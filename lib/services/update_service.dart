import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_info.dart';

class ReleaseInfo {
  ReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.apkUrl,
    required this.pageUrl,
  });

  final String tag;
  final String version;
  final String name;
  final String notes;
  final String apkUrl;
  final String pageUrl;
}

class UpdateCheckResult {
  UpdateCheckResult({required this.ok, this.release, this.error = ''});

  final bool ok;
  final ReleaseInfo? release;
  final String error;
}

int compareVersion(String a, String b) {
  String normalize(String value) => value.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
  final leftRaw = normalize(a);
  final rightRaw = normalize(b);
  final leftDash = leftRaw.indexOf('-');
  final rightDash = rightRaw.indexOf('-');
  final leftCore = leftDash >= 0 ? leftRaw.substring(0, leftDash) : leftRaw;
  final rightCore = rightDash >= 0 ? rightRaw.substring(0, rightDash) : rightRaw;
  final leftPre = leftDash >= 0 ? leftRaw.substring(leftDash + 1) : '';
  final rightPre = rightDash >= 0 ? rightRaw.substring(rightDash + 1) : '';
  final leftParts = leftCore.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final rightParts = rightCore.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var i = 0; i < length; i += 1) {
    final valueA = i < leftParts.length ? leftParts[i] : 0;
    final valueB = i < rightParts.length ? rightParts[i] : 0;
    if (valueA != valueB) return valueA > valueB ? 1 : -1;
  }
  if (leftPre.isEmpty && rightPre.isNotEmpty) return 1;
  if (leftPre.isNotEmpty && rightPre.isEmpty) return -1;
  if (leftPre == rightPre) return 0;
  return leftPre.compareTo(rightPre) > 0 ? 1 : -1;
}

class UpdateService {
  static const _mirrorPrefix = 'https://gh-proxy.com/';
  static const _timeout = Duration(milliseconds: 6500);

  static Future<dynamic> _requestJson(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'CapuLife/$appVersion');
      final response = await request.close().timeout(_timeout);
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  static ReleaseInfo? _pickRelease(dynamic data) {
    if (data is! List) return null;
    final releases = data
        .whereType<Map>()
        .where((item) => item['draft'] != true && '${item['tag_name'] ?? ''}'.isNotEmpty)
        .toList();
    if (releases.isEmpty) return null;
    releases.sort(
      (a, b) => compareVersion(
        '${b['tag_name']}',
        '${a['tag_name']}',
      ),
    );
    final raw = releases.first;
    final assets = raw['assets'] is List ? raw['assets'] as List : const [];
    Map? apk;
    for (final asset in assets) {
      if (asset is Map && RegExp(r'\.apk$', caseSensitive: false).hasMatch('${asset['name'] ?? ''}')) {
        apk = asset;
        break;
      }
    }
    final tag = '${raw['tag_name'] ?? ''}';
    return ReleaseInfo(
      tag: tag,
      version: tag.replaceFirst(RegExp(r'^v', caseSensitive: false), ''),
      name: '${raw['name'] ?? raw['tag_name'] ?? ''}',
      notes: '${raw['body'] ?? ''}'.length > 500
          ? '${raw['body']}'.substring(0, 500)
          : '${raw['body'] ?? ''}',
      apkUrl: apk == null
          ? '${raw['html_url'] ?? ''}'
          : '${apk['browser_download_url'] ?? raw['html_url'] ?? ''}',
      pageUrl: '${raw['html_url'] ?? ''}',
    );
  }

  static Future<UpdateCheckResult> check(String repo) async {
    final clean = repo
        .trim()
        .replaceFirst(RegExp(r'^https?://github\.com/'), '')
        .replaceFirst(RegExp(r'\.git$'), '')
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
    if (clean.isEmpty || !RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(clean)) {
      return UpdateCheckResult(ok: false, error: '未配置更新仓库');
    }
    final api = 'https://api.github.com/repos/$clean/releases?per_page=5';
    var lastError = 'network';
    for (final url in [api, '$_mirrorPrefix$api']) {
      try {
        final data = await _requestJson(url);
        final release = _pickRelease(data);
        if (release == null) {
          return UpdateCheckResult(ok: false, error: '仓库还没有发布版本');
        }
        return UpdateCheckResult(ok: true, release: release);
      } catch (error) {
        lastError = '$error';
      }
    }
    return UpdateCheckResult(ok: false, error: lastError);
  }
}
