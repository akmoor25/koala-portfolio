import type { App } from "firebase-admin/app";
import type { Auth } from "firebase-admin/auth";
import type { Database } from "firebase-admin/database";

/** しおり ID をキーにして持つ場所。 */
export const PER_LEAFLET_PATHS = [
  "marks",
  "rich_notes",
  "leafletSecrets",
  "leafletMembers",
  "leafletClosures",
  "presence/notes",
] as const;

/** 通知の二重送信の防止と連打の抑制の記録は、役目が数分で終わるので、これより古いものを消す。 */
export const NOTIFICATION_STATE_MAX_AGE_MS = 24 * 60 * 60 * 1000;

/** 1 回の更新で書き換えるパスの数。 */
const UPDATE_CHUNK = 200;

/** Authentication に、1 回で問い合わせられる ID の数（`getUsers` の上限）。 */
const AUTH_BATCH = 100;

/** Authentication の uid として、あり得る長さ。 */
const UID_MAX_LENGTH = 128;

/** 掃除が外の世界に頼る部分。テストでは差し替える。 */
export interface CleanupDeps {
  db: Database;
  now: () => number;
  /** [path] の直下のキーだけを返す（中身は読まない）。 */
  shallowKeys: (path: string) => Promise<string[]>;
  /** [uids] のうち、Authentication にもう無いものを返す。確かめられなかったときは、投げる。 */
  missingUids: (uids: string[]) => Promise<Set<string>>;
}

/** 持ち主のユーザーがいなくなって、消すしおり。 */
export interface RemovedLeaflet {
  id: string;
  title: string;
  ownerUid: string;
  /** メンバー（オーナーを含む）の uid。 */
  members: string[];
}

export interface CleanupPlan {
  /** 持ち主がいなくなったしおり。 */
  removedLeaflets: RemovedLeaflet[];
  /** 持ち主の記録（`ownerUid`）が無いので、判断できずに残したしおりの数。 */
  unownedLeaflets: number;
  /** しおりが無いのに残っている、旅程・ノートなど。 */
  orphans: string[];
  /** 消えるしおり、または元から無いしおりを指す、各人の索引。 */
  strayIndex: string[];
  /** Authentication にもう無いユーザー（そのトークンと索引を消す）。 */
  goneUsers: string[];
  /** 古い通知の記録。 */
  staleNotifications: string[];
  /** `db.ref().update()` にそのまま渡せる（値は null）。端末のトークンを先に並べる。 */
  updates: Record<string, null>;
}

type LeafletValue = { title?: unknown; ownerUid?: unknown } | null;

/**
 * 何をどう消すかの計画を作る。データベースは変更しない。
 *
 * 消すのは、持ち主（`ownerUid`）が Authentication にもういないしおりと、その関連データ。
 * 参加者が残っていても消す（持ち主がいないしおりは、削除も、あいことばの変更も、できないため）。
 * Authentication に問い合わせられなかったときは、何も消さないよう、例外のまま投げる。
 */
