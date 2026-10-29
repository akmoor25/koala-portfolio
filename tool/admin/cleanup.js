#!/usr/bin/env node
/**
 * 持ち主のユーザーがいなくなったしおりと、その関連データを、手で掃除する管理用のツール。
 *
 * 毎日 4:00（日本時間）に、同じ処理を Cloud Functions（`dailyCleanup`）が自動で行う。
 * このツールは、消す前に中身を確かめたいときや、すぐに掃除したいときに使う。
 * 処理は、`functions/src/cleanup.ts` にあり、関数と同じものを使う。
 *
 * 使い方（既定は確認だけ。何も消さない）:
 *   npm --prefix functions run build
 *   node tool/admin/cleanup.js --project koala-portfolio
 *   node tool/admin/cleanup.js --project koala-portfolio --apply
 *
 * 管理者の権限が要る（セキュリティルールを通らない）。サービスアカウントのキーを
 * Firebase コンソールで作り、環境変数 GOOGLE_APPLICATION_CREDENTIALS にそのパスを入れる。
 * キーはリポジトリに入れない。
 *
 * 消すもの:
 *   - 持ち主が Authentication にもういないしおりと、その旅程・ノート・カーソル・あいことば・メンバー・
 *     閉鎖の記録・各人の索引（参加者が残っていても消す）
 *   - しおりが無いのに残っている、旅程・ノート・カーソル・あいことば・メンバー・閉鎖の記録、索引の項目
 *   - Authentication にもういないユーザーの、端末のトークンと索引
 *   - 作られて 1 日以上たった、通知の二重送信の防止と連打の抑制の記録
 */
const { parseArgs } = require("node:util");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getDatabase } = require("firebase-admin/database");

function readArgs(argv) {
  const { values } = parseArgs({
    args: argv,
    options: {
      project: { type: "string" },
      "database-url": { type: "string" },
      apply: { type: "boolean", default: false },
    },
  });
  if (!values.project) throw new Error("--project を指定してください");
  return values;
}

/** 関数と同じ処理（ビルド済みの TypeScript）を読み込む。 */
function loadCleanup() {
  try {
    return require("../../functions/lib/src/cleanup");
  } catch (error) {
    if (error.code === "MODULE_NOT_FOUND") {
      throw new Error("先に npm --prefix functions run build を実行してください");
    }
    throw error;
  }
}

async function main(argv) {
  const args = readArgs(argv);
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error("GOOGLE_APPLICATION_CREDENTIALS に、サービスアカウントのキーのパスを入れてください");
  }
  const cleanup = loadCleanup();
  const app = initializeApp({
    projectId: args.project,
    databaseURL:
      args["database-url"] ||
      `https://${args.project}-default-rtdb.asia-southeast1.firebasedatabase.app`,
    credential: applicationDefault(),
  });
  const db = getDatabase(app);

  const plan = await cleanup.planCleanup({
    db,
    now: () => Date.now(),
    shallowKeys: cleanup.shallowKeysVia(app),
    missingUids: cleanup.missingUidsVia(getAuth(app)),
  });

  console.log(`持ち主がいなくなったしおり: ${plan.removedLeaflets.length} 件`);
  for (const r of plan.removedLeaflets) {
    console.log(`  - ${r.id}  メンバー ${r.members.length} 人  「${r.title}」`);
  }
  console.log(`持ち主の記録が無く、判断できずに残すしおり: ${plan.unownedLeaflets} 件`);
  console.log(`しおりが無いのに残っているもの: ${plan.orphans.length} 件`);
  plan.orphans.forEach((p) => console.log(`  - ${p}`));
  console.log(`宙に浮いた索引: ${plan.strayIndex.length} 件`);
  console.log(`Authentication にもういないユーザー: ${plan.goneUsers.length} 人`);
  console.log(`古い通知の記録: ${plan.staleNotifications.length} 件`);
  console.log(`消すパスの数: ${Object.keys(plan.updates).length}`);

  if (!args.apply) {
    console.log("確認だけです。消すときは --apply を付けてください。");
    return;
  }
  const count = await cleanup.applyCleanup(db, plan);
  console.log(`${count} 件のパスを消しました。`);
}

main(process.argv.slice(2)).then(
  () => process.exit(0),
  (error) => {
    console.error(`エラー: ${error.message}`);
    process.exit(1);
  },
);
