package com.capulife.capulife_native

import android.app.Notification
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

class PaymentNotificationService : NotificationListenerService() {
    private fun prefs(): SharedPreferences =
        getSharedPreferences("capulife_capture", MODE_PRIVATE)

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        val preferences = prefs()
        val watched = (
            preferences.getString(
                "watched",
                "com.tencent.mm,com.eg.android.AlipayGphone,com.unionpay",
            ) ?: ""
        ).split(",").map { it.trim() }.filter { it.isNotEmpty() }
        if (pkg !in watched) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
        )?.toString()?.trim().orEmpty()
        if (title.isBlank() && text.isBlank()) return
        val combined = "$title $text"
        val amount = parseAmount(combined)
        if (amount == null || amount <= 0 || amount > 100000000) return
        val at = System.currentTimeMillis()
        val appLabel = when (pkg) {
            "com.tencent.mm" -> "微信"
            "com.eg.android.AlipayGphone" -> "支付宝"
            "com.unionpay" -> "云闪付"
            "com.icbc" -> "工商银行"
            "com.chinamworld.main" -> "建设银行"
            "cmb.pb" -> "招商银行"
            else -> "通知"
        }
        val income = Regex("收款|收入|到账|退款|已收|入账").containsMatchIn(combined)
        val type = if (income) "income" else "expense"
        val merchant = when {
            title.isNotBlank() && !title.contains("微信支付") && !title.contains("支付宝") -> title
            text.isNotBlank() -> text.take(32)
            else -> appLabel
        }
        val item = JSONObject().apply {
            put("id", "cap_${at}_${(1000..9999).random()}")
            put("type", type)
            put("amountCents", amount)
            put("merchant", merchant)
            put("title", title)
            put("text", text.take(200))
            put("app", appLabel)
            put("at", at)
            put("auto", true)
        }
        appendRaw(preferences, item)
        appendPending(preferences, item)
    }

    private fun parseAmount(text: String): Int? {
        val patterns = listOf(
            Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)"),
            Regex("([0-9]+(?:\\.[0-9]{1,2})?)\\s*元"),
        )
        for (pattern in patterns) {
            val match = pattern.find(text) ?: continue
            val value = match.groupValues.getOrNull(1)?.toDoubleOrNull() ?: continue
            if (value > 0) return (value * 100).roundToInt()
        }
        if (Regex("付款|支付|消费|转账|红包|收款").containsMatchIn(text)) {
            val match = Regex("([0-9]+(?:\\.[0-9]{1,2})?)").find(text) ?: return null
            val value = match.groupValues.getOrNull(1)?.toDoubleOrNull() ?: return null
            if (value > 0 && value < 1000000) return (value * 100).roundToInt()
        }
        return null
    }

    private fun appendRaw(preferences: SharedPreferences, item: JSONObject) {
        val raw = try {
            JSONArray(preferences.getString("raw", "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        raw.put(item)
        val trimmed = JSONArray()
        for (index in maxOf(0, raw.length() - 30) until raw.length()) {
            trimmed.put(raw.get(index))
        }
        preferences.edit().putString("raw", trimmed.toString()).apply()
    }

    private fun appendPending(preferences: SharedPreferences, item: JSONObject) {
        val pending = try {
            JSONArray(preferences.getString("pending", "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        // Avoid duplicate notifications from the same payment within 5 minutes.
        for (index in 0 until pending.length()) {
            val existing = pending.optJSONObject(index) ?: continue
            if (existing.optInt("amountCents") == item.optInt("amountCents") &&
                existing.optString("merchant") == item.optString("merchant") &&
                kotlin.math.abs(existing.optLong("at") - item.optLong("at")) < 5 * 60 * 1000
            ) {
                return
            }
        }
        pending.put(item)
        preferences.edit().putString("pending", pending.toString()).apply()
    }
}
