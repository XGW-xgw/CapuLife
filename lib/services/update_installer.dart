import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/cap_storage.dart';
import 'update_service.dart';

class UpdateInstallResult {
  const UpdateInstallResult({required this.ok, this.needPermission = false});

  final bool ok;
  final bool needPermission;
}

/// Downloads a release APK into the app's private files and hands it to the
/// Android package installer. Android still requires the user to confirm the
/// install; there is no silent-install bypass.
class UpdateInstaller {
  static const _channel = MethodChannel('capulife/update');
  static const _mirrorPrefix = 'https://gh-proxy.com/';

  static Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  static Future<UpdateInstallResult> installApk(String path) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'install',
        {'path': path},
      );
      return UpdateInstallResult(
        ok: result?['ok'] == true,
        needPermission: result?['needPermission'] == true,
      );
    } catch (_) {
      return const UpdateInstallResult(ok: false);
    }
  }

  static Future<String?> pickApk() async {
    try {
      final path = await _channel.invokeMethod<String>('pickApk');
      if (path == null || path.isEmpty) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<String> download(
    ReleaseInfo release, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final url = release.apkUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      throw StateError('这个版本没有 APK 附件，只能打开网页更新');
    }
    final base = await CapStorage.filesDir();
    if (base == null) throw StateError('无法访问本机存储');
    final dir = Directory('$base/updates');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeVersion = release.version.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final target = File('${dir.path}/CapuLife-$safeVersion.apk');
    if (await target.exists() && await target.length() > 1000000) {
      try {
        final head = await target.openRead(0, 2).first;
        if (head.length >= 2 && head[0] == 0x50 && head[1] == 0x4B) {
          return target.path;
        }
      } catch (_) {}
    }
    if (await target.exists()) {
      try {
        await target.delete();
      } catch (_) {}
    }
    final urls = <String>[
      url,
      if (url.startsWith('https://github.com/') ||
          url.startsWith('https://objects.githubusercontent.com/'))
        '$_mirrorPrefix$url',
    ];
    Object? lastError;
    for (final source in urls) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      IOSink? sink;
      try {
        final request = await client.getUrl(Uri.parse(source)).timeout(
          const Duration(seconds: 10),
        );
        request.headers.set(HttpHeaders.userAgentHeader, 'CapuLife/3.0.03');
        request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
        final response = await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final total = response.contentLength;
        final fileSink = target.openWrite();
        sink = fileSink;
        var received = 0;
        var first = true;
        await for (final chunk in response) {
          if (first) {
            first = false;
            if (chunk.length < 2 || chunk[0] != 0x50 || chunk[1] != 0x4B) {
              throw StateError('下载内容不是 APK');
            }
          }
          fileSink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress?.call(
              (received / total).clamp(0.0, 1.0),
              received,
              total,
            );
          } else {
            onProgress?.call(0, received, 0);
          }
        }
        await fileSink.flush();
        await fileSink.close();
        sink = null;
        if (total > 0 && received != total) {
          throw StateError('下载不完整');
        }
        if (!await target.exists() || await target.length() < 1000000) {
          throw StateError('下载的 APK 不完整');
        }
        return target.path;
      } catch (error) {
        lastError = error;
        try {
          await sink?.close();
        } catch (_) {}
        try {
          if (await target.exists()) await target.delete();
        } catch (_) {}
      } finally {
        client.close(force: true);
        try {
          await sink?.close();
        } catch (_) {}
      }
    }
    throw StateError(lastError == null ? '更新下载失败' : '更新下载失败：$lastError');
  }
}