export async function planCleanup(deps: CleanupDeps): Promise<CleanupPlan> {
  const { db, now, shallowKeys, missingUids } = deps;

  const leaflets = ((await db.ref("leaflets").get()).val() ?? {}) as Record<string, LeafletValue>;
  const allIds = new Set(Object.keys(leaflets));

  const owners = new Set<string>();
  for (const leaflet of Object.values(leaflets)) {
    if (typeof leaflet?.ownerUid === "string") owners.add(leaflet.ownerUid);
  }
  const indexed = new Set(await shallowKeys("userLeaflets"));
  const withTokens = new Set(await shallowKeys("users"));
  const known = [...new Set([...owners, ...indexed, ...withTokens])].sort();
  const missing = known.length > 0 ? await missingUids(known) : new Set<string>();
  const goneUsers = known.filter((uid) => missing.has(uid));

  const updates: Record<string, null> = {};
  // しおりを消すと、オーナーの端末に「脱退」の通知が飛びうる。先にトークンを消しておくため、先に並べる。
  for (const uid of goneUsers) {
    if (withTokens.has(uid)) updates[`users/${uid}`] = null;
  }
  // 索引の上と下を、同じ更新で書くことはできない。ユーザーごと消す索引は、下を書かない。
  const wholeIndex = new Set<string>();
  for (const uid of goneUsers) {
    if (indexed.has(uid)) {
      updates[`userLeaflets/${uid}`] = null;
      wholeIndex.add(uid);
    }
  }

  const removedLeaflets: RemovedLeaflet[] = [];
  let unownedLeaflets = 0;
  for (const [id, leaflet] of Object.entries(leaflets)) {
    const ownerUid = leaflet?.ownerUid;
    if (typeof ownerUid !== "string") {
      unownedLeaflets++;
      continue;
    }
    if (!missing.has(ownerUid)) continue;
    const members = Object.keys(((await db.ref(`leafletMembers/${id}`).get()).val() ?? {}) as object);
    removedLeaflets.push({
      id,
      title: typeof leaflet?.title === "string" ? leaflet.title : "",
      ownerUid,
      members,
    });
  }
  const removedIds = new Set(removedLeaflets.map((r) => r.id));
  for (const { id, members } of removedLeaflets) {
    updates[`leaflets/${id}`] = null;
    for (const path of PER_LEAFLET_PATHS) updates[`${path}/${id}`] = null;
    for (const uid of members) {
      if (!wholeIndex.has(uid)) updates[`userLeaflets/${uid}/${id}`] = null;
    }
  }

  // しおりが無いのに残っているもの。
  const orphans: string[] = [];
  for (const path of PER_LEAFLET_PATHS) {
    for (const id of await shallowKeys(path)) {
      if (!allIds.has(id)) {
        orphans.push(`${path}/${id}`);
        updates[`${path}/${id}`] = null;
      }
    }
  }

  // 消えるしおり、または元から無いしおりを指す、各人の索引。
  // ユーザーごと消す索引は上で消すので飛ばし、しおりと一緒に消す分は数えない。
  const strayIndex: string[] = [];
  const indexSnap = ((await db.ref("userLeaflets").get()).val() ?? {}) as Record<string, object | null>;
  for (const [uid, entries] of Object.entries(indexSnap)) {
    if (wholeIndex.has(uid)) continue;
    for (const id of Object.keys(entries ?? {})) {
      if (!allIds.has(id) || removedIds.has(id)) {
        const path = `userLeaflets/${uid}/${id}`;
        if (!(path in updates)) strayIndex.push(path);
        updates[path] = null;
      }
    }
  }

  // 通知の二重送信の防止と、連打の抑制のための記録。
  const staleNotifications: string[] = [];
  const staleBefore = now() - NOTIFICATION_STATE_MAX_AGE_MS;
  const log = ((await db.ref("notificationLog").get()).val() ?? {}) as Record<
    string,
    Record<string, { at?: unknown } | null> | null
  >;
  for (const [id, devices] of Object.entries(log)) {
    // notificationLog/{イベント ID}/{端末のトークンのハッシュ} = { at }。新しい端末の記録が 1 つでもあれば残す。
    const times = Object.values(devices ?? {}).map((d) => (typeof d?.at === "number" ? d.at : 0));
    if (times.length === 0 || Math.max(...times) < staleBefore) {
      staleNotifications.push(`notificationLog/${id}`);
    }
  }
  const throttle = ((await db.ref("notificationThrottle").get()).val() ?? {}) as Record<string, unknown>;
  for (const [key, at] of Object.entries(throttle)) {
    if (typeof at !== "number" || at < staleBefore) {
      staleNotifications.push(`notificationThrottle/${key}`);
    }
  }
  for (const path of staleNotifications) updates[path] = null;

  return { removedLeaflets, unownedLeaflets, orphans, strayIndex, goneUsers, staleNotifications, updates };
}

/** 計画を実行する。消したパスの数を返す。 */
export async function applyCleanup(db: Database, plan: CleanupPlan): Promise<number> {
  const entries = Object.entries(plan.updates);
  for (let i = 0; i < entries.length; i += UPDATE_CHUNK) {
    await db.ref().update(Object.fromEntries(entries.slice(i, i + UPDATE_CHUNK)));
  }
  return entries.length;
}

/** 計画を作り、[apply] が true のときだけ実行する。 */
export async function runCleanup(
  deps: CleanupDeps,
  options: { apply: boolean },
): Promise<{ plan: CleanupPlan; removedPaths: number }> {
  const plan = await planCleanup(deps);
  const removedPaths = options.apply ? await applyCleanup(deps.db, plan) : 0;
  return { plan, removedPaths };
}

/**
 * [path] の直下のキーだけを、REST の `shallow=true` で取る（中身は転送しない）。
 *
 * Emulator に対しては、環境変数 FIREBASE_DATABASE_EMULATOR_HOST があれば、そこへ向ける。
 */
export function shallowKeysVia(app: App): (path: string) => Promise<string[]> {
  return async (path) => {
    const databaseURL = app.options.databaseURL;
    if (!databaseURL) throw new Error("The database URL is not set");
    const emulatorHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
    let url: string;
    let token: string;
    if (emulatorHost) {
      const ns = new URL(databaseURL).hostname.split(".")[0];
      url = `http://${emulatorHost}/${path}.json?ns=${ns}&shallow=true`;
      token = "owner";
    } else {
      const credential = app.options.credential;
      if (!credential) throw new Error("No credential is set");
      token = (await credential.getAccessToken()).access_token;
      url = `${databaseURL}/${path}.json?shallow=true`;
    }
    const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!response.ok) throw new Error(`Could not read ${path}: HTTP ${response.status}`);
    const body: unknown = await response.json();
    return body && typeof body === "object" ? Object.keys(body) : [];
  };
}

/**
 * Authentication に、もう無いユーザーを調べる。
 *
 * 「見つからなかった」と答えられたものだけを、いないものとして扱う。問い合わせが失敗したときは、
 * 例外のまま投げる（失敗を「いない」と取り違えて、消してしまわないため）。
 */
export function missingUidsVia(auth: Pick<Auth, "getUsers">): (uids: string[]) => Promise<Set<string>> {
  return async (uids) => {
    const valid = uids.filter((uid) => uid.length > 0 && uid.length <= UID_MAX_LENGTH);
    const missing = new Set<string>();
    for (let i = 0; i < valid.length; i += AUTH_BATCH) {
      const result = await auth.getUsers(valid.slice(i, i + AUTH_BATCH).map((uid) => ({ uid })));
      for (const identifier of result.notFound) {
        if ("uid" in identifier) missing.add(identifier.uid);
      }
    }
    return missing;
  };
}
