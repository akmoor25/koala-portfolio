/** ニックネームの最大の長さ（見た目の文字数）。アプリの `NicknamePolicy` と同じ。 */
export const NICKNAME_MAX_LENGTH = 20;

const segmenter = new Intl.Segmenter("en", { granularity: "grapheme" });

/** しおりのタイトルの最大の長さ（見た目の文字数）。ルールの上限（100）と同じ。 */
export const TITLE_MAX_LENGTH = 100;

/** 制御文字と、表示の向きを変える文字。空白に置き換える。 */
const UNSAFE = /[\p{Cc}\u202A-\u202E\u2066-\u2069]/gu;

/**
 * 見えない文字。取り除く。
 *
 * ゼロ幅の空白（U+200B）、左右の向きの印（U+200E、U+200F）、単語の結合子（U+2060）、BOM（U+FEFF）。
 * ZWJ（U+200D）と ZWNJ（U+200C）は、絵文字の連結（家族、虹の旗など）や、一部の言語の表記で
 * 意味を持つため、取り除かない。
 */
const INVISIBLE = /[\u200B\u200E\u200F\u2060\uFEFF]/gu;

/**
 * 利用者が書いた文字列を、通知に入れられる形にする。
 *
 * 不正なクライアントが長い文字列や制御文字を入れても、通知を壊さないための、サーバー側の砦。
 * 空になったときは空の文字列を返す。
 */
export function sanitizeText(raw: string | null | undefined, maxLength: number): string {
  if (!raw) return "";
  const cleaned = raw
    .replace(INVISIBLE, "")
    .replace(UNSAFE, " ")
    .replace(/\s+/gu, " ")
    .trim();
  const graphemes = Array.from(segmenter.segment(cleaned), (s) => s.segment);
  return graphemes.slice(0, maxLength).join("").trim();
}

/** ニックネーム。空なら、呼び出し側が「名前なし」の文言にする。 */
export function sanitizeNickname(raw: string | null | undefined): string {
  return sanitizeText(raw, NICKNAME_MAX_LENGTH);
}

/** しおりのタイトル。クライアントが書いた値なので、ニックネームと同じく通す。 */
export function sanitizeTitle(raw: string | null | undefined): string {
  return sanitizeText(raw, TITLE_MAX_LENGTH);
}
