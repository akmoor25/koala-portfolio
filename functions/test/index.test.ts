import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import path from "node:path";

/** データベース（Realtime Database）と同じリージョン。 */
const REGION = "asia-southeast1";

type Endpoint = {
  region?: string[];
  eventTrigger?: {
    eventType: string;
    eventFilterPathPatterns?: Record<string, string>;
    retry?: boolean;
  };
  scheduleTrigger?: { schedule: string; timeZone: string };
  timeoutSeconds?: number | null;
  [key: string]: unknown;
};

/**
 * デプロイで使われる関数ごとの設定（`__endpoint`）を読む。
 *
 * index は読み込み時に既定のアプリを初期化し、他のテストの初期化とぶつかるため、別のプロセスで読む。
 */
function endpoints(): Record<string, Endpoint> {
  const index = path.join(__dirname, "../src/index.js");
  const script = `
    const m = require(${JSON.stringify(index)});
    const out = {};
    for (const [name, value] of Object.entries(m)) out[name] = value.__endpoint;
    process.stdout.write(JSON.stringify(out));
  `;
  return JSON.parse(execFileSync(process.execPath, ["-e", script], { encoding: "utf8" }));
}

describe("deployed functions", () => {
  let all: Record<string, Endpoint>;

  before(function () {
    this.timeout(30000);
    all = endpoints();
  });

  it("exports only the two background functions, with no entry point callable from outside", () => {
    assert.deepEqual(Object.keys(all).sort(), ["dailyCleanup", "onMembersChange"]);
    for (const [name, endpoint] of Object.entries(all)) {
      assert.ok(endpoint.eventTrigger ?? endpoint.scheduleTrigger, name);
      assert.equal(endpoint.httpsTrigger, undefined, name);
      assert.equal(endpoint.callableTrigger, undefined, name);
    }
  });

  it("onMembersChange runs on member writes, next to the database, and retries", () => {
    const endpoint = all.onMembersChange;
    assert.deepEqual(endpoint.region, [REGION]);
    assert.equal(endpoint.eventTrigger?.eventType, "google.firebase.database.ref.v1.written");
    assert.equal(endpoint.eventTrigger?.eventFilterPathPatterns?.ref, "leafletMembers/{leafletId}");
    assert.equal(endpoint.eventTrigger?.retry, true);
  });

  it("dailyCleanup runs every day at 4:00 in Japan, next to the database", () => {
    const endpoint = all.dailyCleanup;
    assert.deepEqual(endpoint.region, [REGION]);
    assert.equal(endpoint.scheduleTrigger?.schedule, "0 4 * * *");
    assert.equal(endpoint.scheduleTrigger?.timeZone, "Asia/Tokyo");
  });
});
