package io.akmoor25.koala_portfolio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // 共同編集の通知（参加、しおりの削除と停止）のチャンネル。
    // サーバー（Cloud Functions）が、同じ ID（collab）を指定して送る。
    // 名前は端末の言語で表示されるよう、strings.xml に置く。
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notif_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "collab"
    }
}
