import assert from "node:assert/strict";
import {
  CLOSURE_MAX_AGE_MS,
  Closure,
  Members,
  decide,
  joinedMembers,
  ownerOf,
  parseClosure,
  removedMembers,
} from "../src/decide";

const HASH = "a".repeat(64);
const NOW = Date.UTC(2026, 9, 12, 12, 0, 0);

const closure = (kind: Closure["kind"], ageMs = 1000): Closure => ({
  kind,
  title: "Hokkaido",
  at: NOW - ageMs,
});

describe("members diff", () => {
  const owner: Members = { alice: true };
  const withBob: Members = { alice: true, bob: HASH };

  it("finds the owner by the true value", () => {
    assert.equal(ownerOf(withBob), "alice");
    assert.equal(ownerOf(null, withBob), "alice");
    assert.equal(ownerOf({ bob: HASH }), null);
    assert.equal(ownerOf(null), null);
  });

  it("finds who joined and who was removed", () => {
    assert.deepEqual(joinedMembers(owner, withBob), ["bob"]);
    assert.deepEqual(removedMembers(withBob, owner), ["bob"]);
    assert.deepEqual(joinedMembers(withBob, owner), []);
    assert.deepEqual(removedMembers(owner, withBob), []);
  });

  it("never treats the owner as a participant", () => {
    assert.deepEqual(joinedMembers(null, owner), []);
    assert.deepEqual(removedMembers(owner, null), []);
  });
});

describe("parseClosure", () => {
  it("accepts a valid record", () => {
    assert.deepEqual(parseClosure({ kind: "deleted", title: "t", at: 5 }), {
      kind: "deleted",
      title: "t",
      at: 5,
    });
  });

  it("rejects malformed records", () => {
    for (const bad of [
      null,
      "x",
      {},
      { kind: "left", title: "t", at: 1 },
      { kind: "deleted", title: "", at: 1 },
      { kind: "deleted", title: "t" },
      { kind: "deleted", title: "t", at: "1" },
    ]) {
      assert.equal(parseClosure(bad), null, JSON.stringify(bad));
    }
  });
});

describe("decide", () => {
  const owner: Members = { alice: true };
  const withBob: Members = { alice: true, bob: HASH };
  const withBoth: Members = { alice: true, bob: HASH, carol: HASH };
  const decideWith = (
    before: Members,
    after: Members,
    c: Closure | null = null,
  ) => decide({ before, after, closure: c, eventTimeMs: NOW });

  it("tells the owner that a friend joined", () => {
    assert.deepEqual(decideWith(owner, withBob), [
      { type: "joined", ownerUid: "alice", memberUid: "bob" },
    ]);
  });

  it("makes one decision for each friend who joined", () => {
    const result = decideWith(owner, withBoth);
    assert.deepEqual(
      result.map((d) => d.type === "joined" && d.memberUid).sort(),
      ["bob", "carol"],
    );
  });

  it("does not notify when the owner creates a leaflet", () => {
    assert.deepEqual(decideWith(null, owner), []);
  });

  it("tells every removed friend that the leaflet was deleted", () => {
    assert.deepEqual(decideWith(withBoth, owner, closure("deleted")), [
      {
        type: "deleted",
        ownerUid: "alice",
        recipients: ["bob", "carol"],
        title: "Hokkaido",
      },
    ]);
  });

  it("tells every removed friend that sharing was stopped", () => {
    const [decision] = decideWith(withBob, owner, closure("stopped"));
    assert.equal(decision.type, "stopped");
    assert.deepEqual("recipients" in decision && decision.recipients, ["bob"]);
  });

  it("never sends to the owner who closed it", () => {
    for (const kind of ["deleted", "stopped"] as const) {
      const decisions = decideWith(withBob, owner, closure(kind));
      for (const d of decisions) {
        assert.ok(!("recipients" in d) || !d.recipients.includes("alice"));
      }
    }
  });

  it("tells the owner when a friend leaves by themselves", () => {
    assert.deepEqual(decideWith(withBob, owner), [
      { type: "left", ownerUid: "alice", memberUid: "bob" },
    ]);
    assert.deepEqual(decideWith(withBoth, { alice: true, carol: HASH }), [
      { type: "left", ownerUid: "alice", memberUid: "bob" },
    ]);
  });

  it("does not report a leave when the owner closed the leaflet", () => {
    for (const kind of ["deleted", "stopped"] as const) {
      const types: string[] = decideWith(withBoth, owner, closure(kind)).map(
        (d) => d.type,
      );
      assert.deepEqual(types, [kind]);
    }
  });

  it("reads a closure record that is too old as a leave", () => {
    const stale = closure("stopped", CLOSURE_MAX_AGE_MS + 1);
    assert.deepEqual(decideWith(withBob, owner, stale), [
      { type: "left", ownerUid: "alice", memberUid: "bob" },
    ]);
  });

  it("has no one to tell when the owner is unknown", () => {
    assert.deepEqual(decideWith({ bob: HASH }, null), []);
  });

  it("uses a closure record only when someone was removed", () => {
    assert.deepEqual(decideWith(owner, owner, closure("deleted")), []);
  });

  it("stays silent when the owner removes their own record last", () => {
    assert.deepEqual(decideWith(owner, null, closure("deleted")), []);
  });

  it("still finds the owner when the leaflet record is gone", () => {
    const [decision] = decideWith(withBob, null, closure("deleted"));
    assert.equal(decision.type, "deleted");
    assert.equal(decision.ownerUid, "alice");
  });
});
