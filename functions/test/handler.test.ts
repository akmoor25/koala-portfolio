import assert from "node:assert/strict";
import { initializeApp } from "firebase-admin/app";
import { Database, getDatabase } from "firebase-admin/database";
import type { Message } from "firebase-admin/messaging";
import { Members } from "../src/decide";
import {
  Deps,
  MAX_EVENT_AGE_MS,
  MembersEvent,
  PENDING_TTL_MS,
  SendResult,
  THROTTLE_MS,
  handleMembersChange,
  tokenKey,
} from "../src/handler";

const HASH = "a".repeat(64);
const LID = "0123456789AB";
const NOW = Date.UTC(2026, 9, 12, 12, 0, 0);
const TOKEN_B = "token-of-bob-".padEnd(40, "b");
const TOKEN_B2 = "token-of-bob-second-".padEnd(40, "c");
const TOKEN_C = "token-of-carol-".padEnd(40, "d");
const TOKEN_A = "token-of-alice-".padEnd(40, "a");

let db: Database;

before(() => {
  if (!process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
    throw new Error(
      "Run with the Realtime Database emulator: npm run test:functions (at the repository root)",
    );
  }
  db = getDatabase(
    initializeApp({
      projectId: "demo-koala-test",
      databaseURL: "https://demo-koala-test-default-rtdb.firebaseio.com",
    }),
  );
});

beforeEach(async () => {
  await db.ref().set(null);
});

class Fixture {
  clock = NOW;
  sent: Message[][] = [];
  warnings: { message: string; data: Record<string, unknown> }[] = [];
  names: Record<string, string | null> = { alice: "Aki", bob: "Bob", carol: "Carol" };
  /** 送信の結果を決める。既定は、すべて成功。 */
  outcome: (messages: Message[]) => SendResult[] = (messages) =>
    messages.map(() => ({ ok: true }));

  deps(): Deps {
    return {
      db,
      now: () => this.clock,
      warn: (message, data) => this.warnings.push({ message, data }),
      displayName: async (uid) => this.names[uid] ?? null,
      send: async (messages) => {
        this.sent.push(messages);
        return this.outcome(messages);
      },
    };
  }

  event(id: string, before: Members, after: Members, timeMs = NOW): MembersEvent {
    return { id, timeMs, leafletId: LID, before, after };
  }

  get tokens(): string[] {
    return this.sent.flat().map((m) => ("token" in m ? m.token : ""));
  }
}

/** 新しい形式：キーはトークンのハッシュで、トークンは値に持つ。 */
async function seedTokens(uid: string, tokens: string[]): Promise<void> {
  for (const token of tokens) {
    await db
      .ref(`users/${uid}/fcmTokens/${tokenKey(token)}`)
      .set({ token, at: 1, platform: "android" });
  }
}

/** 古い形式：キーがトークンそのもの。 */
async function seedLegacyToken(uid: string, token: string): Promise<void> {
  await db.ref(`users/${uid}/fcmTokens/${token}`).set({ at: 1, platform: "android" });
}

async function seedClosure(kind: string, title = "Hokkaido", at = NOW - 500) {
  await db.ref(`leafletClosures/${LID}`).set({ kind, title, at });
}

const owner: Members = { alice: true };
const withBob: Members = { alice: true, bob: HASH };
const withBoth: Members = { alice: true, bob: HASH, carol: HASH };

