package com.capulife.capulife_native

import android.annotation.SuppressLint
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Message
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.JsResult
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

@SuppressLint("SetJavaScriptEnabled")
class CapWebView(
    context: Context,
    private val id: String,
    private val startUrl: String,
    private val startUserAgent: String,
    messenger: BinaryMessenger,
) : PlatformView {
    private val webView = WebView(context)
    private val channel = MethodChannel(messenger, "capulife/webview/$id")
    private val appContext = context.applicationContext
    private var lastTitle = ""

    private fun emitTitle(title: String) {
        if (title == lastTitle) return
        lastTitle = title
        channel.invokeMethod("title", title)
    }

    init {
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true
        settings.setSupportMultipleWindows(false)
        settings.loadsImagesAutomatically = true
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        settings.mediaPlaybackRequiresUserGesture = true
        val defaultUa = settings.userAgentString ?: ""
        if (startUserAgent.isNotEmpty()) {
            settings.userAgentString = startUserAgent
        } else if (!defaultUa.contains("CapuLifeNative")) {
            settings.userAgentString = "$defaultUa CapuLifeNative/3.0.03"
        }
        webView.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun postMessage(value: String?) {
                    val text = value ?: ""
                    webView.post { emitTitle(text) }
                }
            },
            "CapBridge",
        )
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
        webView.setBackgroundColor(0xFFF4F1E9.toInt())
        webView.isVerticalScrollBarEnabled = false
        webView.isHorizontalScrollBarEnabled = false

        webView.webViewClient =
            object : WebViewClient() {
                override fun onPageStarted(
                    view: WebView?,
                    url: String?,
                    favicon: Bitmap?,
                ) {
                    channel.invokeMethod("started", url)
                }

                override fun onPageFinished(
                    view: WebView?,
                    url: String?,
                ) {
                    try {
                        CookieManager.getInstance().flush()
                    } catch (_: Exception) {
                    }
                    channel.invokeMethod("loaded", url)
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: android.webkit.WebResourceError?,
                ) {
                    if (request?.isForMainFrame == true) {
                        channel.invokeMethod(
                            "error",
                            mapOf(
                                "url" to (request.url?.toString() ?: ""),
                                "message" to (error?.description?.toString() ?: "页面加载失败"),
                            ),
                        )
                    }
                }

                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?,
                ): Boolean {
                    val uri = request?.url ?: return false
                    val scheme = uri.scheme?.lowercase() ?: ""
                    if (scheme == "http" || scheme == "https" || scheme == "about") return false
                    try {
                        appContext.startActivity(
                            Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    } catch (_: Exception) {
                    }
                    return true
                }
            }

        webView.webChromeClient =
            object : WebChromeClient() {
                override fun onReceivedTitle(
                    view: WebView?,
                    title: String?,
                ) {
                    if (title != null) emitTitle(title)
                }

                override fun onProgressChanged(
                    view: WebView?,
                    newProgress: Int,
                ) {
                    channel.invokeMethod("progress", newProgress)
                }

                override fun onCreateWindow(
                    view: WebView?,
                    isDialog: Boolean,
                    isUserGesture: Boolean,
                    resultMsg: Message?,
                ): Boolean {
                    return false
                }

                override fun onJsAlert(
                    view: WebView?,
                    url: String?,
                    message: String?,
                    result: JsResult?,
                ): Boolean {
                    if (result == null) return false
                    try {
                        AlertDialog.Builder(view?.context ?: appContext)
                            .setMessage(message)
                            .setPositiveButton("知道了") { _, _ -> result.confirm() }
                            .setOnCancelListener { result.cancel() }
                            .show()
                    } catch (_: Exception) {
                        result.confirm()
                    }
                    return true
                }

                override fun onJsConfirm(
                    view: WebView?,
                    url: String?,
                    message: String?,
                    result: JsResult?,
                ): Boolean {
                    if (result == null) return false
                    try {
                        AlertDialog.Builder(view?.context ?: appContext)
                            .setMessage(message)
                            .setPositiveButton("确定") { _, _ -> result.confirm() }
                            .setNegativeButton("取消") { _, _ -> result.cancel() }
                            .setOnCancelListener { result.cancel() }
                            .show()
                    } catch (_: Exception) {
                        result.cancel()
                    }
                    return true
                }
            }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "evalJs" -> {
                    val script = call.arguments as? String ?: ""
                    webView.evaluateJavascript(script) { value -> result.success(value) }
                }
                "reload" -> {
                    webView.reload()
                    result.success(true)
                }
                "loadUrl" -> {
                    val url = call.arguments as? String ?: ""
                    if (url.isNotEmpty()) webView.loadUrl(url)
                    result.success(true)
                }
                "canGoBack" -> result.success(webView.canGoBack())
                "goBack" -> {
                    if (webView.canGoBack()) webView.goBack()
                    result.success(true)
                }
                "currentUrl" -> result.success(webView.url ?: "")
                else -> result.notImplemented()
            }
        }

        if (startUrl.isNotEmpty()) webView.loadUrl(startUrl)
    }

    override fun getView(): View = webView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        try {
            webView.stopLoading()
            webView.loadUrl("about:blank")
            webView.removeAllViews()
            webView.destroy()
        } catch (_: Exception) {
        }
    }
}