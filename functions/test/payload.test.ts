import assert from "node:assert/strict";
import { buildMessage, textsFor } from "../src/payload";

describe("notification payload", () => {
  const base = { token: "tok", leafletId: "LID", title: "Hokkaido" };

  it("joined: title and nickname, grouped by trip and kind", () => {
    const message = buildMessage({
      ...base,
      type: "joined",
      actor: "Sakura",
      memberUid: "bob",
    });
    assert.equal(message.android?.notification?.titleLocKey, "notif_joined_title");
    assert.equal(message.android?.notification?.bodyLocKey, "notif_joined_body");
    assert.deepEqual(message.android?.notification?.bodyLocArgs, [
      "Hokkaido",
      "Sakura",
    ]);
    assert.equal(message.android?.notification?.tag, "LID:joined:bob");
    assert.deepEqual(message.data, {
      type: "joined",
      leafletId: "LID",
      title: "Hokkaido",
      actor: "Sakura",
    });
    assert.equal("token" in message && message.token, "tok");
  });

  it("deleted and stopped: owner nickname and title", () => {
    for (const type of ["deleted", "stopped"] as const) {
      const message = buildMessage({ ...base, type, actor: "Aki" });
      assert.equal(
        message.android?.notification?.titleLocKey,
        "notif_unavailable_title",
      );
      assert.equal(message.android?.notification?.bodyLocKey, `notif_${type}_body`);
      assert.deepEqual(message.android?.notification?.bodyLocArgs, [
        "Aki",
        "Hokkaido",
      ]);
      assert.equal(message.android?.notification?.tag, `LID:${type}`);
    }
  });

  it("keeps the notifications of two friends apart, but groups closures", () => {
    const tag = (type: "joined" | "left" | "deleted" | "stopped", memberUid?: string) =>
      buildMessage({ ...base, type, actor: "x", memberUid }).android?.notification?.tag;

    // Android は、同じ tag の通知を置き換える。2 人目が 1 人目を消さないよう、参加はメンバーごと。
    assert.notEqual(tag("joined", "bob"), tag("joined", "carol"));
    assert.notEqual(tag("left", "bob"), tag("left", "carol"));
    assert.notEqual(tag("left", "bob"), tag("joined", "bob"));
    // 削除と停止は、しおりと種類で、1 つにまとめる。
    assert.equal(tag("deleted"), "LID:deleted");
    assert.equal(tag("stopped"), "LID:stopped");
  });

  it("words a leave for the owner with the title and the nickname", () => {
    const message = buildMessage({ ...base, type: "left", actor: "Aki", memberUid: "bob" });
    const notification = message.android?.notification;
    assert.equal(notification?.titleLocKey, "notif_left_title");
    assert.equal(notification?.bodyLocKey, "notif_left_body");
    assert.deepEqual(notification?.bodyLocArgs, ["Hokkaido", "Aki"]);
    assert.equal(notification?.tag, "LID:left:bob");
  });

  it("uses the nameless wording when there is no nickname", () => {
    for (const type of ["joined", "left"] as const) {
      const texts = textsFor({ type, title: "T", actor: "" });
      assert.equal(texts.bodyKey, `notif_${type}_body_anonymous`);
      assert.deepEqual(texts.args, ["T"]);
    }
    for (const type of ["deleted", "stopped"] as const) {
      const texts = textsFor({ type, title: "T", actor: "" });
      assert.equal(texts.bodyKey, `notif_${type}_body_anonymous`);
      assert.deepEqual(texts.args, ["T"]);
    }
  });

  it("mirrors the keys for iOS and sends no literal text that would beat the loc keys", () => {
    const message = buildMessage({ ...base, type: "stopped", actor: "Aki" });
    const alert = message.apns?.payload?.aps?.alert;
    assert.ok(alert && typeof alert === "object");
    assert.equal(alert.titleLocKey, "notif_unavailable_title");
    assert.equal(alert.locKey, "notif_stopped_body");
    assert.deepEqual(alert.locArgs, ["Aki", "Hokkaido"]);
    // Android の FCM クライアントは、title と body があると、loc key より先に使う。
    assert.equal(message.notification, undefined);
  });
});