describe("handleMembersChange: a friend joins", () => {
  beforeEach(async () => {
    await db.ref(`leaflets/${LID}/title`).set("Hokkaido");
    await seedTokens("alice", [TOKEN_A]);
  });

  it("sends the owner the title and the nickname of the friend", async () => {
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    assert.equal(result.outcome, "sent");
    assert.deepEqual(f.tokens, [TOKEN_A]);
    const notification = f.sent[0][0].android?.notification;
    assert.equal(notification?.bodyLocKey, "notif_joined_body");
    assert.deepEqual(notification?.bodyLocArgs, ["Hokkaido", "Bob"]);
  });

  it("sends to every device of the owner", async () => {
    await seedTokens("alice", [TOKEN_B2]);
    const f = new Fixture();

    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    assert.deepEqual([...f.tokens].sort(), [TOKEN_A, TOKEN_B2].sort());
  });

  it("uses the nameless wording and cleans the nickname", async () => {
    const f = new Fixture();
    f.names.bob = "   ";
    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));
    assert.equal(
      f.sent[0][0].android?.notification?.bodyLocKey,
      "notif_joined_body_anonymous",
    );

    const g = new Fixture();
    g.clock = NOW + THROTTLE_MS + 1;
    g.names.bob = `\u0000${"あ".repeat(40)}`;
    await handleMembersChange(g.deps(), g.event("e2", owner, withBob, g.clock));
    const args = g.sent[0][0].android?.notification?.bodyLocArgs;
    assert.equal(Array.from(args?.[1] ?? "").length, 20);
  });

  it("falls back to the nameless wording when the user cannot be read", async () => {
    const f = new Fixture();
    const deps = f.deps();
    deps.displayName = async () => {
      throw new Error("user not found");
    };
    await handleMembersChange(deps, f.event("e1", owner, withBob));
    assert.equal(
      f.sent[0][0].android?.notification?.bodyLocKey,
      "notif_joined_body_anonymous",
    );
  });

  it("does nothing when the owner has no registered device", async () => {
    await db.ref(`users/alice`).remove();
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    assert.equal(result.outcome, "no-tokens");
    assert.equal(f.sent.length, 0);
  });

  it("does not send a join notification when the title cannot be read", async () => {
    await db.ref(`leaflets/${LID}`).remove();
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    assert.equal(result.outcome, "no-tokens");
    assert.equal(f.sent.length, 0);
  });

  it("cleans the title as it does the nickname", async () => {
    await db.ref(`leaflets/${LID}/title`).set(`\u202EHok\u200Bkaido\u0007${"x".repeat(200)}`);
    const f = new Fixture();

    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    const args = f.sent[0][0].android?.notification?.bodyLocArgs;
    const title = args?.[0] ?? "";
    assert.ok(title.startsWith("Hokkaido"));
    assert.ok(!/[\u202E\u200B\u0007]/u.test(title));
    assert.equal(Array.from(title).length, 100);
    assert.equal(f.sent[0][0].data?.title, title);
  });

  it("does nothing when the owner only creates the leaflet", async () => {
    const f = new Fixture();
    const result = await handleMembersChange(f.deps(), f.event("e1", null, owner));
    assert.equal(result.outcome, "no-change");
    assert.equal(f.sent.length, 0);
  });
});

