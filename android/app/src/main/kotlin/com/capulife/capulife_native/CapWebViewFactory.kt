package com.capulife.capulife_native

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CapWebViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        val id = params["id"] as? String ?: "pv_$viewId"
        val url = params["url"] as? String ?: "about:blank"
        val userAgent = params["userAgent"] as? String ?: ""
        return CapWebView(context, id, url, userAgent, messenger)
    }
}