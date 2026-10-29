import { getApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getDatabase } from "firebase-admin/database";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { onValueWritten } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { CleanupDeps, missingUidsVia, runCleanup, shallowKeysVia } from "./cleanup";
import { Deps, SendResult, handleMembersChange } from "./handler";

initializeApp();

/** データベース（Realtime Database）と同じリージョン。 */
const REGION = "asia-southeast1";

/**
 * 毎日の掃除の実行時間の上限（秒）。既定の 60 秒より長くする。
 * Authentication への照会と削除を、件数が増えても 1 回の実行で終えるため。
 */
const CLEANUP_TIMEOUT_SECONDS = 300;

function realDeps(): Deps {
  return {
    db: getDatabase(),
    now: () => Date.now(),
    warn: (message, data) => logger.warn(message, data),
    displayName: async (uid) => (await getAuth().getUser(uid)).displayName ?? null,
    send: async (messages): Promise<SendResult[]> => {
      const response = await getMessaging().sendEach(messages);
      return response.responses.map((r) =>
        r.success ? { ok: true } : { ok: false, code: r.error?.code ?? "unknown" },
      );
    },
  };
}

/**
 * 共同編集のメンバーの変化（参加、削除、停止）から、プッシュ通知を送る。
 *
 * データベースの変化だけで動き、外から呼べる入り口は無い。`retry` を有効にして、
 * 一時的な失敗は再試行する（二重の通知は、イベント ID と端末ごとの予約で防ぐ）。
 */
export const onMembersChange = onValueWritten(
  { ref: "/leafletMembers/{leafletId}", region: REGION, retry: true },
  async (event) => {
    const result = await handleMembersChange(realDeps(), {
      id: event.id,
      timeMs: Date.parse(event.time),
      leafletId: event.params.leafletId,
      before: event.data.before.val(),
      after: event.data.after.val(),
    });
    logger.info("leafletMembers changed", {
      leafletId: event.params.leafletId,
      eventId: event.id,
      ...result,
    });
  },
);

function realCleanupDeps(): CleanupDeps {
  const app = getApp();
  return {
    db: getDatabase(app),
    now: () => Date.now(),
    shallowKeys: shallowKeysVia(app),
    missingUids: missingUidsVia(getAuth(app)),
  };
}

/**
 * 毎日 4:00（日本時間）に、持ち主のユーザーがいなくなったしおりと、その関連データを消す。
 *
 * Cloud Scheduler のジョブだけが呼べる（外から直接呼べる入り口は無い）。Authentication に問い合わせられない
 * ときは、何も消さずに失敗する（次の日に、もう一度試す）。しおりのタイトルや ID は、ログに出さず、件数だけを残す。
 */
export const dailyCleanup = onSchedule(
  {
    // 分 時 日 月 曜日。毎日 4:00。
    schedule: "0 4 * * *",
    timeZone: "Asia/Tokyo",
    region: REGION,
    timeoutSeconds: CLEANUP_TIMEOUT_SECONDS,
  },
  async () => {
    const { plan, removedPaths } = await runCleanup(realCleanupDeps(), { apply: true });
    logger.info("daily cleanup finished", {
      removedLeaflets: plan.removedLeaflets.length,
      unownedLeaflets: plan.unownedLeaflets,
      orphans: plan.orphans.length,
      strayIndex: plan.strayIndex.length,
      goneUsers: plan.goneUsers.length,
      staleNotifications: plan.staleNotifications.length,
      removedPaths,
    });
  },
);
