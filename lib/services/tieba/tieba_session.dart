import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../data/cap_storage.dart';
import 'tieba_crypto.dart';
import 'tieba_models.dart';

class TiebaDevice {
  TiebaDevice({
    required this.uuid,
    required this.androidId,
    required this.firstInstallTime,
    required this.lastUpdateTime,
    required this.activeTimestamp,
    required this.clientId,
    required this.sampleId,
    required this.baiduId,
  });

  String uuid;
  String androidId;
  int firstInstallTime;
  int lastUpdateTime;
  int activeTimestamp;
  String clientId;
  String sampleId;
  String baiduId;

  String uid = '';
  String nameShow = '';
  String bduss = '';
  String stoken = '';
  String tbs = '';
  String zid = '';
  String webCookie = '';

  String get baseCuidValue => baseCuid(androidId);
  String get finalCuidValue => finalCuid(androidId);
  String get newCuidValue => newCuid(androidId);
  String get c3Aid => tiebaAid(androidId: androidId, uuid: uuid);
  String get base64AndroidIdValue => base64Utf8(androidId);
  String get imei => '000000000000000';
  String get model => 'Pixel 8';
  String get brand => 'Google';
  String get osVersion => '34';
  int get screenWidth => 1080;
  int get screenHeight => 2400;
  double get screenDensity => 2.75;
  String get eventDay {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String get oaidJson => '{"v":"","sc":-200,"sup":0,"isTrackLimited":0}';
  String get deviceScore => '0.423';

  String webUserAgent([String append = '']) {
    const base =
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/135.0.0.0 Mobile Safari/537.36';
    return append.isEmpty ? base : '$base $append';
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'androidId': androidId,
    'firstInstallTime': firstInstallTime,
    'lastUpdateTime': lastUpdateTime,
    'activeTimestamp': activeTimestamp,
    'clientId': clientId,
    'sampleId': sampleId,
    'baiduId': baiduId,
  };

  factory TiebaDevice.fromJson(Map<String, dynamic> json, TiebaDevice fallback) {
    return TiebaDevice(
      uuid: '${json['uuid'] ?? fallback.uuid}',
      androidId: '${json['androidId'] ?? fallback.androidId}',
      firstInstallTime:
          tiebaInt(json['firstInstallTime']) != 0
              ? tiebaInt(json['firstInstallTime'])
              : fallback.firstInstallTime,
      lastUpdateTime:
          tiebaInt(json['lastUpdateTime']) != 0
              ? tiebaInt(json['lastUpdateTime'])
              : fallback.lastUpdateTime,
      activeTimestamp:
          tiebaInt(json['activeTimestamp']) != 0
              ? tiebaInt(json['activeTimestamp'])
              : fallback.activeTimestamp,
      clientId: '${json['clientId'] ?? fallback.clientId}',
      sampleId: '${json['sampleId'] ?? fallback.sampleId}',
      baiduId: '${json['baiduId'] ?? fallback.baiduId}',
    );
  }
}

class TiebaAccount {
  TiebaAccount({
    required this.uid,
    required this.name,
    required this.nameShow,
    required this.portrait,
    required this.bduss,
    required this.stoken,
    required this.tbs,
    required this.zid,
    required this.baiduId,
    required this.cookie,
    this.fansNum = 0,
    this.concernNum = 0,
    this.postNum = 0,
    this.updatedAt = 0,
  });

  String uid;
  String name;
  String nameShow;
  String portrait;
  String bduss;
  String stoken;
  String tbs;
  String zid;
  String baiduId;
  String cookie;
  int fansNum;
  int concernNum;
  int postNum;
  int updatedAt;

  String get displayName => nameShow.isNotEmpty ? nameShow : (name.isNotEmpty ? name : '贴吧用户');

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'nameShow': nameShow,
    'portrait': portrait,
    'bduss': bduss,
    'stoken': stoken,
    'tbs': tbs,
    'zid': zid,
    'baiduId': baiduId,
    'cookie': cookie,
    'fansNum': fansNum,
    'concernNum': concernNum,
    'postNum': postNum,
    'updatedAt': updatedAt,
  };

  factory TiebaAccount.fromJson(Map<String, dynamic> json) => TiebaAccount(
    uid: '${json['uid'] ?? ''}',
    name: '${json['name'] ?? ''}',
    nameShow: '${json['nameShow'] ?? ''}',
    portrait: '${json['portrait'] ?? ''}',
    bduss: '${json['bduss'] ?? ''}',
    stoken: '${json['stoken'] ?? ''}',
    tbs: '${json['tbs'] ?? ''}',
    zid: '${json['zid'] ?? ''}',
    baiduId: '${json['baiduId'] ?? ''}',
    cookie: '${json['cookie'] ?? ''}',
    fansNum: tiebaInt(json['fansNum']),
    concernNum: tiebaInt(json['concernNum']),
    postNum: tiebaInt(json['postNum']),
    updatedAt: tiebaInt(json['updatedAt']),
  );
}

