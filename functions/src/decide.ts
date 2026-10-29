/** 共同編集のメンバーの登録（`leafletMembers/{lid}`）。オーナーは `true`、参加者はあいことばのハッシュ（文字列）。 */
export type Members = Record<string, true | string> | null | undefined;

/** 削除と停止のときに、オーナーが同じ更新で書く「閉鎖の記録」。 */
export type ClosureKind = "deleted" | "stopped";

export interface Closure {
  kind: ClosureKind;
  title: string;
  /** サーバー時刻（ミリ秒）。 */
  at: number;
}

/** 通知の種類。 */
export type NotificationType = "joined" | "left" | ClosureKind;

/** 閉鎖の記録を、この時間（ミリ秒）より古いものは使わない。自分で抜けたことの誤判定を防ぐ。 */
export const CLOSURE_MAX_AGE_MS = 5 * 60 * 1000;

export type Decision =
  | { type: "joined" | "left"; ownerUid: string; memberUid: string }
  | {
      type: ClosureKind;
      ownerUid: string | null;
      recipients: string[];
      title: string;
    };

/** オーナーの uid。メンバーの値が `true` の人。しおりが消えた後でも、メンバーの記録だけで決まる。 */
export function ownerOf(...maps: Members[]): string | null {
  for (const members of maps) {
    for (const [uid, value] of Object.entries(members ?? {})) {
      if (value === true) return uid;
    }
  }
  return null;
}

/** 参加者（値が文字列）の uid。 */
function participants(members: Members): Set<string> {
  const result = new Set<string>();
  for (const [uid, value] of Object.entries(members ?? {})) {
    if (typeof value === "string") result.add(uid);
  }
  return result;
}

/** 新しく加わった参加者。 */
export function joinedMembers(before: Members, after: Members): string[] {
  const was = participants(before);
  return [...participants(after)].filter((uid) => !was.has(uid));
}

/** 消えた参加者。 */
export function removedMembers(before: Members, after: Members): string[] {
  const now = new Set(Object.keys(after ?? {}));
  return [...participants(before)].filter((uid) => !now.has(uid));
}

/** 閉鎖の記録を取り出す。形が正しくなければ null。 */
export function parseClosure(value: unknown): Closure | null {
  if (typeof value !== "object" || value === null) return null;
  const { kind, title, at } = value as Record<string, unknown>;
  if (kind !== "deleted" && kind !== "stopped") return null;
  if (typeof title !== "string" || title.length === 0) return null;
  if (typeof at !== "number" || !Number.isFinite(at)) return null;
  return { kind, title, at };
}

/** 閉鎖の記録が、このイベントの直前に書かれたものか。 */
export function isFresh(closure: Closure, eventTimeMs: number): boolean {
  return Math.abs(eventTimeMs - closure.at) <= CLOSURE_MAX_AGE_MS;
}

/**
 * メンバーの変化と閉鎖の記録から、送る通知を決める。
 *
 * - 参加者が増えた：オーナーへ「参加」。
 * - 参加者が消え、新しい閉鎖の記録がある：消えた参加者へ「削除」か「停止」。
 * - 参加者が消えたが、閉鎖の記録が無い（古い）：自分で抜けたので、オーナーへ「脱退」。
 *
 * 操作したオーナーは、参加者ではないので、宛先に入らない。
 */
export function decide(input: {
  before: Members;
  after: Members;
  closure: Closure | null;
  eventTimeMs: number;
}): Decision[] {
  const { before, after, closure, eventTimeMs } = input;
  const decisions: Decision[] = [];
  const ownerUid = ownerOf(after, before);

  if (ownerUid !== null) {
    for (const memberUid of joinedMembers(before, after)) {
      decisions.push({ type: "joined", ownerUid, memberUid });
    }
  }

  const removed = removedMembers(before, after);
  if (removed.length > 0 && closure !== null && isFresh(closure, eventTimeMs)) {
    decisions.push({
      type: closure.kind,
      ownerUid,
      recipients: removed,
      title: closure.title,
    });
  } else if (ownerUid !== null) {
    for (const memberUid of removed) {
      decisions.push({ type: "left", ownerUid, memberUid });
    }
  }
  return decisions;
}
