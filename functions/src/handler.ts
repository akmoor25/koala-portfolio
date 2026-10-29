import { createHash } from "node:crypto";
import type { Database } from "firebase-admin/database";
import type { Message } from "firebase-admin/messaging";
import {
  Closure,
  Decision,
  Members,
  decide,
  isFresh,
  joinedMembers,
  parseClosure,
  removedMembers,
} from "./decide";
import { sanitizeNickname, sanitizeTitle } from "./nickname";
import { buildMessage } from "./payload";

/**
 * 同じ（しおり、メンバー、種類）の通知を出さない時間。参加と脱退の連打を抑える。
 *
 * 3 秒にした理由：当初は 60 秒だったが、実機で、抜けて数秒で入り直した通知が出なかった。
 * 人が操作できる速さの連打（誤操作、通信の揺れ）だけを抑える値にした。
 * 確認と書き込みは不可分ではないので、同時に届いた別のイベントは、両方通りうる。
 * 通知が 1 件多いだけで害はないため、厳密にしない割り切りとした。
 */
export const THROTTLE_MS = 3 * 1000;

/**
 * 送信の予約（pending）が、この時間を過ぎても済みにならなければ、実行が途中で落ちたとみなし、取り直せる。
 *
 * 予約したあとに、タイムアウトなどで関数が強制終了すると、予約だけが残る。取り直せないと、その通知は
 * 二度と送られない。取り直せるようにすると、送信の直後に落ちた場合は、同じ通知が 2 回届きうる。
 * 「重複を防ぎつつ、取りこぼさない」ことを優先し、まれな重複を許す（少なくとも 1 回の配信）。
 */
export const PENDING_TTL_MS = 60 * 1000;

/** これより古いイベントは、通知として古すぎるので捨てる（再試行が長引いたとき）。 */
export const MAX_EVENT_AGE_MS = 10 * 60 * 1000;

/** 送信の結果。`code` は FCM のエラーコード。 */
export type SendResult = { ok: true } | { ok: false; code: string };

/** 関数が外の世界とやりとりする部分。テストでは、これを差し替える。 */
export interface Deps {
  db: Database;
  /** Firebase Authentication の表示名。 */
  displayName(uid: string): Promise<string | null>;
  /** メッセージを送り、1 件ごとの結果を同じ順で返す。 */
  send(messages: Message[]): Promise<SendResult[]>;
  /** 現在時刻（ミリ秒）。 */
  now(): number;
  /** 想定外の出来事を、警告として残す。トークンそのものは渡さない。 */
  warn(message: string, data: Record<string, unknown>): void;
}

/** `leafletMembers/{lid}` の書き込みのイベント。 */
export interface MembersEvent {
  id: string;
  timeMs: number;
  leafletId: string;
  before: Members;
  after: Members;
}

export interface HandleResult {
  /** 何もしなかった理由、または `sent`。 */
  outcome:
    | "no-change"
    | "stale-event"
    | "no-owner"
    | "duplicate"
    | "throttled"
    | "no-tokens"
    | "sent";
  sent: number;
  removedTokens: number;
}

