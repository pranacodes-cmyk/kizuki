package com.kizukijapan.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import org.json.JSONObject
import java.util.Calendar

/**
 * Android phones do not allow third-party lock-screen widgets, so "Lock screen word" sets a
 * simple black lock-screen wallpaper with one Japanese word per day, drawn from the same
 * offline widget snapshot. Turning it off clears the lock wallpaper (falls back to home).
 */
object LockWord {
    private const val PREFS = "kizuki_widgets"
    private const val DAY = 86_400_000L

    fun enabled(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("lock_enabled", false)

    fun setEnabled(context: Context, on: Boolean): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!on) {
            prefs.edit().putBoolean("lock_enabled", false).remove("lock_key").commit()
            cancel(context)
            return try {
                if (Build.VERSION.SDK_INT >= 24) WallpaperManager.getInstance(context).clear(WallpaperManager.FLAG_LOCK)
                true
            } catch (_: Exception) { true }
        }
        prefs.edit().putBoolean("lock_enabled", true).remove("lock_key").commit()
        val ok = apply(context, force = true)
        if (!ok) prefs.edit().putBoolean("lock_enabled", false).commit() else schedule(context)
        return ok
    }

    /** Re-draws only when today's word changed (avoids wallpaper flicker on every app update). */
    fun apply(context: Context, force: Boolean = false): Boolean {
        if (Build.VERSION.SDK_INT < 24 || !enabled(context)) return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val word = today(context) ?: Triple("気づき", "きづき", "noticing")
        val key = "${System.currentTimeMillis() / DAY}|${word.first}|${word.second}|${word.third}"
        if (!force && prefs.getString("lock_key", null) == key) return true
        return try {
            WallpaperManager.getInstance(context).setBitmap(draw(context, word), null, true, WallpaperManager.FLAG_LOCK)
            prefs.edit().putString("lock_key", key).commit()
            true
        } catch (_: Exception) { false }
    }

    private fun today(context: Context): Triple<String, String, String>? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("snapshot", null) ?: return null
        val s = try { JSONObject(raw) } catch (_: Exception) { return null }
        val now = System.currentTimeMillis()
        val expired = now >= s.optLong("expires")
        val pool = s.optJSONArray(if (expired) "fallback" else "words") ?: return null
        if (pool.length() == 0) return null
        val w = pool.optJSONObject(((now / DAY) % pool.length()).toInt()) ?: return null
        val reading = if (s.optBoolean("reading", true)) w.optString("reading") else ""
        val meaning = if (s.optBoolean("meaning", true)) w.optString("meaning") else ""
        return Triple(w.optString("word"), reading, meaning)
    }

    private fun draw(context: Context, w: Triple<String, String, String>): Bitmap {
        val m = DisplayMetrics()
        @Suppress("DEPRECATION")
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.getRealMetrics(m)
        val width = minOf(m.widthPixels, m.heightPixels).coerceAtLeast(720)
        val height = maxOf(m.widthPixels, m.heightPixels).coerceAtLeast(1280)
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(Color.BLACK)
        val cx = width / 2f
        val orange = Color.parseColor("#FF8A3D")
        fun paint(size: Float, color: Int, bold: Boolean = false) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = size; this.color = color; textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }
        val wordPaint = paint(width * 0.22f, Color.WHITE)
        while (wordPaint.measureText(w.first) > width * 0.86f && wordPaint.textSize > 40f) wordPaint.textSize *= 0.9f
        // Sits below the system clock and above notifications/shortcuts.
        val y = height * 0.56f
        if (w.second.isNotEmpty()) c.drawText(w.second, cx, y - wordPaint.textSize * 1.05f, paint(width * 0.055f, orange))
        c.drawText(w.first, cx, y, wordPaint)
        if (w.third.isNotEmpty()) {
            val mp = paint(width * 0.052f, Color.parseColor("#BDBDBD"))
            var line = w.third
            while (mp.measureText(line) > width * 0.86f && line.length > 4) line = line.dropLast(2)
            if (line != w.third) line = line.trimEnd() + "…"
            c.drawText(line, cx, y + wordPaint.textSize * 0.55f, mp)
        }
        c.drawText("kizuki", cx, height * 0.93f, paint(width * 0.035f, orange, true))
        return bmp
    }

    private fun pending(context: Context) = PendingIntent.getBroadcast(context, 7101, Intent(context, LockWordReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun schedule(context: Context) {
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 5); set(Calendar.SECOND, 0)
        }.timeInMillis
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .setInexactRepeating(AlarmManager.RTC, next, AlarmManager.INTERVAL_DAY, pending(context))
    }

    private fun cancel(context: Context) = (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(context))
}

/** Daily alarm, reboot and app update: redraw today's word and keep the alarm alive. */
class LockWordReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!LockWord.enabled(context)) return
        LockWord.apply(context)
        LockWord.schedule(context)
    }
}
