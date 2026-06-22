package com.autoresq.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val alertsChannel = NotificationChannel(
            "autoresq_alerts",
            "Alertas de AutoResQ",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Solicitudes, mensajes y cambios importantes del servicio."
            enableLights(true)
            lightColor = Color.rgb(187, 2, 15)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 120, 250)
            setSound(soundUri, audioAttributes)
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(alertsChannel)
    }
}
