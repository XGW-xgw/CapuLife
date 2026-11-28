import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class CapWebView extends StatefulWidget {
  const CapWebView({
    super.key,
    required this.url,
    this.onTitle,
    this.onLoaded,
    this.onStarted,
    this.onError,
    this.onProgress,
    this.userAgent = '',
  });

  final String url;
  final String userAgent;
  final ValueChanged<String>? onTitle;
  final ValueChanged<String>? onLoaded;
  final ValueChanged<String>? onStarted;
  final void Function(String url, String message)? onError;
  final ValueChanged<int>? onProgress;

  @override
  State<CapWebView> createState() => CapWebViewState();
}

class CapWebViewState extends State<CapWebView> {
  late final String _id = 'wv_${DateTime.now().microsecondsSinceEpoch}';
  late final MethodChannel _channel = MethodChannel('capulife/webview/$_id');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleCall);
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'title':
        widget.onTitle?.call('${call.arguments ?? ''}');
        return null;
      case 'loaded':
        widget.onLoaded?.call('${call.arguments ?? ''}');
        return null;
      case 'started':
        widget.onStarted?.call('${call.arguments ?? ''}');
        return null;
      case 'error':
        if (call.arguments is Map) {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          widget.onError?.call(
            '${args['url'] ?? ''}',
            '${args['message'] ?? '页面加载失败'}',
          );
        }
        return null;
      case 'progress':
        if (call.arguments is num) {
          widget.onProgress?.call((call.arguments as num).toInt());
        }
        return null;
    }
    return null;
  }

  Future<String?> evalJs(String script) async {
    try {
      return await _channel.invokeMethod<String>('evalJs', script);
    } catch (_) {
      return null;
    }
  }

  Future<void> reload() async {
    try {
      await _channel.invokeMethod('reload');
    } catch (_) {}
  }

  Future<void> loadUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _channel.invokeMethod('loadUrl', url);
    } catch (_) {}
  }

  Future<bool> canGoBack() async {
    try {
      return await _channel.invokeMethod<bool>('canGoBack') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> goBack() async {
    try {
      await _channel.invokeMethod('goBack');
    } catch (_) {}
  }

  Future<String> currentUrl() async {
    try {
      return await _channel.invokeMethod<String>('currentUrl') ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidView(
        viewType: 'capulife/webview',
        creationParams: {
          'id': _id,
          'url': widget.url,
          'userAgent': widget.userAgent,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Container(
      color: AppColors.surfaceSoft,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        '内置网页仅支持 Android 版本',
        style: TextStyle(fontSize: 14, color: AppColors.muted),
      ),
    );
  }
}