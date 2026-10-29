package com.kizukijapan.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kizukijapan.app/widgets").setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    val prefs = getSharedPreferences("kizuki_widgets", MODE_PRIVATE).edit()
                    val json = call.arguments as? String
                    if (json == null) prefs.remove("snapshot") else prefs.putString("snapshot", json)
                    prefs.commit()
                    KizukiWidget.refreshAll(this)
                    result.success(null)
                }
                "pin" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    if (Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported) {
                        val cls = if (call.arguments == true) KizukiWideWidget::class.java else KizukiWidget::class.java
                        result.success(manager.requestPinAppWidget(ComponentName(this, cls), null, null))
                    } else result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }
}
