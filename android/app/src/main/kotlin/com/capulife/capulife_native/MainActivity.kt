package com.capulife.capulife_native

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.webkit.CookieManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private var pendingPicks: MethodChannel.Result? = null
    private var pendingPicksLimit = 9
    private var pendingApk: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "capulife/webview",
            CapWebViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/storage",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDir" -> result.success(filesDir.absolutePath)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/system",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.arguments as? String
                    if (url.isNullOrEmpty()) {
                        result.success(null)
                    } else {
                        try {
                            startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "openListenerSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "openBatterySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "isNotificationListenerEnabled" -> {
                    val enabled = Settings.Secure.getString(
                        contentResolver,
                        "enabled_notification_listeners",
                    )
                    result.success(enabled?.contains(packageName) == true)
                }
                "isAccessibilityEnabled" -> {
                    val enabled = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                    )
                    result.success(
                        enabled?.contains(packageName) == true &&
                            enabled.contains("CapAccessibilityService"),
                    )
                }
                "hasNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(true)
                    } else {
                        result.success(
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED,
                        )
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (pendingPermission != null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    pendingPermission = result
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATION_PERMISSION,
                    )
                }
                "notifyNow" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = (args?.get("title") as? String) ?: "CapuLife"
                    val content = (args?.get("content") as? String) ?: ""
                    val manager = getSystemService(NotificationManager::class.java)
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
                        android.app.Notification.Builder(this, "capulife_reminders")
                    } else {
                        @Suppress("DEPRECATION")
                        android.app.Notification.Builder(this)
                    }
                    builder
                        .setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle(title)
                        .setContentText(content)
                        .setAutoCancel(true)
                    try {
                        manager.notify(System.currentTimeMillis().toInt(), builder.build())
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/capture",
        ).setMethodCallHandler { call, result ->
            val preferences = getSharedPreferences("capulife_capture", MODE_PRIVATE)
            when (call.method) {
                "setWatchedApps" -> {
                    val apps = (call.arguments as? List<*>)?.joinToString(",") { "$it" } ?: ""
                    preferences.edit().putString("watched", apps).apply()
                    result.success(true)
                }
                "setPageCaptureEnabled" -> {
                    preferences.edit()
                        .putBoolean("page_enabled", call.arguments as? Boolean ?: true)
                        .apply()
                    result.success(true)
                }
                "pullCapturesJson" -> {
                    val pending = preferences.getString("pending", "[]") ?: "[]"
                    preferences.edit().putString("pending", "[]").apply()
                    result.success(pending)
                }
                "peekRawJson" -> {
                    result.success(preferences.getString("raw", "[]") ?: "[]")
                }
                "clearRaw" -> {
                    preferences.edit().putString("raw", "[]").apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls(),
                    )
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        } catch (_: Exception) {
                        }
                    }
                    result.success(true)
                }
                "install" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String ?: ""
                    val file = File(path)
                    if (path.isEmpty() || !file.exists()) {
                        result.success(mapOf("ok" to false, "needPermission" to false))
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        } catch (_: Exception) {
                        }
                        result.success(mapOf("ok" to false, "needPermission" to true))
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file,
                        )
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                        startActivity(intent)
                        result.success(mapOf("ok" to true, "needPermission" to false))
                    } catch (error: Exception) {
                        result.success(mapOf("ok" to false, "needPermission" to false))
                    }
                }
                "pickApk" -> {
                    if (pendingApk != null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    pendingApk = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "application/vnd.android.package-archive",
                                "application/octet-stream",
                            ),
                        )
                    }
                    try {
                        startActivityForResult(intent, REQUEST_PICK_APK)
                    } catch (_: Exception) {
                        pendingApk = null
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/notifications",
        ).setMethodCallHandler { call, result ->
            val manager = getSystemService(AlarmManager::class.java)
            val args = call.arguments as? Map<*, *>
            val id = (args?.get("id") as? Number)?.toInt() ?: 0
            when (call.method) {
                "schedule" -> {
                    val at = (args?.get("at") as? Number)?.toLong() ?: 0L
                    val title = (args?.get("title") as? String) ?: "CapuLife"
                    val content = (args?.get("content") as? String) ?: ""
                    if (id == 0 || at <= 0L) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(this, NotificationReceiver::class.java).apply {
                        putExtra("id", id)
                        putExtra("title", title)
                        putExtra("content", content)
                    }
                    val pending = PendingIntent.getBroadcast(
                        this,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            !manager.canScheduleExactAlarms()
                        ) {
                            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                        } else {
                            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                        }
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "cancel" -> {
                    val intent = Intent(this, NotificationReceiver::class.java)
                    val pending = PendingIntent.getBroadcast(
                        this,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    manager.cancel(pending)
                    pending.cancel()
                    result.success(true)
                }
                "canScheduleExact" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                            manager.canScheduleExactAlarms(),
                    )
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/tieba",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookies" -> {
                    val url = call.arguments as? String ?: "https://tieba.baidu.com"
                    try {
                        CookieManager.getInstance().flush()
                    } catch (_: Exception) {
                    }
                    result.success(CookieManager.getInstance().getCookie(url) ?: "")
                }
                "clearBaiduCookies" -> {
                    val manager = CookieManager.getInstance()
                    val names = linkedSetOf(
                        "BDUSS",
                        "BDUSS_BF",
                        "BDUSS_BFESS",
                        "STOKEN",
                        "PTOKEN",
                        "PTOKEN2",
                        "BAIDUID",
                        "BAIDUID_BF",
                        "BAIDUZID",
                        "PASSID",
                        "UBI",
                        "SESSION",
                        "ZID",
                        "PPUS",
                        "PPUS_U",
                        "H_PS_PSSID",
                        "BIDUPSID",
                        "PSTM",
                        "BDRCVFR",
                        "BDORZ",
                        "BD_CK_SAM",
                        "BD_LAST_QID",
                        "bdshare_firstime",
                        "TIEBA_USERTYPE",
                        "TIEBAUID",
                        "TBS",
                        "wise_device",
                    )
                    val urls = arrayOf(
                        "https://baidu.com",
                        "https://tieba.baidu.com",
                        "https://wappass.baidu.com",
                        "https://passport.baidu.com",
                    )
                    // Also learn every cookie name actually present, so a pending
                    // passport flow cannot pin us to an old (possibly half-finished)
                    // SMS / password step after clearing.
                    for (url in urls) {
                        val raw = manager.getCookie(url) ?: continue
                        for (part in raw.split(";")) {
                            val trimmed = part.trim()
                            val index = trimmed.indexOf('=')
                            if (index > 0) names.add(trimmed.substring(0, index).trim())
                        }
                    }
                    val domains = arrayOf(
                        ".baidu.com",
                        ".tieba.baidu.com",
                        ".wappass.baidu.com",
                        ".passport.baidu.com",
                    )
                    for (name in names) {
                        for (url in urls) {
                            for (domain in domains) {
                                try {
                                    manager.setCookie(
                                        url,
                                        "$name=; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; Domain=$domain",
                                    )
                                } catch (_: Exception) {
                                }
                            }
                            try {
                                manager.setCookie(
                                    url,
                                    "$name=; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/",
                                )
                            } catch (_: Exception) {
                            }
                        }
                    }
                    try {
                        manager.flush()
                    } catch (_: Exception) {
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "capulife/media",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImage" -> {
                    if (pendingPick != null || pendingPicks != null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    pendingPick = result
                    val intent =
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                        }
                    try {
                        startActivityForResult(intent, REQUEST_PICK_IMAGE)
                    } catch (_: Exception) {
                        pendingPick = null
                        result.success(null)
                    }
                }
                "pickImages" -> {
                    if (pendingPick != null || pendingPicks != null) {
                        result.success(emptyList<String>())
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as? Map<*, *>
                    pendingPicksLimit = ((args?.get("count") as? Number)?.toInt() ?: 9).coerceIn(1, 9)
                    pendingPicks = result
                    val intent =
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            putExtra("android.provider.extra.PICK_IMAGES_MAX", pendingPicksLimit)
                        }
                    try {
                        startActivityForResult(intent, REQUEST_PICK_IMAGES)
                    } catch (_: Exception) {
                        pendingPicks = null
                        result.success(emptyList<String>())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_APK) {
            val pending = pendingApk
            pendingApk = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return
            }
            try {
                val dir = File(filesDir, "updates")
                if (!dir.exists()) dir.mkdirs()
                val target = File(dir, "local_${System.currentTimeMillis()}.apk")
                contentResolver.openInputStream(data.data!!)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                } ?: run {
                    pending.success(null)
                    return
                }
                pending.success(target.absolutePath)
            } catch (_: Exception) {
                pending.success(null)
            }
            return
        }
        if (requestCode == REQUEST_PICK_IMAGES) {
            val pending = pendingPicks
            pendingPicks = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK) {
                pending.success(emptyList<String>())
                return
            }
            val uris = mutableListOf<Uri>()
            data?.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index)?.uri?.let { uris.add(it) }
                }
            }
            data?.data?.let { uri ->
                if (uris.isEmpty()) uris.add(uri)
            }
            if (uris.isEmpty()) {
                pending.success(emptyList<String>())
                return
            }
            val paths = mutableListOf<String>()
            val dir = File(filesDir, "cap_images")
            if (!dir.exists()) dir.mkdirs()
            for ((index, uri) in uris.take(pendingPicksLimit).withIndex()) {
                try {
                    val target = File(dir, "tieba_${System.currentTimeMillis()}_$index.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    } ?: continue
                    paths.add(target.absolutePath)
                } catch (_: Exception) {
                }
            }
            pending.success(paths)
            return
        }
        if (requestCode != REQUEST_PICK_IMAGE) return
        val pending = pendingPick
        pendingPick = null
        if (pending == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }
        val uri = data.data!!
        try {
            val dir = File(filesDir, "cap_images")
            if (!dir.exists()) dir.mkdirs()
            val target = File(dir, "countdown_${System.currentTimeMillis()}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: run {
                pending.success(null)
                return
            }
            pending.success(target.absolutePath)
        } catch (_: Exception) {
            pending.success(null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
    }

    companion object {
        private const val REQUEST_PICK_IMAGE = 4101
        private const val REQUEST_PICK_IMAGES = 4102
        private const val REQUEST_PICK_APK = 4103
        private const val REQUEST_NOTIFICATION_PERMISSION = 4102
    }
}
