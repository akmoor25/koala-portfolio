package io.akmoor25.koala_portfolio.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import io.akmoor25.koala_portfolio.MainActivity
import io.akmoor25.koala_portfolio.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.time.ZoneId
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/** Flutter 側 (TripWidgetSync) が書き込む JSON のキー */
private const val DATA_KEY = "koala_trip"

data class TripStep(
    val title: String,
    val remark: String?,
    val startSec: Long,
    val endSec: Long?,
    val isAbout: Boolean,
    // 開始時刻を現地時刻にするタイムゾーン ID。無い（旧データ）ときは端末のタイムゾーン
    val timeZoneId: String? = null,
)

data class TripSnapshot(val leaflet: String, val steps: List<TripStep>)

/** Dart の resolveCurrentStep と同じ判定 */
fun resolve(steps: List<TripStep>, nowSec: Long): Pair<TripStep?, TripStep?> {
    val nextIndex = steps.indexOfFirst { it.startSec > nowSec }
    val next = steps.getOrNull(nextIndex)
    val candidate = when (nextIndex) {
        -1 -> steps.lastOrNull()
        0 -> null
        else -> steps[nextIndex - 1]
    }
    val current = candidate?.takeUnless { c -> c.endSec != null && c.endSec <= nowSec }
    return current to next
}

fun parseSnapshot(json: String?): TripSnapshot? {
    if (json.isNullOrEmpty()) return null
    return runCatching {
        val root = JSONObject(json)
        val array = root.getJSONArray("steps")
        val steps = (0 until array.length()).map { i ->
            val s = array.getJSONObject(i)
            TripStep(
                title = s.optString("title"),
                remark = s.optString("remark").ifEmpty { null },
                startSec = s.getLong("start"),
                endSec = if (s.has("end") && !s.isNull("end")) s.getLong("end") else null,
                isAbout = s.optBoolean("isAbout", false),
                timeZoneId = s.optString("tz").ifEmpty { null },
            )
        }
        TripSnapshot(root.optString("leaflet"), steps)
    }.getOrNull()
}

class KoalaWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*> = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            Content(parseSnapshot(prefs.getString(DATA_KEY, null)))
        }
    }

    @Composable
    private fun Content(snapshot: TripSnapshot?) {
        val context = LocalContext.current
        val black = ColorProvider(Color.Black)
        val open = actionStartActivity<MainActivity>()
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(Color.White)
                .cornerRadius(16.dp)
                .padding(12.dp)
                .clickable(open),
        ) {
            if (snapshot == null || snapshot.steps.isEmpty()) {
                Text(context.getString(R.string.widget_open_app), style = TextStyle(color = black, fontSize = 13.sp))
                return@Box
            }
            val nowSec = TimeUnit.MILLISECONDS.toSeconds(System.currentTimeMillis())
            val (current, next) = resolve(snapshot.steps, nowSec)

            // リスト上ではルートの clickable が効かないため、各行にも付ける
            LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                item {
                    Column(modifier = GlanceModifier.fillMaxWidth().clickable(open)) {
                        Text(snapshot.leaflet, maxLines = 1, style = TextStyle(color = black, fontSize = 11.sp))
                        Spacer(GlanceModifier.height(4.dp))
                        Badge(context.getString(R.string.widget_now), foreground = Color.White, background = Color(0xFFFF3B30))
                        Text(
                            current?.title ?: context.getString(if (next == null) R.string.widget_done else R.string.widget_free),
                            style = TextStyle(color = black, fontSize = 16.sp, fontWeight = FontWeight.Bold),
                        )
                        current?.remark?.let { Text(it, style = TextStyle(color = black, fontSize = 12.sp)) }
                    }
                }
                if (next != null) {
                    item {
                        Column(modifier = GlanceModifier.fillMaxWidth().clickable(open)) {
                            Spacer(GlanceModifier.height(6.dp))
                            Badge(context.getString(R.string.widget_next, formatTime(context, next)), foreground = Color.Black, background = Color(0xFFFFCC00))
                            Text(next.title, style = TextStyle(color = black, fontSize = 13.sp))
                            next.remark?.let { Text(it, style = TextStyle(color = black, fontSize = 12.sp)) }
                        }
                    }
                }
            }
        }
    }

    // 色は iOS の systemRed / systemYellow に合わせている
    @Composable
    private fun Badge(text: String, foreground: Color, background: Color) {
        Text(
            text,
            modifier = GlanceModifier
                .background(background)
                .cornerRadius(3.dp)
                .padding(horizontal = 4.dp, vertical = 1.dp),
            style = TextStyle(color = ColorProvider(foreground), fontSize = 10.sp, fontWeight = FontWeight.Bold),
        )
    }

    private fun formatTime(context: Context, step: TripStep): String {
        // 表記は端末の言語に連動させない。時刻は、旅程のタイムゾーン（現地時刻）で表示する。
        val zone = step.timeZoneId?.let { runCatching { TimeZone.getTimeZone(ZoneId.of(it)) }.getOrNull() }
            ?: TimeZone.getDefault()
        val text = SimpleDateFormat("M/d HH:mm", Locale.US).apply { timeZone = zone }
            .format(Date(TimeUnit.SECONDS.toMillis(step.startSec)))
        return if (step.isAbout) context.getString(R.string.widget_about, text) else text
    }
}
