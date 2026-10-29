import type { Message } from "firebase-admin/messaging";
import type { NotificationType } from "./decide";

/** Android の通知のチャンネル。アプリの `MainActivity` が同じ ID で作る。 */
export const CHANNEL_ID = "collab";

export interface MessageInput {
  token: string;
  type: NotificationType;
  leafletId: string;
  /** しおりのタイトル。 */
  title: string;
  /** 参加した人（`joined`）か、操作したオーナー（`deleted`、`stopped`）のニックネーム。空なら、名前なしの文言。 */
  actor: string;
  /** 参加した人の uid（`joined` のとき）。通知を、メンバーごとに分けるために使う。 */
  memberUid?: string;
}

interface Texts {
  titleKey: string;
  bodyKey: string;
  args: string[];
}

/**
 * 通知の文言を決める。
 *
 * 表示は OS が、端末の言語で、`strings.xml`（Android）と `Localizable.strings`（iOS）から引く。
 * `notification` に title と body を入れてはいけない。Android の FCM クライアントは、title と body が
 * あれば、loc key より先に使うため、端末の言語に合わせた文言にならない（英語の文が出てしまった）。
 * キーと引数の数は、アプリの ARB、Android、iOS と同じ（`tool/ci/check_l10n.py` が検査する）。
 */
export function textsFor(input: Pick<MessageInput, "type" | "title" | "actor">): Texts {
  const { type, title, actor } = input;
  const named = actor.length > 0;
  switch (type) {
    case "joined":
      return {
        titleKey: "notif_joined_title",
        bodyKey: named ? "notif_joined_body" : "notif_joined_body_anonymous",
        args: named ? [title, actor] : [title],
      };
    case "left":
      return {
        titleKey: "notif_left_title",
        bodyKey: named ? "notif_left_body" : "notif_left_body_anonymous",
        args: named ? [title, actor] : [title],
      };
    case "deleted":
      return {
        titleKey: "notif_unavailable_title",
        bodyKey: named ? "notif_deleted_body" : "notif_deleted_body_anonymous",
        args: named ? [actor, title] : [title],
      };
    case "stopped":
      return {
        titleKey: "notif_unavailable_title",
        bodyKey: named ? "notif_stopped_body" : "notif_stopped_body_anonymous",
        args: named ? [actor, title] : [title],
      };
  }
}

/** Android の通知の tag。 */
export function tagFor(
  input: Pick<MessageInput, "leafletId" | "type" | "memberUid">,
): string {
  const base = `${input.leafletId}:${input.type}`;
  const perMember = input.type === "joined" || input.type === "left";
  return perMember && input.memberUid ? `${base}:${input.memberUid}` : base;
}

/**
 * FCM に渡すメッセージを作る。
 *
 * - `android.notification.tag`：Android は、同じ tag の通知を置き換える。削除と停止は、しおりと
 *   種類で 1 つにまとめる。参加と脱退は、メンバーごとに分ける（2 人目が、1 人目の通知を消さない）。
 * - `data`：アプリが前面にあるとき（OS が通知を出さないとき）に、アプリ自身が文言を作るための材料。
 *   種類、しおり ID、しおりのタイトル、ニックネーム。タップしたときの行き先にも使う。
 */
export function buildMessage(input: MessageInput): Message {
  const texts = textsFor(input);
  return {
    token: input.token,
    data: {
      type: input.type,
      leafletId: input.leafletId,
      title: input.title,
      actor: input.actor,
    },
    android: {
      priority: "high",
      notification: {
        channelId: CHANNEL_ID,
        tag: tagFor(input),
        titleLocKey: texts.titleKey,
        bodyLocKey: texts.bodyKey,
        bodyLocArgs: texts.args,
      },
    },
    apns: {
      payload: {
        aps: {
          threadId: input.leafletId,
          alert: {
            titleLocKey: texts.titleKey,
            locKey: texts.bodyKey,
            locArgs: texts.args,
          },
        },
      },
    },
  };
}