describe("handleMembersChange: the leaflet is closed", () => {
  beforeEach(async () => {
    await seedTokens("bob", [TOKEN_B]);
    await seedTokens("carol", [TOKEN_C]);
    await seedTokens("alice", [TOKEN_A]);
  });

  it("tells the removed friends that the leaflet was deleted", async () => {
    await seedClosure("deleted");
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", withBoth, owner));

    assert.equal(result.outcome, "sent");
    assert.deepEqual([...f.tokens].sort(), [TOKEN_B, TOKEN_C].sort());
    const notification = f.sent[0][0].android?.notification;
    assert.equal(notification?.titleLocKey, "notif_unavailable_title");
    assert.equal(notification?.bodyLocKey, "notif_deleted_body");
    assert.deepEqual(notification?.bodyLocArgs, ["Aki", "Hokkaido"]);
  });

  it("tells them that sharing was stopped, and never tells the owner", async () => {
    await seedClosure("stopped", "Kyoto");
    const f = new Fixture();

    await handleMembersChange(f.deps(), f.event("e1", withBob, owner));

    assert.deepEqual(f.tokens, [TOKEN_B]);
    const notification = f.sent[0][0].android?.notification;
    assert.equal(notification?.bodyLocKey, "notif_stopped_body");
    assert.deepEqual(notification?.bodyLocArgs, ["Aki", "Kyoto"]);
  });

  it("removes the closure record after sending", async () => {
    await seedClosure("deleted");
    const f = new Fixture();
    await handleMembersChange(f.deps(), f.event("e1", withBob, owner));
    assert.equal((await db.ref(`leafletClosures/${LID}`).get()).exists(), false);
  });

  it("removes the closure record even when nobody can be reached", async () => {
    await db.ref(`users/bob`).remove();
    await seedClosure("deleted");
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", withBob, owner));

    assert.equal(result.outcome, "no-tokens");
    assert.equal((await db.ref(`leafletClosures/${LID}`).get()).exists(), false);
  });

  it("tells the owner when a friend leaves by themselves", async () => {
    await db.ref(`leaflets/${LID}/title`).set("Hokkaido");
    await seedTokens("alice", [TOKEN_A]);
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", withBob, owner));

    assert.equal(result.outcome, "sent");
    assert.deepEqual(f.tokens, [TOKEN_A]);
    const notification = f.sent[0][0].android?.notification;
    assert.equal(notification?.titleLocKey, "notif_left_title");
    assert.equal(notification?.bodyLocKey, "notif_left_body");
    assert.deepEqual(notification?.bodyLocArgs, ["Hokkaido", "Bob"]);
    assert.equal(notification?.tag, `${LID}:left:bob`);
  });

  it("does not tell the owner about a leave when the leaflet is already gone", async () => {
    await seedTokens("alice", [TOKEN_A]);
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", withBob, owner));

    assert.equal(result.outcome, "no-tokens");
    assert.equal(f.sent.length, 0);
  });

  it("reads a stale closure record as a leave, and drops the record", async () => {
    await db.ref(`leaflets/${LID}/title`).set("Hokkaido");
    await seedTokens("alice", [TOKEN_A]);
    await seedClosure("stopped", "Old", NOW - 60 * 60 * 1000);
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", withBob, owner));

    assert.equal(result.outcome, "sent");
    assert.equal(f.sent[0][0].android?.notification?.bodyLocKey, "notif_left_body");
    assert.equal((await db.ref(`leafletClosures/${LID}`).get()).exists(), false);
  });

  it("does not tell the owner about a leave when the owner deleted the leaflet", async () => {
    await seedTokens("alice", [TOKEN_A]);
    await seedTokens("bob", [TOKEN_B]);
    await seedClosure("deleted");
    const f = new Fixture();

    await handleMembersChange(f.deps(), f.event("e1", withBob, owner));

    assert.deepEqual(f.tokens, [TOKEN_B]);
  });

  it("does not send again when the owner removes their own record last", async () => {
    await seedClosure("deleted");
    const f = new Fixture();
    const result = await handleMembersChange(f.deps(), f.event("e2", owner, null));
    assert.equal(result.outcome, "no-change");
    assert.equal(f.sent.length, 0);
  });
});

