const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-koala-test",
    // ホストとポートは `firebase emulators:exec` が設定する FIREBASE_DATABASE_EMULATOR_HOST から取得する。
    database: {
      rules: fs.readFileSync("database.rules.json", "utf8"),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearDatabase();
});

// 公開用しおり ID（Crockford Base32 の 12 文字）。
const LEAFLET = "0123456789AB";
const HASH = "a".repeat(64);
const OTHER_HASH = "b".repeat(64);

async function seed(data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.database().ref().set(data);
  });
}

// サーバーの時刻。ルールの `now` と比べるために、データベースが書き込みの時刻に置き換える。
const SERVER_NOW = { ".sv": "timestamp" };

function db(uid) {
  return uid
    ? testEnv.authenticatedContext(uid).database()
    : testEnv.unauthenticatedContext().database();
}

/** alice がオーナーで、まだ共同編集は有効にしていないしおり。 */
function ownedLeaflet(extra = {}) {
  return {
    leaflets: {
      [LEAFLET]: { title: "Hokkaido", imageUrl: "✈️", ownerUid: "alice" },
    },
    leafletMembers: { [LEAFLET]: { alice: true } },
    userLeaflets: { alice: { [LEAFLET]: true } },
    ...extra,
  };
}

/** alice がオーナーで共同編集が有効なしおり。 */
function sharedLeaflet(extra = {}) {
  const data = ownedLeaflet();
  data.leaflets[LEAFLET].shared = true;
  return { ...data, leafletSecrets: { [LEAFLET]: HASH }, ...extra };
}

function joinPaths(uid, hash) {
  return {
    [`leafletMembers/${LEAFLET}/${uid}`]: hash,
    [`userLeaflets/${uid}/${LEAFLET}`]: true,
  };
}

function noteLine(generation = "g", extra = {}) {
  return { generation, afterId: "", order: 1, writeId: "w",
    deleted: false, delta: '[{"insert":"one\\n"}]', ...extra };
}

function paragraphNote(generation = "g") {
  return { schemaVersion: 2, generation, lines: { first: noteLine(generation) } };
}

