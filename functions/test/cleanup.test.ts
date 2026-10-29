import assert from "node:assert/strict";
import { deleteApp, initializeApp, App } from "firebase-admin/app";
import { Auth } from "firebase-admin/auth";
import { Database, getDatabase } from "firebase-admin/database";
import {
  CleanupDeps,
  applyCleanup,
  missingUidsVia,
  planCleanup,
  runCleanup,
  shallowKeysVia,
} from "../src/cleanup";

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 31);

describe("cleanup", () => {
  let app: App;
  let db: Database;

  before(() => {
    if (!process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
      throw new Error(
        "Run with the Realtime Database emulator: npm run test:functions (at the repository root)",
      );
    }
    app = initializeApp(
      {
        projectId: "demo-koala-test",
        databaseURL: "https://demo-koala-test-default-rtdb.firebaseio.com",
      },
      "cleanup-test",
    );
    db = getDatabase(app);
  });

  after(async () => {
    await deleteApp(app);
  });

  beforeEach(async () => {
    await db.ref().set(null);
  });

  /** [gone] の uid は、Authentication にもういないことにする。 */
  function deps(gone: string[] = [], overrides: Partial<CleanupDeps> = {}): CleanupDeps {
    return {
      db,
      now: () => NOW,
      shallowKeys: shallowKeysVia(app),
      missingUids: async (uids) => new Set(uids.filter((uid) => gone.includes(uid))),
      ...overrides,
    };
  }

  /** 1 冊分の関連データ一式を入れる。持ち主は、最初のメンバー。 */
  async function seedLeaflet(id: string, title: string, members: string[] = ["alice"]): Promise<void> {
    const updates: Record<string, unknown> = {
      [`leaflets/${id}`]: { title, ownerUid: members[0], createdAt: NOW - 5 * DAY },
      [`marks/${id}/m1`]: { startDate: 1, title: "x" },
      [`rich_notes/${id}`]: { text: "[]" },
      [`presence/notes/${id}/alice`]: { name: "A" },
      [`leafletSecrets/${id}`]: "a".repeat(64),
    };
    members.forEach((uid, index) => {
      updates[`leafletMembers/${id}/${uid}`] = index === 0 ? true : "b".repeat(64);
      updates[`userLeaflets/${uid}/${id}`] = true;
    });
    await db.ref().update(updates);
  }

  async function exists(path: string): Promise<boolean> {
    return (await db.ref(path).get()).exists();
  }

  it("plans nothing when every owner still exists", async () => {
    await seedLeaflet("0000000000AA", "mine");

    const plan = await planCleanup(deps());

    assert.deepEqual(plan.removedLeaflets, []);
    assert.deepEqual(plan.updates, {});
  });

  it("selects the leaflets whose owner is gone, even when other members remain", async () => {
    await seedLeaflet("0000000000AA", "alive");
    await seedLeaflet("0000000000BB", "orphaned", ["zed", "bob"]);

    const plan = await planCleanup(deps(["zed"]));

    assert.deepEqual(
      plan.removedLeaflets.map((r) => r.id),
      ["0000000000BB"],
    );
    assert.equal(plan.removedLeaflets[0].ownerUid, "zed");
    assert.deepEqual([...plan.removedLeaflets[0].members].sort(), ["bob", "zed"]);
  });

  it("never changes anything when it only makes a plan", async () => {
    await seedLeaflet("0000000000BB", "orphaned", ["zed"]);
    await db.ref("users/zed/fcmTokens/key1").set({ token: "t", at: NOW, platform: "android" });

    await planCleanup(deps(["zed"]));

    assert.ok(await exists("leaflets/0000000000BB"));
    assert.ok(await exists("marks/0000000000BB"));
    assert.ok(await exists("users/zed/fcmTokens/key1"));
  });

  it("removes the leaflet with all of its data and every member's index", async () => {
    await seedLeaflet("0000000000AA", "alive");
    await seedLeaflet("0000000000BB", "orphaned", ["zed", "bob"]);

    const plan = await planCleanup(deps(["zed"]));
    await applyCleanup(db, plan);

    for (const path of [
      "leaflets/0000000000BB",
      "marks/0000000000BB",
      "rich_notes/0000000000BB",
      "presence/notes/0000000000BB",
      "leafletSecrets/0000000000BB",
      "leafletMembers/0000000000BB",
      "userLeaflets/zed",
      "userLeaflets/bob/0000000000BB",
    ]) {
      assert.ok(!(await exists(path)), `${path} should be gone`);
    }
    for (const path of [
      "leaflets/0000000000AA",
      "marks/0000000000AA",
      "rich_notes/0000000000AA",
      "leafletSecrets/0000000000AA",
      "userLeaflets/alice/0000000000AA",
    ]) {
      assert.ok(await exists(path), `${path} should stay`);
    }
  });

  it("removes paragraph notes including deletion records when the owner is gone", async () => {
    const id = "0000000000BB";
    await seedLeaflet(id, "orphaned", ["zed"]);
    await db.ref(`rich_notes/${id}`).set({
      schemaVersion: 2,
      generation: "g",
      lines: {
        first: {
          generation: "g", afterId: "", order: 1, writeId: "w1",
          delta: '[{"insert":"memo\\n"}]', deleted: false,
        },
        second: {
          generation: "g", afterId: "first", order: 2, writeId: "w2", deleted: true,
        },
      },
    });

    await applyCleanup(db, await planCleanup(deps(["zed"])));

    assert.equal(await exists(`rich_notes/${id}`), false);
  });

  it("keeps a leaflet that records no owner", async () => {
    await db.ref().update({
      "leaflets/0000000000CC": { title: "no owner", createdAt: NOW },
      "leafletMembers/0000000000CC/alice": true,
    });

    const plan = await planCleanup(deps(["alice"]));

    assert.deepEqual(plan.removedLeaflets, []);
    assert.equal(plan.unownedLeaflets, 1);
  });

  it("removes data left behind by a leaflet that no longer exists", async () => {
    await seedLeaflet("0000000000AA", "alive");
    await db.ref().update({
      "marks/0000000000ZZ/m1": { startDate: 1, title: "orphan" },
      "rich_notes/0000000000ZZ": { text: "[]" },
      "leafletMembers/0000000000ZZ/carol": true,
      "leafletSecrets/0000000000ZZ": "c".repeat(64),
      "presence/notes/0000000000ZZ/carol": { name: "C" },
      "userLeaflets/carol/0000000000ZZ": true,
    });

    const plan = await planCleanup(deps());
    await applyCleanup(db, plan);

    assert.equal(plan.orphans.length, 5);
    assert.deepEqual(plan.strayIndex, ["userLeaflets/carol/0000000000ZZ"]);
    assert.ok(!(await exists("marks/0000000000ZZ")));
    assert.ok(!(await exists("userLeaflets/carol/0000000000ZZ")));
    assert.ok(await exists("leaflets/0000000000AA"));
  });

  it("removes the closure record together with the leaflet", async () => {
    await seedLeaflet("0000000000AA", "orphaned", ["zed"]);
    await db.ref("leafletClosures/0000000000AA").set({ kind: "stopped", title: "x", at: NOW });

    await applyCleanup(db, await planCleanup(deps(["zed"])));

    assert.ok(!(await exists("leafletClosures/0000000000AA")));
  });

  it("removes the index and the tokens of a gone user, but leaves other leaflets' members alone", async () => {
    await seedLeaflet("0000000000AA", "alive", ["alice", "zed"]);
    await db.ref("users/zed/fcmTokens/key1").set({ token: "t", at: NOW, platform: "android" });

    const plan = await planCleanup(deps(["zed"]));
    await applyCleanup(db, plan);

    assert.deepEqual(plan.goneUsers, ["zed"]);
    assert.ok(!(await exists("users/zed")));
    assert.ok(!(await exists("userLeaflets/zed")));
    // メンバーの記録を消すと、オーナーに「脱退」の通知が飛ぶので、触らない。
    assert.ok(await exists("leafletMembers/0000000000AA/zed"));
    assert.ok(await exists("leaflets/0000000000AA"));
  });

  it("removes the tokens of a gone owner before the leaflet, so that nobody is notified", async () => {
    await seedLeaflet("0000000000BB", "orphaned", ["zed", "bob"]);
    await db.ref("users/zed/fcmTokens/key1").set({ token: "t", at: NOW, platform: "android" });

    const plan = await planCleanup(deps(["zed"]));

    assert.equal(Object.keys(plan.updates)[0], "users/zed");
    await applyCleanup(db, plan);
    assert.ok(!(await exists("users/zed")));
  });

  it("removes old notification bookkeeping but keeps the recent one", async () => {
    await db.ref().update({
      "notificationLog/old-event/aaaa": { at: NOW - 2 * DAY },
      "notificationLog/new-event/bbbb": { at: NOW - 60 * 1000 },
      "notificationLog/mixed-event/cccc": { at: NOW - 2 * DAY },
      "notificationLog/mixed-event/dddd": { at: NOW - 1000 },
      "notificationThrottle/LID_bob_joined": NOW - 3 * DAY,
      "notificationThrottle/LID_carol_joined": NOW - 1000,
    });

    const plan = await planCleanup(deps());
    await applyCleanup(db, plan);

    assert.deepEqual([...plan.staleNotifications].sort(), [
      "notificationLog/old-event",
      "notificationThrottle/LID_bob_joined",
    ]);
    assert.ok(!(await exists("notificationLog/old-event")));
    assert.ok(await exists("notificationLog/new-event"));
    assert.ok(await exists("notificationLog/mixed-event"));
    assert.ok(!(await exists("notificationThrottle/LID_bob_joined")));
    assert.ok(await exists("notificationThrottle/LID_carol_joined"));
  });

  it("works on an empty database", async () => {
    let asked = false;
    const plan = await planCleanup(
      deps([], {
        missingUids: async () => {
          asked = true;
          return new Set();
        },
      }),
    );

    assert.deepEqual(plan, {
      removedLeaflets: [],
      unownedLeaflets: 0,
      orphans: [],
      strayIndex: [],
      goneUsers: [],
      staleNotifications: [],
      updates: {},
    });
    assert.equal(asked, false, "no user to ask about");
    assert.equal(await applyCleanup(db, plan), 0);
  });

  it("deletes nothing when Authentication cannot be asked", async () => {
    await seedLeaflet("0000000000BB", "orphaned", ["zed"]);
    const failing = deps([], {
      missingUids: async () => {
        throw new Error("auth is down");
      },
    });

    await assert.rejects(() => runCleanup(failing, { apply: true }), /auth is down/);

    assert.ok(await exists("leaflets/0000000000BB"));
    assert.ok(await exists("userLeaflets/zed/0000000000BB"));
  });

  it("applies the plan only when asked", async () => {
    await seedLeaflet("0000000000BB", "orphaned", ["zed"]);

    const dry = await runCleanup(deps(["zed"]), { apply: false });
    assert.equal(dry.removedPaths, 0);
    assert.ok(await exists("leaflets/0000000000BB"));

    const applied = await runCleanup(deps(["zed"]), { apply: true });
    assert.equal(applied.removedPaths, Object.keys(applied.plan.updates).length);
    assert.ok(!(await exists("leaflets/0000000000BB")));
  });

  describe("missingUidsVia", () => {
    it("asks in batches, reports only the users reported as not found, and skips impossible uids", async () => {
      const calls: string[][] = [];
      const auth = {
        getUsers: async (identifiers: { uid: string }[]) => {
          calls.push(identifiers.map((i) => i.uid));
          return {
            users: [],
            notFound: identifiers.filter((i) => i.uid.endsWith("7")),
          };
        },
      } as unknown as Pick<Auth, "getUsers">;
      const uids = Array.from({ length: 250 }, (_, i) => `u${i}`);

      const missing = await missingUidsVia(auth)([...uids, "", "x".repeat(129)]);

      assert.deepEqual(
        calls.map((c) => c.length),
        [100, 100, 50],
      );
      assert.deepEqual(
        [...missing].sort(),
        uids.filter((u) => u.endsWith("7")).sort(),
      );
    });

    it("does not turn a failed lookup into a missing user", async () => {
      const auth = {
        getUsers: async () => {
          throw new Error("quota");
        },
      } as unknown as Pick<Auth, "getUsers">;

      await assert.rejects(() => missingUidsVia(auth)(["alice"]), /quota/);
    });
  });
});