class TiebaCookies {
  static const _channel = MethodChannel('capulife/tieba');

  static Future<String> read([String url = 'https://tieba.baidu.com']) async {
    try {
      return await _channel.invokeMethod<String>('getCookies', url) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> clearBaidu() async {
    try {
      await _channel.invokeMethod('clearBaiduCookies');
    } catch (_) {}
  }
}

class TiebaSessionStore {
  TiebaSessionStore._(this.device, this.account);

  static TiebaSessionStore? _instance;
  static TiebaSessionStore? get instance => _instance;

  TiebaDevice device;
  TiebaAccount? account;
  Map<String, String> signCache = {};

  static const _fileName = 'tieba_state_v1.json';

  static Future<TiebaSessionStore> load() async {
    if (_instance != null) return _instance!;
    Map<String, dynamic>? saved;
    try {
      final dir = await CapStorage.filesDir();
      if (dir != null) {
        final file = File('$dir/$_fileName');
        if (await file.exists()) {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map) saved = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final defaultDevice = TiebaDevice(
      uuid: _uuidV4(random),
      androidId: List<int>.generate(
        16,
        (_) => random.nextInt(16),
      ).map((e) => e.toRadixString(16)).join(),
      firstInstallTime: now,
      lastUpdateTime: now,
      activeTimestamp: now,
      clientId: 'wappc_${now}_${random.nextInt(1000)}',
      sampleId: '',
      baiduId: '',
    );
    TiebaDevice device = defaultDevice;
    if (saved?['device'] is Map) {
      device = TiebaDevice.fromJson(
        Map<String, dynamic>.from(saved!['device'] as Map),
        defaultDevice,
      );
    }
    TiebaAccount? account;
    if (saved?['account'] is Map) {
      final parsed = TiebaAccount.fromJson(
        Map<String, dynamic>.from(saved!['account'] as Map),
      );
      if (parsed.bduss.isNotEmpty) account = parsed;
    }
    final store = TiebaSessionStore._(device, account);
    if (saved?['signs'] is Map) {
      store.signCache = (saved!['signs'] as Map).map(
        (key, value) => MapEntry('$key', '$value'),
      );
    }
    _applyAccount(store.device, account);
    _instance = store;
    if (saved == null) await store.save();
    return store;
  }

  static String _uuidV4(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static void _applyAccount(TiebaDevice device, TiebaAccount? account) {
    device.uid = account?.uid ?? '';
    device.nameShow = account?.nameShow ?? '';
    device.webCookie = account?.cookie ?? '';
    device.bduss = account?.bduss ?? '';
    device.stoken = account?.stoken ?? '';
    device.tbs = account?.tbs ?? '';
    device.zid = account?.zid ?? '';
    if (account != null && account.baiduId.isNotEmpty) {
      device.baiduId = account.baiduId;
    }
  }

  void setAccount(TiebaAccount? value) {
    account = value;
    _applyAccount(device, value);
    save();
  }

  void refreshDeviceAccount() {
    _applyAccount(device, account);
  }

  Future<void> save() async {
    try {
      final dir = await CapStorage.filesDir();
      if (dir == null) return;
      final file = File('$dir/$_fileName');
      await file.writeAsString(
        jsonEncode({
          'device': device.toJson(),
          'account': account?.toJson(),
          'signs': signCache,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  bool signedToday(String uid, int forumId) {
    final date = DateTime.now();
    final key =
        'sign:${uid.isEmpty ? 'guest' : uid}:$forumId:${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return signCache[key] == '1';
  }

  void markSigned(String uid, int forumId) {
    final date = DateTime.now();
    final key =
        'sign:${uid.isEmpty ? 'guest' : uid}:$forumId:${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    signCache[key] = '1';
    save();
  }

  Future<void> logout() async {
    account = null;
    _applyAccount(device, null);
    device.tbs = '';
    await TiebaCookies.clearBaidu();
    await save();
  }
}

String parseTiebaCookieValue(String raw, String key) {
  for (final part in raw.split(';')) {
    final trimmed = part.trim();
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    if (trimmed.substring(0, index).trim() == key) {
      return trimmed.substring(index + 1).trim();
    }
  }
  return '';
}

Map<String, String> parseTiebaCookies(String raw) {
  final map = <String, String>{};
  for (final part in raw.split(';')) {
    final trimmed = part.trim();
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    final key = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) map[key] = value;
  }
  return map;
}

String tiebaCookieHeader(Map<String, String> map) =>
    map.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');