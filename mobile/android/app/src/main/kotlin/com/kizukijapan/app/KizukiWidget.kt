package com.kizukijapan.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import org.json.JSONObject

/** Offline launcher widget. No player, network calls or learner identity. */
open class KizukiWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }
    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            listOf(KizukiWidget::class.java, KizukiWideWidget::class.java).forEach { cls ->
                manager.getAppWidgetIds(ComponentName(context, cls)).forEach { render(context, manager, it) }
            }
        }
        private fun tap(context: Context, id: Int, url: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse(url)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val wide = manager.getAppWidgetInfo(id)?.provider?.className?.endsWith("KizukiWideWidget") == true
            val view = RemoteViews(context.packageName, if (wide) R.layout.kizuki_widget_wide else R.layout.kizuki_widget)
            val raw = context.getSharedPreferences("kizuki_widgets", Context.MODE_PRIVATE).getString("snapshot", null)
            val snapshot = try { raw?.let { JSONObject(it) } } catch (_: Exception) { null }
            val now = System.currentTimeMillis()
            val expired = now >= (snapshot?.optLong("expires") ?: 0)
            val pool = snapshot?.optJSONArray(if (expired) "fallback" else "words")
            val length = pool?.length() ?: 0
            val index = if (length == 0) 0 else (((now - (snapshot?.optLong("base") ?: now)).coerceAtLeast(0) / 7200000) % length).toInt()
            val word = pool?.optJSONObject(index)
            view.setTextViewText(R.id.widget_word, word?.optString("word") ?: "気づき")
            view.setTextViewText(R.id.widget_reading, if (snapshot?.optBoolean("reading", true) != false) word?.optString("reading") ?: "きづき" else "")
            view.setTextViewText(R.id.widget_meaning, if (snapshot?.optBoolean("meaning", true) != false) word?.optString("meaning") ?: "Open Kizuki to discover a word" else "")
            val clip = word?.optString("clipId") ?: ""
            val url = Uri.Builder().scheme("kizuki").authority("widget").path("/word").appendQueryParameter("clip", clip).build().toString()
            view.setOnClickPendingIntent(R.id.widget_root, tap(context, id * 2, url))
            if (wide) {
                val due = if (expired) 0 else snapshot?.optInt("due") ?: 0
                val streak = if (expired) 0 else snapshot?.optInt("streak") ?: 0
                view.setTextViewText(R.id.widget_review, if (due > 0) "$due to review →" else "Discover more →")
                view.setTextViewText(R.id.widget_streak, if (streak > 0) "🔥 $streak" else "")
                view.setOnClickPendingIntent(R.id.widget_review, tap(context, id * 2 + 1, "kizuki://widget/review"))
            }
            manager.updateAppWidget(id, view)
        }
    }
}
class KizukiWideWidget : KizukiWidget()