describe("Koala Database Rules", () => {
  describe("paragraph notes", () => {
    const path = `rich_notes/${LEAFLET}`;
    beforeEach(async () => {
      await seed(ownedLeaflet({
        leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
        rich_notes: { [LEAFLET]: paragraphNote() },
      }));
    });

    it("allows different paragraphs to be saved independently", async () => {
      await assertSucceeds(db("alice").ref(`${path}/lines/second`).set(
        noteLine("g", { afterId: "first", order: 2 }),
      ));
      await Promise.all([
        assertSucceeds(db("alice").ref(`${path}/lines/first`).update({ delta: '[{"insert":"A\\n"}]', writeId: "a" })),
        assertSucceeds(db("bob").ref(`${path}/lines/second`).update({ delta: '[{"insert":"B\\n"}]', writeId: "b" })),
      ]);
      const result = (await db("alice").ref(path).get()).val();
      require("assert").equal(result.lines.first.delta, '[{"insert":"A\\n"}]');
      require("assert").equal(result.lines.second.delta, '[{"insert":"B\\n"}]');
    });

    it("accepts an atomic split with references to another newly inserted line", async () => {
      await assertSucceeds(db("alice").ref(path).update({
        "lines/second": noteLine("g", { afterId: "first", order: 2 }),
        "lines/third": noteLine("g", { afterId: "second", order: 3 }),
      }));
    });

    it("rejects old format writes and arbitrary extra fields", async () => {
      await assertFails(db("alice").ref(`${path}/text`).set("old"));
      await assertFails(db("alice").ref(`${path}/lines/first/extra`).set(true));
      await assertFails(db("alice").ref(path).set({
        schemaVersion: 2, generation: "next", lines: "not a paragraph map",
      }));
    });

    it("rejects stale generations after a reset", async () => {
      await assertSucceeds(db("alice").ref(path).set(paragraphNote("next")));
      await assertFails(db("bob").ref(`${path}/lines/first`).set(noteLine("g")));
    });

    it("keeps deletion final even if a stale editor writes later", async () => {
      const tombstone = noteLine("g", { deleted: true });
      delete tombstone.delta;
      await assertSucceeds(db("alice").ref(`${path}/lines/first`).set(tombstone));
      await assertFails(db("bob").ref(`${path}/lines/first`).set(noteLine()));
      await assertFails(db("bob").ref(`${path}/lines/first`).remove());
      await assertSucceeds(db("bob").ref(`${path}/lines/child`).set(
        noteLine("g", { afterId: "first", order: 2 }),
      ));
    });

    it("rejects cycles, missing anchors and order mutation", async () => {
      await assertFails(db("alice").ref(`${path}/lines/first/afterId`).set("first"));
      await assertFails(db("alice").ref(`${path}/lines/x`).set(noteLine("g", { afterId: "missing", order: 2 })));
      await assertFails(db("alice").ref(`${path}/lines/first/order`).set(2));
    });

    it("enforces serialized paragraph size at the exact boundary", async () => {
      await assertSucceeds(db("alice").ref(`${path}/lines/first/delta`).set("x".repeat(20000)));
      await assertFails(db("alice").ref(`${path}/lines/first/delta`).set("x".repeat(20001)));
    });

    it("permits explicit replacement of unreadable legacy data", async () => {
      await seed(ownedLeaflet({ rich_notes: { [LEAFLET]: { text: "legacy" } } }));
      await assertSucceeds(db("alice").ref(path).set(paragraphNote()));
      await assertFails(db("alice").ref(`${path}/text`).set("legacy"));
    });
  });
  describe("creating a leaflet", () => {
    const stamp = { ".sv": "timestamp" };
    const create = (ownerUid = "alice", id = LEAFLET, extra = {}) => ({
      [`leaflets/${id}`]: {
        title: "Okinawa",
        imageUrl: "🏝️",
        ownerUid,
        createdAt: stamp,
        ...extra,
      },
      [`leafletMembers/${id}/alice`]: true,
      [`userLeaflets/alice/${id}`]: true,
    });

    it("lets a signed-in user create one in a single update", async () => {
      await assertSucceeds(db("alice").ref().update(create()));
    });

    it("requires the creation time, so old leaflets can be cleaned up", async () => {
      const without = create();
      delete without[`leaflets/${LEAFLET}`].createdAt;
      await assertFails(db("alice").ref().update(without));
    });

    it("rejects a creation time in the future or of the wrong type", async () => {
      await assertFails(
        db("alice")
          .ref()
          .update(create("alice", LEAFLET, { createdAt: Date.now() + 3600e3 })),
      );
      await assertFails(
        db("alice")
          .ref()
          .update(create("alice", LEAFLET, { createdAt: "yesterday" })),
      );
    });

    it("does not let the creation time be changed afterwards", async () => {
      await assertSucceeds(db("alice").ref().update(create()));
      await assertFails(
        db("alice").ref(`leaflets/${LEAFLET}/createdAt`).set(Date.now() - 1),
      );
      await assertSucceeds(
        db("alice").ref(`leaflets/${LEAFLET}`).update({ title: "Renamed" }),
      );
    });

    it("denies unauthenticated users", async () => {
      await assertFails(db(null).ref().update(create()));
    });

    it("requires the creator to be the owner", async () => {
      await assertFails(db("alice").ref().update(create("mallory")));
    });

    it("requires a well-formed public id", async () => {
      await assertFails(db("alice").ref().update(create("alice", "short")));
      await assertFails(
        db("alice").ref().update(create("alice", "-NxAbCdEfGhIjKlMnOp")),
      );
    });

    it("cannot take over an existing leaflet", async () => {
      await seed(ownedLeaflet());
      await assertFails(
        db("mallory")
          .ref()
          .update({
            [`leaflets/${LEAFLET}`]: {
              title: "mine",
              ownerUid: "mallory",
            },
            [`leafletMembers/${LEAFLET}/mallory`]: true,
          }),
      );
    });

    it("cannot claim ownership membership of an existing leaflet", async () => {
      await seed(ownedLeaflet());
      await assertFails(
        db("mallory").ref(`leafletMembers/${LEAFLET}/mallory`).set(true),
      );
    });
  });

  describe("reading", () => {
    beforeEach(async () => {
      await seed(sharedLeaflet({ leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } } }));
    });

    it("lets members read the leaflet and their own membership", async () => {
      await assertSucceeds(db("alice").ref(`leaflets/${LEAFLET}`).get());
      await assertSucceeds(db("bob").ref(`leaflets/${LEAFLET}`).get());
      await assertSucceeds(
        db("bob").ref(`leafletMembers/${LEAFLET}/bob`).get(),
      );
    });

    it("hides the leaflet from non-members and the signed-out", async () => {
      await assertFails(db("mallory").ref(`leaflets/${LEAFLET}`).get());
      await assertFails(db(null).ref(`leaflets/${LEAFLET}`).get());
    });

    it("does not allow listing all leaflets or the whole database", async () => {
      await assertFails(db("alice").ref("leaflets").get());
      await assertFails(db("alice").ref().get());
    });

    it("never exposes the passphrase hash", async () => {
      await assertFails(db("alice").ref(`leafletSecrets/${LEAFLET}`).get());
      await assertFails(db("bob").ref(`leafletSecrets/${LEAFLET}`).get());
      await assertFails(db("mallory").ref(`leafletSecrets/${LEAFLET}`).get());
    });

    it("lets only the owner list the members", async () => {
      await assertSucceeds(db("alice").ref(`leafletMembers/${LEAFLET}`).get());
      await assertFails(db("bob").ref(`leafletMembers/${LEAFLET}`).get());
      await assertFails(db("bob").ref(`leafletMembers/${LEAFLET}/alice`).get());
    });

    it("keeps the personal index private", async () => {
      await assertSucceeds(db("alice").ref("userLeaflets/alice").get());
      await assertFails(db("bob").ref("userLeaflets/alice").get());
      await assertFails(db("bob").ref("userLeaflets").get());
    });
  });

  describe("sharing", () => {
    beforeEach(async () => {
      await seed(
        ownedLeaflet({ leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } } }),
      );
    });

    it("lets the owner enable sharing", async () => {
      await assertSucceeds(
        db("alice")
          .ref()
          .update({
            [`leafletSecrets/${LEAFLET}`]: HASH,
            [`leaflets/${LEAFLET}/shared`]: true,
          }),
      );
    });

    it("lets the owner change or stop sharing", async () => {
      await seed(sharedLeaflet());
      await assertSucceeds(
        db("alice").ref(`leafletSecrets/${LEAFLET}`).set(OTHER_HASH),
      );
      await assertSucceeds(
        db("alice")
          .ref()
          .update({
            [`leafletSecrets/${LEAFLET}`]: null,
            [`leaflets/${LEAFLET}/shared`]: null,
          }),
      );
    });

    it("lets the owner stop sharing and remove the members at once", async () => {
      await seed(
        sharedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
        }),
      );
      await assertSucceeds(
        db("alice")
          .ref()
          .update({
            [`leafletSecrets/${LEAFLET}`]: null,
            [`leaflets/${LEAFLET}/shared`]: null,
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
            [`leafletClosures/${LEAFLET}`]: {
              kind: "stopped",
              title: "Hokkaido",
              at: SERVER_NOW,
            },
          }),
      );
      await assertFails(db("bob").ref(`leaflets/${LEAFLET}`).get());
      await assertFails(db("bob").ref(`marks/${LEAFLET}`).get());
    });

    it("does not let the owner remove a member without a closure record", async () => {
      // 古いアプリや不正なクライアントが、記録を書かずに追い出すと、通知が正しく決まらない。
      await seed(
        sharedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
        }),
      );
      await assertFails(
        db("alice")
          .ref()
          .update({
            [`leafletSecrets/${LEAFLET}`]: null,
            [`leaflets/${LEAFLET}/shared`]: null,
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
          }),
      );
      await assertFails(db("alice").ref(`leafletMembers/${LEAFLET}/bob`).remove());
    });

    it("does not accept a closure record with a time other than now", async () => {
      await seed(
        sharedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
        }),
      );
      for (const at of [Date.now() - 3_600_000, Date.now() + 3_600_000]) {
        await assertFails(
          db("alice")
            .ref()
            .update({
              [`leafletMembers/${LEAFLET}/bob`]: null,
              [`userLeaflets/bob/${LEAFLET}`]: null,
              [`leafletClosures/${LEAFLET}`]: { kind: "stopped", title: "t", at },
            }),
        );
      }
    });

    it("still lets a participant leave without a closure record", async () => {
      await seed(
        sharedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
        }),
      );
      await assertSucceeds(
        db("bob")
          .ref()
          .update({
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
          }),
      );
    });

    it("lets only the owner clear someone else's index entry", async () => {
      await seed(
        ownedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
        }),
      );
      await assertFails(
        db("bob").ref(`userLeaflets/alice/${LEAFLET}`).remove(),
      );
      await assertFails(
        db("mallory").ref(`userLeaflets/bob/${LEAFLET}`).remove(),
      );
      await assertFails(
        db("alice").ref(`userLeaflets/bob/${LEAFLET}`).set(true),
      );
      await assertSucceeds(
        db("alice").ref(`userLeaflets/bob/${LEAFLET}`).remove(),
      );
    });

    it("does not let a participant touch the secret or the flag", async () => {
      await assertFails(db("bob").ref(`leafletSecrets/${LEAFLET}`).set(HASH));
      await assertFails(db("bob").ref(`leaflets/${LEAFLET}/shared`).set(true));
    });

    it("does not let an outsider touch the secret", async () => {
      await assertFails(
        db("mallory").ref(`leafletSecrets/${LEAFLET}`).set(HASH),
      );
    });

    it("requires a 64-character hash", async () => {
      await assertFails(
        db("alice").ref(`leafletSecrets/${LEAFLET}`).set("plain-text"),
      );
    });
  });

  describe("joining", () => {
    beforeEach(async () => {
      await seed(sharedLeaflet());
    });

    it("accepts the correct passphrase hash", async () => {
      await assertSucceeds(db("bob").ref().update(joinPaths("bob", HASH)));
      await assertSucceeds(db("bob").ref(`leaflets/${LEAFLET}`).get());
    });

    it("rejects a wrong passphrase hash", async () => {
      await assertFails(db("bob").ref().update(joinPaths("bob", OTHER_HASH)));
    });

    it("rejects joining as the owner or with a boolean", async () => {
      await assertFails(db("bob").ref().update(joinPaths("bob", true)));
    });

    it("rejects joining on behalf of someone else", async () => {
      await assertFails(db("bob").ref().update(joinPaths("carol", HASH)));
    });

    it("rejects joining while signed out", async () => {
      await assertFails(db(null).ref().update(joinPaths("bob", HASH)));
    });

    it("rejects joining when sharing is not enabled", async () => {
      await seed(ownedLeaflet());
      await assertFails(db("bob").ref().update(joinPaths("bob", HASH)));
    });

    it("rejects joining after the owner stopped sharing", async () => {
      await seed(ownedLeaflet({ leaflets: sharedLeaflet().leaflets }));
      await assertFails(db("bob").ref().update(joinPaths("bob", HASH)));
    });

    it("rejects joining an unknown leaflet", async () => {
      await assertFails(
        db("bob")
          .ref()
          .update({
            "leafletMembers/ZZZZZZZZZZZZ/bob": HASH,
            "userLeaflets/bob/ZZZZZZZZZZZZ": true,
          }),
      );
    });

    it("does not let a member overwrite an existing membership", async () => {
      await db("bob").ref().update(joinPaths("bob", HASH));
      await assertFails(
        db("bob").ref(`leafletMembers/${LEAFLET}/bob`).set(HASH),
      );
    });

    it("keeps the passphrase change from affecting existing members", async () => {
      await db("bob").ref().update(joinPaths("bob", HASH));
      await db("alice").ref(`leafletSecrets/${LEAFLET}`).set(OTHER_HASH);
      await assertSucceeds(db("bob").ref(`leaflets/${LEAFLET}`).get());
      await assertFails(db("carol").ref().update(joinPaths("carol", HASH)));
      await assertSucceeds(
        db("carol").ref().update(joinPaths("carol", OTHER_HASH)),
      );
    });
  });

  describe("leaving and deleting", () => {
    beforeEach(async () => {
      await seed(
        sharedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
          marks: { [LEAFLET]: { m1: { startDate: 1, title: "t" } } },
          rich_notes: { [LEAFLET]: { text: "[]" } },
        }),
      );
    });

    it("lets a participant leave", async () => {
      await assertSucceeds(
        db("bob")
          .ref()
          .update({
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
          }),
      );
      await assertFails(db("bob").ref(`leaflets/${LEAFLET}`).get());
    });

    it("does not let the owner leave without deleting", async () => {
      await assertFails(db("alice").ref(`leafletMembers/${LEAFLET}/alice`).remove());
    });

    it("does not let a participant remove someone else", async () => {
      await assertFails(db("bob").ref(`leafletMembers/${LEAFLET}/alice`).remove());
    });

    it("does not let a participant delete the leaflet", async () => {
      await assertFails(db("bob").ref(`leaflets/${LEAFLET}`).remove());
    });

    it("lets the owner delete everything in two updates", async () => {
      // 自分の参加記録は、しおりが無くなってから消せる（途中で放棄できないようにする）。
      await assertSucceeds(
        db("alice")
          .ref()
          .update({
            [`leaflets/${LEAFLET}`]: null,
            [`marks/${LEAFLET}`]: null,
            [`rich_notes/${LEAFLET}`]: null,
            [`leafletSecrets/${LEAFLET}`]: null,
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/alice/${LEAFLET}`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
            [`leafletClosures/${LEAFLET}`]: {
              kind: "deleted",
              title: "Hokkaido",
              at: SERVER_NOW,
            },
          }),
      );
      await assertSucceeds(
        db("alice").ref(`leafletMembers/${LEAFLET}/alice`).remove(),
      );
    });
  });

  describe("access control", () => {
    beforeEach(async () => {
      await seed(
        ownedLeaflet({ leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } } }),
      );
    });

    it("denies unauthenticated users", async () => {
      await assertFails(db(null).ref(`marks/${LEAFLET}`).get());
      await assertFails(db(null).ref(`rich_notes/${LEAFLET}`).get());
    });

    it("denies authenticated non-members", async () => {
      await assertFails(db("mallory").ref(`marks/${LEAFLET}`).get());
      await assertFails(
        db("mallory").ref(`rich_notes/${LEAFLET}/text`).set("hack"),
      );
      await assertFails(
        db("mallory").ref(`leaflets/${LEAFLET}/title`).set("hack"),
      );
    });

    it("allows participants to read and write", async () => {
      await assertSucceeds(db("bob").ref(`leaflets/${LEAFLET}`).get());
      await assertSucceeds(
        db("bob").ref(`leaflets/${LEAFLET}`).update({ title: "Okinawa" }),
      );
      await assertSucceeds(
        db("bob").ref(`rich_notes/${LEAFLET}`).set(paragraphNote()),
      );
    });
  });

  describe("leaflet validation", () => {
    beforeEach(async () => {
      await seed(ownedLeaflet());
    });

    const path = `leaflets/${LEAFLET}`;

    it("requires a non-empty title", async () => {
      await assertFails(db("alice").ref(`${path}/title`).set(""));
      await assertFails(
        db("alice").ref(path).set({ imageUrl: "✈️", ownerUid: "alice" }),
      );
    });

    it("cannot change the owner", async () => {
      await assertFails(db("alice").ref(`${path}/ownerUid`).set("mallory"));
    });

    it("rejects unknown fields", async () => {
      await assertFails(
        db("alice")
          .ref(path)
          .set({ title: "t", ownerUid: "alice", admin: true }),
      );
    });

    it("accepts the time zones of the first and last dates", async () => {
      await assertSucceeds(
        db("alice").ref(path).update({
          firstDate: 100,
          lastDate: 200,
          firstTimeZoneId: "Asia/Tokyo",
          lastTimeZoneId: "Australia/Sydney",
        }),
      );
    });

    it("rejects a malformed time zone id on the leaflet", async () => {
      await assertFails(db("alice").ref(`${path}/firstTimeZoneId`).set("Tokyo!"));
      await assertFails(db("alice").ref(`${path}/lastTimeZoneId`).set(1));
    });
    it("rejects lastDate before firstDate", async () => {
      await assertFails(
        db("alice")
          .ref(path)
          .update({ firstDate: 200, lastDate: 100 }),
      );
      await assertSucceeds(
        db("alice")
          .ref(path)
          .update({ firstDate: 100, lastDate: 200 }),
      );
    });
  });

  describe("mark validation", () => {
    beforeEach(async () => {
      await seed(ownedLeaflet());
    });

    const valid = {
      startDate: 1000,
      endDate: 2000,
      actIcon: 5,
      isAbout: false,
      title: "Shinkansen",
      remark: "",
      link: "",
    };

    it("accepts a valid mark", async () => {
      await assertSucceeds(db("alice").ref(`marks/${LEAFLET}/m1`).set(valid));
    });

    it("rejects marks for a non-existent leaflet", async () => {
      await seed({ leafletMembers: { ZZZZZZZZZZZZ: { alice: true } } });
      await assertFails(db("alice").ref("marks/ZZZZZZZZZZZZ/m1").set(valid));
    });

    it("rejects endDate before startDate", async () => {
      await assertFails(
        db("alice")
          .ref(`marks/${LEAFLET}/m1`)
          .set({ ...valid, endDate: 500 }),
      );
    });

    it("accepts time zone ids, including the legacy empty one", async () => {
      for (const zone of ["Asia/Tokyo", "America/Argentina/Buenos_Aires", "Etc/GMT+9", ""]) {
        await assertSucceeds(
          db("alice")
            .ref(`marks/${LEAFLET}/m1`)
            .set({ ...valid, timeZoneId: zone, endTimeZoneId: zone }),
        );
      }
    });

    it("rejects a malformed or oversized time zone id", async () => {
      for (const zone of ["Asia/Tokyo; drop", "a b", "x".repeat(65), 9]) {
        await assertFails(
          db("alice")
            .ref(`marks/${LEAFLET}/m1`)
            .set({ ...valid, timeZoneId: zone }),
        );
        await assertFails(
          db("alice")
            .ref(`marks/${LEAFLET}/m1`)
            .set({ ...valid, endTimeZoneId: zone }),
        );
      }
    });
    it("rejects an out-of-range actIcon", async () => {
      await assertFails(
        db("alice")
          .ref(`marks/${LEAFLET}/m1`)
          .set({ ...valid, actIcon: 13 }),
      );
    });

    it("rejects wrong types", async () => {
      await assertFails(
        db("alice")
          .ref(`marks/${LEAFLET}/m1`)
          .set({ ...valid, startDate: "tomorrow" }),
      );
    });

    it("allows cascading delete after the leaflet is gone", async () => {
      await seed({
        leafletMembers: { ZZZZZZZZZZZZ: { alice: true } },
        marks: { ZZZZZZZZZZZZ: { m1: valid } },
      });
      await assertSucceeds(db("alice").ref("marks/ZZZZZZZZZZZZ").remove());
    });
  });

  describe("note presence", () => {
    beforeEach(async () => {
      await seed(
        ownedLeaflet({ leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } } }),
      );
    });

    const path = (uid) => `presence/notes/${LEAFLET}/${uid}`;

    const ts = { ".sv": "timestamp" };
    const valid = { at: ts, name: "A", index: 3 };

    it("lets a member set and clear only their own presence", async () => {
      await assertSucceeds(db("alice").ref(path("alice")).set(valid));
      await assertSucceeds(db("alice").ref(path("alice")).remove());
      await assertFails(db("alice").ref(path("bob")).set(valid));
    });

    it("accepts presence without a caret (editor not focused)", async () => {
      await assertSucceeds(
        db("alice").ref(path("alice")).set({ at: ts, name: "A" }),
      );
    });

    it("rejects the legacy numeric shape and missing fields", async () => {
      await assertFails(db("alice").ref(path("alice")).set(ts));
      await assertFails(db("alice").ref(path("alice")).set({ at: ts }));
      await assertFails(db("alice").ref(path("alice")).set({ name: "A" }));
    });

    it("rejects timestamps in the future", async () => {
      await assertFails(
        db("alice")
          .ref(path("alice"))
          .set({ ...valid, at: Date.now() + 60 * 60 * 1000 }),
      );
    });

    it("validates the caret index", async () => {
      for (const index of [-1, 1.5, "3", 200001]) {
        await assertFails(
          db("alice")
            .ref(path("alice"))
            .set({ ...valid, index }),
        );
      }
      await assertSucceeds(
        db("alice")
          .ref(path("alice"))
          .set({ ...valid, index: 0 }),
      );
    });

    it("validates the initial", async () => {
      for (const name of ["", "ABC", 1]) {
        await assertFails(
          db("alice")
            .ref(path("alice"))
            .set({ ...valid, name }),
        );
      }
    });

    it("rejects unknown fields", async () => {
      await assertFails(
        db("alice")
          .ref(path("alice"))
          .set({ ...valid, email: "alice@example.com" }),
      );
    });

    it("rejects presence from non-members", async () => {
      await assertFails(
        db("mallory").ref(path("mallory")).set({ at: ts, name: "M" }),
      );
    });

    it("lets members see who is editing", async () => {
      await assertSucceeds(db("bob").ref(`presence/notes/${LEAFLET}`).get());
      await assertFails(db("mallory").ref(`presence/notes/${LEAFLET}`).get());
    });

    it("keeps presence out of the note document", async () => {
      await assertFails(
        db("alice").ref(`rich_notes/${LEAFLET}/editors/alice`).set(true),
      );
    });
  });

  describe("device tokens for notifications", () => {
    const TOKEN = "t".repeat(100);
    const KEY = "0123456789abcdef".repeat(2);
    const entry = (extra = {}) => ({
      token: TOKEN,
      at: Date.now() - 1000,
      platform: "android",
      ...extra,
    });

    it("lets a user register their own token", async () => {
      await assertSucceeds(
        db("alice").ref(`users/alice/fcmTokens/${KEY}`).set(entry()),
      );
      await assertSucceeds(
        db("alice").ref(`users/alice/fcmTokens/${KEY}`).remove(),
      );
    });

    it("does not let anyone write or read another user's tokens", async () => {
      await assertFails(
        db("mallory").ref(`users/alice/fcmTokens/${KEY}`).set(entry()),
      );
      await assertFails(db(null).ref(`users/alice/fcmTokens/${KEY}`).set(entry()));
      await db("alice").ref(`users/alice/fcmTokens/${KEY}`).set(entry());
      await assertFails(db("alice").ref(`users/alice/fcmTokens`).get());
      await assertFails(db("mallory").ref(`users/alice/fcmTokens/${KEY}`).get());
      await assertFails(db("mallory").ref(`users/alice/fcmTokens/${KEY}`).remove());
    });

    it("validates the shape of a token entry", async () => {
      const path = `users/alice/fcmTokens/${KEY}`;
      await assertFails(db("alice").ref(path).set(true));
      await assertFails(db("alice").ref(path).set(entry({ platform: "web" })));
      await assertFails(db("alice").ref(path).set(entry({ at: "now" })));
      await assertFails(db("alice").ref(path).set(entry({ at: Date.now() + 3_600_000 })));
      await assertFails(db("alice").ref(path).set(entry({ extra: 1 })));
      await assertFails(db("alice").ref(path).set({ platform: "android" }));
      await assertFails(db("alice").ref(path).set(entry({ token: "short" })));
      await assertFails(db("alice").ref(path).set(entry({ token: "t".repeat(769) })));
      const { token, ...withoutToken } = entry();
      await assertFails(db("alice").ref(path).set(withoutToken));
    });

    it("requires the key to be a hash, not the token itself", async () => {
      for (const key of ["short", KEY.toUpperCase(), `${KEY}0`, TOKEN]) {
        await assertFails(
          db("alice").ref(`users/alice/fcmTokens/${key}`).set(entry()),
        );
      }
    });

    it("lets a user remove an old entry whose key is the token itself", async () => {
      await seed({ users: { alice: { fcmTokens: { [TOKEN]: { at: 1, platform: "android" } } } } });
      await assertSucceeds(db("alice").ref(`users/alice/fcmTokens/${TOKEN}`).remove());
    });

    it("lets a user delete all of their own tokens at once, but not set data there", async () => {
      await seed({
        users: {
          alice: { fcmTokens: { [KEY]: { token: TOKEN, at: 1, platform: "android" } } },
          bob: { fcmTokens: { [KEY]: { token: TOKEN, at: 1, platform: "android" } } },
        },
      });
      await assertFails(db("mallory").ref("users/alice").remove());
      await assertFails(db(null).ref("users/alice").remove());
      await assertFails(db("alice").ref("users/bob").remove());
      await assertFails(db("alice").ref("users/alice").set({ other: 1 }));
      await assertSucceeds(db("alice").ref("users/alice").remove());
      // 他の人の分は、そのまま残る。
      await assertSucceeds(db("bob").ref(`users/bob/fcmTokens/${KEY}`).remove());
    });

    it("lets a user delete their tokens even when nothing is stored", async () => {
      // 通知を許可していない人は、登録が無い。それでも、アカウントの削除の途中で失敗しない。
      await assertSucceeds(db("alice").ref("users/alice").remove());
    });

    it("keeps the notification log away from clients", async () => {
      await assertFails(db("alice").ref("notificationLog/evt1").set({ at: 1 }));
      await assertFails(db("alice").ref("notificationLog/evt1").get());
      await assertFails(db("alice").ref("notificationLog").get());
    });

    it("keeps the throttle records away from clients", async () => {
      await assertFails(db("alice").ref("notificationThrottle/LID_bob_joined").set(1));
      await assertFails(db("alice").ref("notificationThrottle/LID_bob_joined").get());
      await assertFails(db("alice").ref("notificationThrottle").get());
    });
  });

  describe("closure records", () => {
    const closure = (extra = {}) => ({
      kind: "deleted",
      title: "Hokkaido",
      at: SERVER_NOW,
      ...extra,
    });

    beforeEach(async () => {
      await seed(
        sharedLeaflet({
          leafletMembers: { [LEAFLET]: { alice: true, bob: HASH } },
          userLeaflets: { alice: { [LEAFLET]: true }, bob: { [LEAFLET]: true } },
        }),
      );
    });

    it("lets only the owner write a closure record", async () => {
      await assertSucceeds(db("alice").ref(`leafletClosures/${LEAFLET}`).set(closure()));
      await assertFails(db("bob").ref(`leafletClosures/${LEAFLET}`).set(closure()));
      await assertFails(db("mallory").ref(`leafletClosures/${LEAFLET}`).set(closure()));
      await assertFails(db(null).ref(`leafletClosures/${LEAFLET}`).set(closure()));
    });

    it("does not let anyone read it", async () => {
      await db("alice").ref(`leafletClosures/${LEAFLET}`).set(closure());
      await assertFails(db("alice").ref(`leafletClosures/${LEAFLET}`).get());
      await assertFails(db("bob").ref(`leafletClosures/${LEAFLET}`).get());
    });

    it("validates the kind, the title and the time", async () => {
      const path = `leafletClosures/${LEAFLET}`;
      await assertSucceeds(db("alice").ref(path).set(closure({ kind: "stopped" })));
      await assertFails(db("alice").ref(path).set(closure({ kind: "left" })));
      await assertFails(db("alice").ref(path).set(closure({ title: "" })));
      await assertFails(db("alice").ref(path).set(closure({ title: "x".repeat(101) })));
      await assertFails(db("alice").ref(path).set(closure({ at: Date.now() + 3_600_000 })));
      await assertFails(db("alice").ref(path).set(closure({ at: Date.now() - 3_600_000 })));
      await assertFails(db("alice").ref(path).set(closure({ extra: 1 })));
      await assertFails(db("alice").ref(path).set({ kind: "deleted", title: "t" }));
    });

    it("can be written in the same update that deletes the leaflet", async () => {
      await assertSucceeds(
        db("alice")
          .ref()
          .update({
            [`leaflets/${LEAFLET}`]: null,
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
            [`leafletClosures/${LEAFLET}`]: closure(),
          }),
      );
    });

    it("can be written in the same update that stops sharing", async () => {
      await assertSucceeds(
        db("alice")
          .ref()
          .update({
            [`leafletSecrets/${LEAFLET}`]: null,
            [`leaflets/${LEAFLET}/shared`]: null,
            [`leafletMembers/${LEAFLET}/bob`]: null,
            [`userLeaflets/bob/${LEAFLET}`]: null,
            [`leafletClosures/${LEAFLET}`]: closure({ kind: "stopped" }),
          }),
      );
    });

    it("lets the owner remove a stale record", async () => {
      await db("alice").ref(`leafletClosures/${LEAFLET}`).set(closure());
      await assertSucceeds(db("alice").ref(`leafletClosures/${LEAFLET}`).remove());
    });
  });

  describe("separation between leaflets", () => {
    const OTHER = "ZZZZZZZZZZZZ";

    beforeEach(async () => {
      // alice は LEAFLET のオーナー、bob は別のしおり OTHER のオーナー。
      const data = sharedLeaflet();
      data.leaflets[OTHER] = { title: "Kyoto", ownerUid: "bob" };
      data.leafletMembers[OTHER] = { bob: true };
      data.userLeaflets.bob = { [OTHER]: true };
      data.marks = {
        [OTHER]: { m1: { startDate: 1, title: "Kyoto station" } },
      };
      data.rich_notes = { [OTHER]: { text: "[]" } };
      await seed(data);
    });

    it("does not let a member read another leaflet's data", async () => {
      await assertFails(db("alice").ref(`leaflets/${OTHER}`).get());
      await assertFails(db("alice").ref(`marks/${OTHER}`).get());
      await assertFails(db("alice").ref(`rich_notes/${OTHER}`).get());
      await assertFails(db("alice").ref(`presence/notes/${OTHER}`).get());
    });

    it("does not let a member write another leaflet's data", async () => {
      await assertFails(
        db("alice")
          .ref(`marks/${OTHER}/m2`)
          .set({ startDate: 2, title: "hack" }),
      );
      await assertFails(
        db("alice").ref(`rich_notes/${OTHER}`).update({ text: "hack" }),
      );
      await assertFails(db("alice").ref(`leaflets/${OTHER}/title`).set("hack"));
      await assertFails(db("alice").ref(`leaflets/${OTHER}`).remove());
    });

    it("does not let a secret of one leaflet open another", async () => {
      // bob の LEAFLET 用のあいことばハッシュは、OTHER には使えない。
      await assertFails(
        db("carol")
          .ref()
          .update({
            [`leafletMembers/${OTHER}/carol`]: HASH,
            [`userLeaflets/carol/${OTHER}`]: true,
          }),
      );
    });

    it("does not let an owner touch another owner's members or secret", async () => {
      await assertFails(db("alice").ref(`leafletMembers/${OTHER}/bob`).remove());
      await assertFails(db("alice").ref(`leafletSecrets/${OTHER}`).set(HASH));
      await assertFails(db("alice").ref(`leafletMembers/${OTHER}`).get());
    });

    it("keeps a stray index entry from exposing a leaflet", async () => {
      await db("alice").ref(`userLeaflets/alice/${OTHER}`).set(true);
      await assertFails(db("alice").ref(`leaflets/${OTHER}`).get());
    });

    it("rejects an index value other than true", async () => {
      await assertFails(
        db("alice").ref(`userLeaflets/alice/${OTHER}`).set("yes"),
      );
      await assertFails(
        db("alice").ref(`userLeaflets/alice/${OTHER}`).set(false),
      );
    });
  });
});