/** 時間をおけば成功しうる失敗。再試行する。送信の上限に当たったときを含む。 */
const TRANSIENT = new Set([
  "messaging/internal-error",
  "messaging/server-unavailable",
  "messaging/unknown-error",
  "messaging/quota-exceeded",
  "messaging/message-rate-exceeded",
  "messaging/device-message-rate-exceeded",
  "messaging/topics-message-rate-exceeded",
]);
const INVALID_TOKEN = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/** データベースのキーに使えない文字を置き換える。 */
export function safeKey(value: string): string {
  return value.replace(/[.#$[\]/]/g, "_");
}

/**
 * 送信の記録のキーの長さ（SHA-256 の 16 進数 64 文字のうち、先頭から使う文字数）。
 * アプリ（`lib/notifications/token_key.dart`）とルールも同じ長さを使う。
 */
const TOKEN_KEY_LENGTH = 32;

/** 端末のトークンから、送信の記録のキーを作る（トークンそのものを、記録に残さない）。 */
export function tokenKey(token: string): string {
  return createHash("sha256").update(token).digest("hex").slice(0, TOKEN_KEY_LENGTH);
}

/**
 * メンバーの変化から、必要な通知を送る。
 *
 * 流れ：差分と閉鎖の記録から宛先を決める → 連打を抑える → 宛先のトークンを集める →
 * （イベント ID、トークン）ごとに送信を予約する → 送る → 無効なトークンを消す → 閉鎖の記録を消す。
 *
 * 二重送信の防止は、イベント全体ではなく、（イベント ID、端末のトークン）ごとに記録する。
 * 宛先が複数のとき、一部だけ失敗して再試行されても、成功した端末には、もう送らない。
 * 一時的な失敗のときは、失敗した端末の予約だけを戻して、例外を投げ、再試行に任せる。
 * 予約は pending で取り、送信のあとに sent か failed にする。実行が落ちて pending が残っても、
 * PENDING_TTL_MS を過ぎれば取り直せる（少なくとも 1 回の配信。まれな重複を許す）。
 */
export async function handleMembersChange(
  deps: Deps,
  event: MembersEvent,
): Promise<HandleResult> {
  const { db } = deps;
  const none = (outcome: HandleResult["outcome"]): HandleResult => ({
    outcome,
    sent: 0,
    removedTokens: 0,
  });

  const joined = joinedMembers(event.before, event.after);
  const removed = removedMembers(event.before, event.after);
  if (joined.length === 0 && removed.length === 0) return none("no-change");
  if (deps.now() - event.timeMs > MAX_EVENT_AGE_MS) return none("stale-event");

  let closure: Closure | null = null;
  const closureRef = db.ref(`leafletClosures/${event.leafletId}`);
  if (removed.length > 0) {
    closure = parseClosure((await closureRef.get()).val());
  }
  const decisions = decide({
    before: event.before,
    after: event.after,
    closure,
    eventTimeMs: event.timeMs,
  });
  const closureUsed = decisions.some((d) => d.type === "deleted" || d.type === "stopped");
  if (closure !== null && !isFresh(closure, event.timeMs)) {
    await closureRef.remove();
  }
  if (decisions.length === 0) return none(removed.length > 0 ? "no-owner" : "no-change");

  const result = await deliver(deps, event, decisions, closure);
  // 例外にならなかった（送り終えた、すでに送ってあった、抑えた、宛先が無い）ので、閉鎖の記録は、もう要らない。
  // 例外のとき（一時的な失敗）は、再試行でもう一度読むので、残す。
  if (closureUsed) await closureRef.remove();
  return result;
}

/** 参加と脱退は、メンバーについての通知で、オーナーへ送る。 */
function isAboutMember(
  decision: Decision,
): decision is Extract<Decision, { memberUid: string }> {
  return decision.type === "joined" || decision.type === "left";
}

interface Target {
  uid: string;
  token: string;
  /** このトークンを持つ、`fcmTokens` の子のキー（旧形式と新形式が混ざりうる）。 */
  keys: string[];
  message: Message;
}

async function deliver(
  deps: Deps,
  event: MembersEvent,
  decisions: Decision[],
  closure: Closure | null,
): Promise<HandleResult> {
  const { db } = deps;
  const targets: Target[] = [];
  const throttleKeys: string[] = [];
  let throttled = 0;

  for (const decision of decisions) {
    const subject = isAboutMember(decision)
      ? decision.memberUid
      : (decision.ownerUid ?? "owner");
    const throttleKey = `${safeKey(event.leafletId)}_${safeKey(subject)}_${decision.type}`;
    const last = (await db.ref(`notificationThrottle/${throttleKey}`).get()).val();
    if (typeof last === "number" && deps.now() - last < THROTTLE_MS) {
      throttled++;
      continue;
    }

    const recipients = isAboutMember(decision)
      ? [decision.ownerUid]
      : decision.recipients;
    const tokens = await tokensOf(db, recipients);
    if (tokens.length === 0) continue;

    // タイトルも、クライアントが書いた値なので、ニックネームと同じく無害化する。
    const title = sanitizeTitle(
      isAboutMember(decision)
        ? await titleOf(db, event.leafletId)
        : (closure?.title ?? decision.title),
    );
    // 参加と脱退は、しおりが無くなっている（削除と同時など）ときは、伝える意味がない。
    if (isAboutMember(decision) && title === "") continue;
    const actorUid = isAboutMember(decision) ? decision.memberUid : decision.ownerUid;
    const actor = actorUid === null ? "" : await nicknameOf(deps, actorUid);

    for (const { uid, token, keys } of tokens) {
      targets.push({
        uid,
        token,
        keys,
        message: buildMessage({
          token,
          type: decision.type,
          leafletId: event.leafletId,
          title,
          actor,
          // 参加の通知は、メンバーごとに別の通知にする（同じ tag だと、2 人目が 1 人目を置き換える）。
          memberUid: isAboutMember(decision) ? decision.memberUid : undefined,
        }),
      });
    }
    throttleKeys.push(throttleKey);
  }

  if (targets.length === 0) {
    return {
      outcome: throttled > 0 ? "throttled" : "no-tokens",
      sent: 0,
      removedTokens: 0,
    };
  }

  // （イベント ID、トークン）ごとに、送信を予約する（pending）。済みの端末には送らない。
  // 別の実行が送信中（pending で、まだ新しい）の端末があれば、あとで確かめるため、最後に例外を投げて再試行に任せる。
  const reserved: Target[] = [];
  let inFlight = 0;
  for (const target of targets) {
    const state = await reserve(db, event.id, target.token, deps.now());
    if (state === "reserved") reserved.push(target);
    else if (state === "in-flight") inFlight++;
  }
  if (reserved.length === 0) {
    if (inFlight > 0) throw new Error("Another run is sending this notification; retrying");
    return { outcome: "duplicate", sent: 0, removedTokens: 0 };
  }

  let results: SendResult[];
  try {
    results = await deps.send(reserved.map((t) => t.message));
  } catch (error) {
    await release(db, event.id, reserved);
    throw error;
  }

  let removedTokens = 0;
  let sent = 0;
  const failed: Target[] = [];
  for (const [index, result] of results.entries()) {
    const target = reserved[index];
    if (result.ok) {
      sent++;
      await settle(db, event.id, target, "sent");
    } else if (INVALID_TOKEN.has(result.code)) {
      for (const key of target.keys) {
        await db.ref(`users/${safeKey(target.uid)}/fcmTokens/${key}`).remove();
      }
      removedTokens++;
      await settle(db, event.id, target, "failed");
    } else if (TRANSIENT.has(result.code)) {
      failed.push(target);
    } else {
      // 想定外のコード。たとえば、APNs の設定の誤り（third-party-auth-error）は、再試行しても直らないので、
      // 再試行はせず、見つけられるよう警告に残す（iOS は実機で確認できないため、特に重要）。
      deps.warn("Unexpected FCM error", {
        code: result.code,
        uid: target.uid,
        leafletId: event.leafletId,
        eventId: event.id,
      });
      await settle(db, event.id, target, "failed");
    }
  }
  if (failed.length > 0) {
    // 失敗した端末の予約だけを戻す。成功した端末は、再試行で、もう送らない。
    await release(db, event.id, failed);
    throw new Error("A transient failure while sending; retrying");
  }
  // 連打の記録は、例外を投げる経路では書かない（再試行が、連打として抑えられてしまうため）。
  if (inFlight > 0) throw new Error("Another run is sending this notification; retrying");

  const at = deps.now();
  for (const key of throttleKeys) {
    await db.ref(`notificationThrottle/${key}`).set(at);
  }
  return { outcome: "sent", sent, removedTokens };
}

function logRef(db: Database, eventId: string, token: string) {
  return db.ref(`notificationLog/${safeKey(eventId)}/${tokenKey(token)}`);
}

type ReserveState = "reserved" | "done" | "in-flight";

interface Pending {
  status: "pending";
  at?: unknown;
}

function isPending(value: unknown): value is Pending {
  return (
    typeof value === "object" &&
    value !== null &&
    (value as { status?: unknown }).status === "pending"
  );
}

/** pending のまま、PENDING_TTL_MS を過ぎている（実行が途中で落ちたとみなせる）。 */
function isStalePending(value: unknown, now: number): boolean {
  if (!isPending(value)) return false;
  return !(typeof value.at === "number" && now - value.at < PENDING_TTL_MS);
}

/**
 * 送信を予約する。トランザクションなので、同時に動いた実行のうち、1 つだけが取れる。
 *
 * - まだ無い、または、pending のまま古い：取れる（reserved）。
 * - sent か failed（旧形式の記録を含む）：済み（done）。送らない。
 * - 新しい pending：別の実行が送信中（in-flight）。
 */
async function reserve(
  db: Database,
  eventId: string,
  token: string,
  now: number,
): Promise<ReserveState> {
  const result = await logRef(db, eventId, token).transaction((current) => {
    if (current === null || isStalePending(current, now)) {
      return { status: "pending", at: now };
    }
    return undefined;
  });
  if (result.committed) return "reserved";
  return isPending(result.snapshot.val()) ? "in-flight" : "done";
}

/** 送信の結果を、予約に書く。 */
async function settle(
  db: Database,
  eventId: string,
  target: Target,
  status: "sent" | "failed",
): Promise<void> {
  await logRef(db, eventId, target.token).child("status").set(status);
}

async function release(db: Database, eventId: string, targets: Target[]): Promise<void> {
  for (const target of targets) {
    await logRef(db, eventId, target.token).remove();
  }
}

/**
 * 宛先の端末のトークンを集める。
 *
 * 新しい形式は、キーがトークンのハッシュで、トークンは値（`token`）に持つ。古い形式は、キーがトークンそのもの。
 * 移行の間は両方を読み、同じトークンは 1 件にまとめる。
 */
async function tokensOf(
  db: Database,
  uids: string[],
): Promise<{ uid: string; token: string; keys: string[] }[]> {
  const found: { uid: string; token: string; keys: string[] }[] = [];
  for (const uid of new Set(uids)) {
    const snapshot = await db.ref(`users/${safeKey(uid)}/fcmTokens`).get();
    const keysByToken = new Map<string, string[]>();
    snapshot.forEach((child) => {
      const value = child.val();
      const token = typeof value?.token === "string" ? value.token : child.key;
      if (!token || child.key === null) return;
      keysByToken.set(token, [...(keysByToken.get(token) ?? []), child.key]);
    });
    for (const [token, keys] of keysByToken) found.push({ uid, token, keys });
  }
  return found;
}

async function titleOf(db: Database, leafletId: string): Promise<string> {
  const value = (await db.ref(`leaflets/${leafletId}/title`).get()).val();
  return typeof value === "string" ? value : "";
}

async function nicknameOf(deps: Deps, uid: string): Promise<string> {
  try {
    return sanitizeNickname(await deps.displayName(uid));
  } catch {
    return "";
  }
}
