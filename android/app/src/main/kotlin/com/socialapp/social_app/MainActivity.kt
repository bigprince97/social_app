package com.socialapp.social_app

import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "omega/notifications",
        ).setMethodCallHandler { call, result ->
            if (call.method != "clearThread") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val threadId = call.argument<String>("threadId")
            if (threadId.isNullOrEmpty()) {
                result.error("INVALID_THREAD", "threadId is required", null)
                return@setMethodCallHandler
            }

            try {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val localNotificationId = call.argument<Int>("localNotificationId")
                if (localNotificationId != null) {
                    manager.cancel(localNotificationId)
                }
                manager.activeNotifications.forEach { notification ->
                    val tag = notification.tag
                    if (tag != null && tag.startsWith("$threadId:")) {
                        manager.cancel(tag, notification.id)
                    }
                }
                result.success(null)
            } catch (error: Exception) {
                result.error("CLEAR_NOTIFICATIONS_FAILED", error.message, null)
            }
        }
    }
}
