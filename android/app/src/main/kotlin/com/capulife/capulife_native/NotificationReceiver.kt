package com.capulife.capulife_native

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "CapuLife"
        val content = intent.getStringExtra("content") ?: ""
        val id = intent.getIntExtra("id", 1)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "capulife_reminders",
                "CapuLife 提醒",
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = "待办、倒计时与课程提醒"
            manager.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, "capulife_reminders")
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(content)
            .setAutoCancel(true)
        try {
            manager.notify(id, builder.build())
        } catch (_: Exception) {
        }
    }
}
