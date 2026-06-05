package com.example.group2_urbanfix

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var foregroundNotificationChannel: MethodChannel? = null
    private var pendingForegroundNotificationPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        foregroundNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FOREGROUND_NOTIFICATION_CHANNEL,
        )
        foregroundNotificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showForegroundNotification" -> {
                    val title = call.argument<String>("title") ?: "New notification"
                    val body = call.argument<String>("body") ?: "Tap to view the details."
                    val payload = call.argument<String>("payload") ?: ""

                    showForegroundNotification(title, body, payload)
                    result.success(null)
                }

                "getInitialForegroundNotification" -> {
                    val payload = pendingForegroundNotificationPayload
                    pendingForegroundNotificationPayload = null
                    result.success(payload)
                }

                else -> result.notImplemented()
            }
        }

        deliverForegroundNotificationTap(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverForegroundNotificationTap(intent)
    }

    private fun showForegroundNotification(title: String, body: String, payload: String) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ANDROID_NOTIFICATION_CHANNEL_ID,
                ANDROID_NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Foreground FCM notifications"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val tapIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_FOREGROUND_NOTIFICATION_TAP
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_FOREGROUND_NOTIFICATION_PAYLOAD, payload)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, ANDROID_NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        @Suppress("DEPRECATION")
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setDefaults(Notification.DEFAULT_ALL)
            .setPriority(Notification.PRIORITY_HIGH)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun deliverForegroundNotificationTap(intent: Intent?) {
        if (intent?.action != ACTION_FOREGROUND_NOTIFICATION_TAP) return

        val payload = intent.getStringExtra(EXTRA_FOREGROUND_NOTIFICATION_PAYLOAD)
            ?: return

        pendingForegroundNotificationPayload = payload

        if (foregroundNotificationChannel == null) {
            return
        }

        foregroundNotificationChannel?.invokeMethod("foregroundNotificationTap", payload)
    }

    companion object {
        private const val FOREGROUND_NOTIFICATION_CHANNEL =
            "laporfix/foreground_notifications"
        private const val ANDROID_NOTIFICATION_CHANNEL_ID =
            "laporfix_foreground_fcm"
        private const val ANDROID_NOTIFICATION_CHANNEL_NAME =
            "LaporFix notifications"
        private const val ACTION_FOREGROUND_NOTIFICATION_TAP =
            "com.example.group2_urbanfix.FOREGROUND_NOTIFICATION_TAP"
        private const val EXTRA_FOREGROUND_NOTIFICATION_PAYLOAD =
            "foreground_notification_payload"
    }
}
