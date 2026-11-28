package com.capulife.capulife_native

import android.accessibilityservice.AccessibilityService
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Captures payment / transfer success pages for the ledger.
 *
 * The page is only inspected when the app has an accessibility service bound
 * by the user. Nothing is sent to the network; successes become "pending"
 * ledger entries that the user reviews before they are committed.
 */
class CapAccessibilityService : AccessibilityService() {
    private var lastEventAt = 0L
    private var lastPackage = ""

    private fun prefs(): SharedPreferences =
        getSharedPreferences("capulife_capture", MODE_PRIVATE)

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }
        val pkg = event.packageName?.toString()?.trim().orEmpty()
        if (pkg.isEmpty()) return
        val preferences = prefs()
        if (!preferences.getBoolean("page_enabled", true)) return
        val watched = (preferences.getString(
            "watched",
            "com.tencent.mm,com.eg.android.AlipayGphone,com.unionpay",
        ) ?: "")
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (pkg !in watched) return

        val now = System.currentTimeMillis()
        // Content-changed fires many times for a single page; throttle and
        // avoid re-reading the exact same window.
        if (pkg == lastPackage && now - lastEventAt < 700) return
        lastPackage = pkg
        lastEventAt = now

        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != pkg) return
        val texts = mutableListOf<String>()
        collectTexts(root, texts, 0)
        if (texts.isEmpty()) return
        parsePage(preferences, pkg, texts, now)
    }

    private fun collectTexts(
        node: AccessibilityNodeInfo?,
        out: MutableList<String>,
        depth: Int,
    ) {
        if (node == null || depth > 18 || out.size >= 90) return
        val text = node.text?.toString()?.trim().orEmpty()
        val desc = node.contentDescription?.toString()?.trim().orEmpty()
        for (raw in arrayOf(text, desc)) {
            if (raw.isEmpty()) continue
            if (raw.length > 160) continue
            if (out.none { it == raw }) out.add(raw)
        }
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            collectTexts(child, out, depth + 1)
            child.recycle()
        }
    }

    private fun parsePage(
        preferences: SharedPreferences,
        pkg: String,
        texts: List<String>,
        now: Long,
    ) {
        val combined = texts.joinToString(" | ")
        if (combined.length > 3000) return
        val success = Regex("支付成功|付款成功|转账成功|交易成功|收款成功|收款到账|已到账|已存入零钱").containsMatchIn(combined)
        if (!success) return
        if (Regex("支付失败|付款失败|交易失败|交易关闭|已取消|已退款|退款成功|待支付|请付款|确认付款").containsMatchIn(combined)) {
            return
        }
        val amount = parseAmount(texts) ?: return
        if (amount <= 0 || amount > 100000000) return
        val income = Regex("收款|到账|已存入零钱").containsMatchIn(combined) &&
            !Regex("支付成功|付款成功|转账成功").containsMatchIn(combined)
        val type = if (income) "income" else "expense"
        val appLabel = when (pkg) {
            "com.tencent.mm" -> "微信"
            "com.eg.android.AlipayGphone" -> "支付宝"
            "com.unionpay" -> "云闪付"
            else -> "页面记账"
        }
        val merchant = extractMerchant(texts, amount, appLabel)
        val fingerprint = "$pkg|$type|$amount|$merchant"
        val last = preferences.getString("page_last", "") ?: ""
        if (last.isNotEmpty()) {
            try {
                val lastJson = JSONObject(last)
                if (lastJson.optString("fingerprint") == fingerprint &&
                    now - lastJson.optLong("at") < 3 * 60 * 1000
                ) {
                    return
                }
            } catch (_: Exception) {
            }
        }
        if (alreadyPending(preferences, amount, merchant, now)) return

        val snippet = texts
            .filter {
                it.contains("成功") || it.contains("到账") ||
                    Regex("[¥￥]\\s*[0-9]").containsMatchIn(it)
            }
            .take(5)
            .joinToString(" | ")
            .take(160)
        val item = JSONObject().apply {
            put("id", "page_${now}_${(1000..9999).random()}")
            put("type", type)
            put("amountCents", amount)
            put("merchant", merchant)
            put("title", if (income) "收款到账" else "支付成功")
            put("text", snippet)
            put("app", appLabel)
            put("at", now)
            put("auto", false)
            put("source", "accessibility")
        }
        appendRaw(preferences, item)
        appendPending(preferences, item)
        preferences.edit()
            .putString("page_last", JSONObject().apply {
                put("fingerprint", fingerprint)
                put("at", now)
            }.toString())
            .apply()
    }

    private fun parseAmount(texts: List<String>): Int? {
        for (index in texts.indices) {
            val raw = texts[index].trim()
            if (raw.isEmpty()) continue
            if (Regex("红包|优惠|立减|折扣|积分|余额|手续费").containsMatchIn(raw)) continue
            val currency = Regex("[¥￥]\\s*([0-9]+(?:[.,][0-9]{1,2})?)").find(raw)
            if (currency != null) {
                val value = currency.groupValues[1].replace(',', '.').toDoubleOrNull()
                if (value != null && value > 0) return (value * 100).roundToInt()
            }
            if (raw == "¥" || raw == "￥") {
                for (next in index + 1 until minOf(texts.size, index + 3)) {
                    val value = texts[next].trim().replace(",", ".").toDoubleOrNull()
                    if (value != null && value > 0) return (value * 100).roundToInt()
                }
            }
            val yuan = Regex("([0-9]+(?:[.,][0-9]{1,2})?)\\s*元").find(raw)
            if (yuan != null) {
                val value = yuan.groupValues[1].replace(',', '.').toDoubleOrNull()
                if (value != null && value > 0) return (value * 100).roundToInt()
            }
        }
        return null
    }

    private fun extractMerchant(texts: List<String>, amount: Int, fallback: String): String {
        val amountText = (amount / 100.0).toString()
        val skip = Regex(
            "支付成功|付款成功|转账成功|交易成功|收款|到账|¥|￥|金额|付款方式|完成|返回|首页|我的|账单|零钱|余额|银行卡|微信支付|支付宝|云闪付|查看|详情|收银台|订单|商品|优惠|红包|立减|积分|请|确认|取消|关闭|成功|失败",
        )
        val amountIndex = texts.indexOfFirst {
            it.contains("¥") || it.contains("￥") || it.contains(amountText)
        }
        val start = if (amountIndex >= 0) amountIndex + 1 else 0
        for (index in start until minOf(texts.size, start + 8)) {
            val value = texts[index].trim()
            if (value.length < 2 || value.length > 30) continue
            if (skip.containsMatchIn(value)) continue
            if (value.all { it.isDigit() || it == '.' || it == ',' || it == ' ' }) continue
            return value
        }
        return fallback
    }

    private fun alreadyPending(
        preferences: SharedPreferences,
        amount: Int,
        merchant: String,
        now: Long,
    ): Boolean {
        val pending = try {
            JSONArray(preferences.getString("pending", "[]") ?: "[]")
        } catch (_: Exception) {
            return false
        }
        for (index in 0 until pending.length()) {
            val existing = pending.optJSONObject(index) ?: continue
            if (existing.optInt("amountCents") == amount &&
                existing.optString("merchant") == merchant &&
                abs(existing.optLong("at") - now) < 3 * 60 * 1000
            ) {
                return true
            }
        }
        return false
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
        pending.put(item)
        preferences.edit().putString("pending", pending.toString()).apply()
    }

    override fun onInterrupt() {
        // No ongoing feedback to interrupt.
    }
}