describe("handleMembersChange: safety", () => {
  beforeEach(async () => {
    await db.ref(`leaflets/${LID}/title`).set("Hokkaido");
    await seedTokens("alice", [TOKEN_A]);
  });

  it("does not send twice for the same event", async () => {
    const f = new Fixture();
    const event = f.event("same", owner, withBob);

    const first = await handleMembersChange(f.deps(), event);
    const second = await handleMembersChange(f.deps(), event);

    assert.equal(first.outcome, "sent");
    // 同じイベントの再配信は、連打の抑制か、予約済みの判定で止まる。どちらでも、送らない。
    assert.ok(["duplicate", "throttled"].includes(second.outcome));
    assert.equal(f.sent.length, 1);
  });

  it("does not send twice for the same event, even without the throttle", async () => {
    const f = new Fixture();
    const event = f.event("same-2", owner, withBob);
    await handleMembersChange(f.deps(), event);
    await db.ref("notificationThrottle").remove();

    const second = await handleMembersChange(f.deps(), event);

    assert.equal(second.outcome, "duplicate");
    assert.equal(f.sent.length, 1);
  });

  it("uses the same key as the app for a token", () => {
    // アプリの deviceTokenKey（test/unit/token_key_test.dart）と同じ値。
    assert.equal(tokenKey("abc"), "ba7816bf8f01cfea414140de5dae2223");
  });

  it("holds back a repeated join of the same friend for a few seconds", async () => {
    const f = new Fixture();
    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    f.clock = NOW + THROTTLE_MS - 1;
    const early = await handleMembersChange(f.deps(), f.event("e2", owner, withBob, f.clock));
    f.clock = NOW + THROTTLE_MS;
    const later = await handleMembersChange(f.deps(), f.event("e3", owner, withBob, f.clock));

    assert.equal(early.outcome, "throttled");
    assert.equal(later.outcome, "sent");
    assert.equal(f.sent.length, 2);
  });

  it("does not hold back a different friend", async () => {
    const f = new Fixture();
    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));
    const result = await handleMembersChange(
      f.deps(),
      f.event("e2", withBob, withBoth),
    );
    assert.equal(result.outcome, "sent");
  });

  it("drops an event that is too old", async () => {
    const f = new Fixture();
    f.clock = NOW + MAX_EVENT_AGE_MS + 1;
    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));
    assert.equal(result.outcome, "stale-event");
    assert.equal(f.sent.length, 0);
  });

  it("removes tokens that FCM says are no longer registered", async () => {
    await seedTokens("alice", [TOKEN_B2]);
    const f = new Fixture();
    f.outcome = (messages) =>
      messages.map((m) =>
        "token" in m && m.token === TOKEN_B2
          ? { ok: false, code: "messaging/registration-token-not-registered" }
          : { ok: true },
      );

    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    assert.equal(result.removedTokens, 1);
    assert.equal(result.sent, 1);
    const left = (await db.ref("users/alice/fcmTokens").get()).val();
    assert.deepEqual(Object.keys(left), [tokenKey(TOKEN_A)]);
  });

  it("removes both the new and the old entry of an invalid token", async () => {
    await seedLegacyToken("alice", TOKEN_B2);
    await seedTokens("alice", [TOKEN_B2]);
    const f = new Fixture();
    f.outcome = (messages) =>
      messages.map((m) =>
        "token" in m && m.token === TOKEN_B2
          ? { ok: false, code: "messaging/registration-token-not-registered" }
          : { ok: true },
      );

    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    // 同じトークンは、1 件として数える。
    assert.equal(result.removedTokens, 1);
    const left = (await db.ref("users/alice/fcmTokens").get()).val();
    assert.deepEqual(Object.keys(left), [tokenKey(TOKEN_A)]);
  });

  it("still reaches a device that registered in the old format", async () => {
    await db.ref("users/alice").remove();
    await seedLegacyToken("alice", TOKEN_A);
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("e1", owner, withBob));

    assert.equal(result.outcome, "sent");
    assert.deepEqual(f.tokens, [TOKEN_A]);
  });

  it("marks a served device as sent", async () => {
    const f = new Fixture();
    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));
    const log = (await db.ref(`notificationLog/e1/${tokenKey(TOKEN_A)}`).get()).val();
    assert.equal(log.status, "sent");
    assert.equal(typeof log.at, "number");
  });

  it("takes over a reservation that stayed pending after a crash", async () => {
    await db
      .ref(`notificationLog/crash/${tokenKey(TOKEN_A)}`)
      .set({ status: "pending", at: NOW - PENDING_TTL_MS - 1 });
    const f = new Fixture();

    const result = await handleMembersChange(f.deps(), f.event("crash", owner, withBob));

    assert.equal(result.outcome, "sent");
    assert.deepEqual(f.tokens, [TOKEN_A]);
    const log = (await db.ref(`notificationLog/crash/${tokenKey(TOKEN_A)}`).get()).val();
    assert.equal(log.status, "sent");
  });

  it("does not send while another run holds a fresh reservation, and retries", async () => {
    await db
      .ref(`notificationLog/busy/${tokenKey(TOKEN_A)}`)
      .set({ status: "pending", at: NOW - 1000 });
    const f = new Fixture();

    await assert.rejects(
      handleMembersChange(f.deps(), f.event("busy", owner, withBob)),
      /retrying/,
    );
    assert.equal(f.sent.length, 0);
  });

  it("treats an old-format log entry as already served", async () => {
    await db.ref(`notificationLog/old/${tokenKey(TOKEN_A)}`).set({ at: NOW - 1000 });
    const f = new Fixture();
    const result = await handleMembersChange(f.deps(), f.event("old", owner, withBob));
    assert.equal(result.outcome, "duplicate");
    assert.equal(f.sent.length, 0);
  });

  it("warns about an unexpected error code, without the token, and does not retry", async () => {
    const f = new Fixture();
    f.outcome = (messages) =>
      messages.map(() => ({ ok: false, code: "messaging/third-party-auth-error" }));

    const result = await handleMembersChange(f.deps(), f.event("auth", owner, withBob));

    assert.equal(result.sent, 0);
    assert.equal(f.warnings.length, 1);
    assert.equal(f.warnings[0].data.code, "messaging/third-party-auth-error");
    assert.equal(f.warnings[0].data.uid, "alice");
    assert.ok(!JSON.stringify(f.warnings).includes(TOKEN_A));
    const log = (await db.ref(`notificationLog/auth/${tokenKey(TOKEN_A)}`).get()).val();
    assert.equal(log.status, "failed");
  });

  it("retries when the sending quota is exceeded", async () => {
    for (const code of ["messaging/quota-exceeded", "messaging/message-rate-exceeded"]) {
      await db.ref("notificationLog").remove();
      const f = new Fixture();
      f.outcome = (messages) => messages.map(() => ({ ok: false, code }));
      await assert.rejects(
        handleMembersChange(f.deps(), f.event("quota", owner, withBob)),
        /transient/,
        code,
      );
      assert.equal(f.warnings.length, 0, code);
    }
  });

  it("releases the reservation and fails on a transient error, so a retry can send", async () => {
    const f = new Fixture();
    f.outcome = (messages) =>
      messages.map(() => ({ ok: false, code: "messaging/server-unavailable" }));
    const event = f.event("retry", owner, withBob);

    await assert.rejects(handleMembersChange(f.deps(), event), /transient/);
    assert.equal((await db.ref("notificationLog/retry").get()).exists(), false);

    f.outcome = (messages) => messages.map(() => ({ ok: true }));
    const result = await handleMembersChange(f.deps(), event);
    assert.equal(result.outcome, "sent");
  });

  it("on a retry, sends only to the devices that failed the first time", async () => {
    await seedTokens("bob", [TOKEN_B]);
    await seedTokens("carol", [TOKEN_C]);
    await seedClosure("deleted");
    const f = new Fixture();
    f.outcome = (messages) =>
      messages.map((m) =>
        "token" in m && m.token === TOKEN_B
          ? { ok: false, code: "messaging/server-unavailable" }
          : { ok: true },
      );
    const event = f.event("partial", withBoth, owner);

    await assert.rejects(handleMembersChange(f.deps(), event), /transient/);
    assert.deepEqual([...f.tokens].sort(), [TOKEN_B, TOKEN_C].sort());
    // 一時的な失敗のときは、閉鎖の記録を残す（再試行で、もう一度読む）。
    assert.equal((await db.ref(`leafletClosures/${LID}`).get()).exists(), true);

    f.sent.length = 0;
    f.outcome = (messages) => messages.map(() => ({ ok: true }));
    const retried = await handleMembersChange(f.deps(), event);

    assert.equal(retried.outcome, "sent");
    assert.deepEqual(f.tokens, [TOKEN_B]);
    assert.equal((await db.ref(`leafletClosures/${LID}`).get()).exists(), false);
  });

  it("does not send again to anyone once every device was served", async () => {
    await seedTokens("bob", [TOKEN_B]);
    await seedTokens("carol", [TOKEN_C]);
    await seedClosure("deleted");
    const f = new Fixture();
    const event = f.event("again", withBoth, owner);
    await handleMembersChange(f.deps(), event);
    await seedClosure("deleted");

    const second = await handleMembersChange(f.deps(), event);

    assert.ok(["duplicate", "throttled"].includes(second.outcome));
    assert.equal(f.sent.length, 1);
    assert.equal((await db.ref(`leafletClosures/${LID}`).get()).exists(), false);
  });

  it("keeps the notifications of two friends who joined apart", async () => {
    const f = new Fixture();
    await handleMembersChange(f.deps(), f.event("e1", owner, withBob));
    await handleMembersChange(f.deps(), f.event("e2", withBob, withBoth));

    const tags = f.sent.flat().map((m) => m.android?.notification?.tag);
    assert.equal(new Set(tags).size, 2);
  });

  it("releases the reservation when sending throws", async () => {
    const f = new Fixture();
    const deps = f.deps();
    deps.send = async () => {
      throw new Error("network down");
    };
    await assert.rejects(handleMembersChange(deps, f.event("boom", owner, withBob)));
    assert.equal((await db.ref("notificationLog/boom").get()).exists(), false);
  });

  it("accepts event ids that are not valid database keys", async () => {
    const f = new Fixture();
    const result = await handleMembersChange(
      f.deps(),
      f.event("a.b#c$d[e]f/g", owner, withBob),
    );
    assert.equal(result.outcome, "sent");
  });
});
