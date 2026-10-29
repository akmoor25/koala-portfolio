import assert from "node:assert/strict";
import {
  NICKNAME_MAX_LENGTH,
  TITLE_MAX_LENGTH,
  sanitizeNickname,
  sanitizeTitle,
} from "../src/nickname";

describe("sanitizeNickname", () => {
  it("keeps an ordinary name", () => {
    assert.equal(sanitizeNickname("アキ"), "アキ");
    assert.equal(sanitizeNickname("Pixel 10a"), "Pixel 10a");
  });

  it("returns an empty string when there is nothing to show", () => {
    for (const raw of [null, undefined, "", "   ", "\u0000\u0007", "\u200B\uFEFF"]) {
      assert.equal(sanitizeNickname(raw), "", JSON.stringify(raw));
    }
  });

  it("cuts a long name by visible characters", () => {
    const name = sanitizeNickname("あ".repeat(50));
    assert.equal(Array.from(name).length, NICKNAME_MAX_LENGTH);
  });

  it("does not split an emoji sequence", () => {
    const family = "👨‍👩‍👧";
    assert.equal(sanitizeNickname(family.repeat(30)), family.repeat(NICKNAME_MAX_LENGTH));
  });

  it("turns control and direction-changing characters inside a name into a space", () => {
    assert.equal(sanitizeNickname("a\u0000b\u202Ec"), "a b c");
  });
});

describe("sanitizeTitle", () => {
  it("removes control, direction and zero-width characters", () => {
    const raw = "\u202EHok\u200Bkai\u200Edo\u2060\uFEFF\u0007";
    assert.equal(sanitizeTitle(raw), "Hokkaido");
  });

  it("turns line breaks and runs of spaces into one space", () => {
    assert.equal(sanitizeTitle("A\n\nB   C"), "A B C");
  });

  it("keeps the joiners that emoji and some scripts need", () => {
    assert.equal(sanitizeTitle("🏳️‍🌈 trip"), "🏳️‍🌈 trip");
  });

  it("limits the length to the one the rules allow", () => {
    assert.equal(Array.from(sanitizeTitle("x".repeat(500))).length, TITLE_MAX_LENGTH);
  });
});
