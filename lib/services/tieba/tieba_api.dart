import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'proto_codec.dart';
import 'tieba_crypto.dart';
import 'tieba_models.dart';
import 'tieba_session.dart';

const _officialHost = 'https://c.tieba.baidu.com';
const _protoHost = 'https://tiebac.baidu.com';
const _clientVersion = '12.52.1.0';
const _tiebaBoundary = '--------7da3d81520810*';

class TiebaApiException implements Exception {
  TiebaApiException(this.code, this.message, [this.detail]);

  final int code;
  final String message;
  final dynamic detail;

  @override
  String toString() => message;
}

class _TiebaResponse {
  _TiebaResponse(this.status, this.text, this.headers);

  final int status;
  final String text;
  final Map<String, List<String>> headers;
}

class TiebaApi {
  TiebaApi({
    required this.device,
    this.onDeviceChanged,
    this.timeout = const Duration(seconds: 20),
  });

  final TiebaDevice device;
  final Future<void> Function()? onDeviceChanged;
  final Duration timeout;

  Map<String, String> _baseParams() {
    final params = <String, String>{
      '_client_id': device.clientId,
      '_client_type': '2',
      '_os_version': device.osVersion,
      'model': device.model,
      'net_type': '1',
      '_phone_imei': device.imei,
      'timestamp': '${DateTime.now().millisecondsSinceEpoch}',
    };
    if (device.bduss.isNotEmpty) params['BDUSS'] = device.bduss;
    return params;
  }

  Map<String, String> _deviceParams() => {
    'active_timestamp': '${device.activeTimestamp}',
    'android_id': device.base64AndroidIdValue,
    'brand': device.brand,
    'cmode': '1',
    'cuid': device.newCuidValue,
    'cuid_galaxy2': device.newCuidValue,
    'cuid_gid': '',
    'c3_aid': device.c3Aid,
    'event_day': device.eventDay,
    'extra': '',
    'first_install_time': '${device.firstInstallTime}',
    'framework_ver': '3340042',
    'from': 'tieba',
    'is_teenager': '0',
    'last_update_time': '${device.lastUpdateTime}',
    'mac': '02:00:00:00:00:00',
    'sdk_ver': '2.34.0',
    'start_scheme': '',
    'start_type': '1',
    'swan_game_ver': '1038000',
    '_client_version': _clientVersion,
    'oaid': device.oaidJson,
  };

  Map<String, String> _randomSt() {
    final num = 100 + Random().nextInt(750);
    if (num <= 120) return {'stErrorNums': '0'};
    final size = ((Random().nextDouble() * 8 + 0.4) * num).round();
    return {
      'stErrorNums': '1',
      'stMethod': '1',
      'stMode': '1',
      'stTimesNum': '1',
      'stTime': '$num',
      'stSize': '$size',
    };
  }

  Map<String, String> _officialHeaders({String? userAgent, Map<String, String>? extra}) => {
    'User-Agent': userAgent ?? 'bdtb for Android 12.52.1.0',
    'cookie':
        'CUID=${device.newCuidValue};ka=open;TBBRAND=${device.model};BAIDUID=${device.baiduId};',
    'cuid': device.newCuidValue,
    'cuid_galaxy2': device.newCuidValue,
    'cuid_gid': '',
    'c3_aid': device.c3Aid,
    'client_logid': '${device.activeTimestamp}',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    ...?extra,
  };

  Future<_TiebaResponse> _send({
    required String url,
    required String method,
    required Map<String, String> headers,
    String? body,
    bool binary = false,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.openUrl(method, Uri.parse(url)).timeout(timeout);
      headers.forEach(request.headers.set);
      request.headers.contentLength = binary ? body?.length ?? 0 : utf8.encode(body ?? '').length;
      if (body != null && body.isNotEmpty) {
        request.add(binary ? latin1.encode(body) : utf8.encode(body));
      }
      final response = await request.close().timeout(timeout);
      final text = binary
          ? latin1.decode(await response.fold<List<int>>([], (a, b) => a..addAll(b)))
          : await utf8.decoder.bind(response).join();
      final headerMap = <String, List<String>>{};
      response.headers.forEach((name, values) {
        headerMap[name.toLowerCase()] = values;
      });
      return _TiebaResponse(response.statusCode, text, headerMap);
    } on TiebaApiException {
      rethrow;
    } on SocketException {
      throw TiebaApiException(-1, '网络请求失败，请检查网络');
    } on TimeoutException {
      throw TiebaApiException(-1, '贴吧请求超时，请重试');
    } catch (error) {
      throw TiebaApiException(-1, '网络请求失败，请检查网络');
    } finally {
      client.close(force: true);
    }
  }

  Future<({int status, Uint8List bytes})> _sendBinary({
    required String url,
    required Map<String, String> headers,
    required Uint8List body,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(Uri.parse(url)).timeout(timeout);
      headers.forEach(request.headers.set);
      request.headers.contentLength = body.length;
      request.add(body);
      final response = await request.close().timeout(timeout);
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return (status: response.statusCode, bytes: builder.toBytes());
    } on SocketException {
      throw TiebaApiException(-1, '网络请求失败，请检查网络');
    } on TimeoutException {
      throw TiebaApiException(-1, '贴吧请求超时，请重试');
    } catch (error) {
      throw TiebaApiException(-1, '网络请求失败，请检查网络');
    } finally {
      client.close(force: true);
    }
  }

  Map<String, String> _protoHeaders({
    required String version,
    required bool isPost,
    required Map<String, String> extra,
  }) {
    final headers = <String, String>{
      'Charset': 'UTF-8',
      if (!isPost) 'client_type': '2',
      if (version == tiebaVersionV12 && !isPost)
        'client_logid': '${device.activeTimestamp}',
      if (device.uid.isNotEmpty) 'client_user_token': device.uid,
      'cookie': version == tiebaVersionV11
          ? 'CUID=${device.newCuidValue};ka=open;TBBRAND=${device.model};'
          : [
              if (isPost && device.zid.isNotEmpty) 'BAIDUZID:${device.zid}',
              'ka:open',
              'CUID:${device.newCuidValue}',
              'TBBRAND:${device.model}',
            ].join('; '),
      'cuid': device.newCuidValue,
      'cuid_galaxy2': device.newCuidValue,
      'cuid_gid': '',
      'c3_aid': device.c3Aid,
      'User-Agent': version == tiebaVersionV11
          ? 'bdtb for Android $version'
          : device.webUserAgent('tieba/$version'),
      'x_bd_data_type': 'protobuf',
      'Content-Type': 'multipart/form-data; boundary=$_tiebaBoundary',
      ...extra,
    };
    return headers;
  }

  Map<String, String> _protoTextFields({
    required String version,
    required bool signed,
    required bool isPost,
  }) {
    final fields = <String, String>{};
    if (!signed) {
      if (device.stoken.isNotEmpty) fields['stoken'] = device.stoken;
      return fields;
    }
    fields.addAll(_baseParams());
    fields.remove('_os_version');
    fields['_client_version'] = version;
    fields['cuid'] = device.newCuidValue;
    fields['cuid_galaxy2'] = device.newCuidValue;
    fields['cuid_gid'] = '';
    fields['c3_aid'] = device.c3Aid;
    fields['from'] = 'tieba';
    fields['oaid'] = device.oaidJson;
    if (isPost) {
      fields['active_timestamp'] = '${device.activeTimestamp}';
      fields['android_id'] = device.base64AndroidIdValue;
      if (device.baiduId.isNotEmpty) fields['baiduid'] = device.baiduId;
      fields['brand'] = device.brand;
      fields['cmode'] = '1';
      fields['device_score'] = device.deviceScore;
      fields['event_day'] = device.eventDay;
      fields['extra'] = '';
      fields['first_install_time'] = '${device.firstInstallTime}';
      fields['framework_ver'] = '3340042';
      fields['is_teenager'] = '0';
      fields['last_update_time'] = '${device.lastUpdateTime}';
      fields['mac'] = '02:00:00:00:00:00';
      fields['naws_game_ver'] = '1038000';
      fields['personalized_rec_switch'] = '1';
      if (device.sampleId.isNotEmpty) fields['sample_id'] = device.sampleId;
      fields['sdk_ver'] = '2.34.0';
      fields['start_scheme'] = '';
      fields['start_type'] = '1';
      if (device.stoken.isNotEmpty) fields['stoken'] = device.stoken;
      fields['z_id'] = device.zid;
    }
    if (device.stoken.isNotEmpty && !fields.containsKey('stoken')) {
      fields['stoken'] = device.stoken;
    }
    return fields;
  }

  Uint8List _buildMultipart({
    required Map<String, String> fields,
    required bool signed,
    required Uint8List fileBytes,
    String fileField = 'data',
  }) {
    final builder = BytesBuilder(copy: false);
    void pushText(String name, String value) {
      builder.add(utf8.encode(
        '--$_tiebaBoundary\r\n'
        'Content-Disposition: form-data; name="$name"\r\n\r\n'
        '$value\r\n',
      ));
    }

    if (signed) {
      final sorted = fields.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sorted) {
        pushText(entry.key, entry.value);
      }
      pushText(
        'sign',
        calculateTiebaSign(
          sorted.map((entry) => '${entry.key}=${entry.value}').join(),
        ),
      );
    } else {
      fields.forEach(pushText);
    }
    builder.add(utf8.encode(
      '--$_tiebaBoundary\r\n'
      'Content-Disposition: form-data; name="$fileField"; filename="file"\r\n\r\n',
    ));
    builder.add(fileBytes);
    builder.add(utf8.encode('\r\n--$_tiebaBoundary--\r\n'));
    return builder.toBytes();
  }

  Future<Uint8List> _postProto(
    String path,
    Uint8List requestBody, {
    String version = tiebaVersionV12,
    bool signed = false,
    bool isPost = false,
  }) async {
    final headers = _protoHeaders(version: version, isPost: isPost, extra: const {});
    final fields = _protoTextFields(version: version, signed: signed, isPost: isPost);
    final body = _buildMultipart(fields: fields, signed: signed, fileBytes: requestBody);
    final response = await _sendBinary(
      url: '$_protoHost$path',
      headers: headers,
      body: body,
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '贴吧接口 HTTP ${response.status}');
    }
    if (response.bytes.isEmpty) {
      throw TiebaApiException(-2, '贴吧返回空响应');
    }
    final unwrapped = unwrapResponse(response.bytes);
    if (unwrapped.errorCode != 0) {
      throw TiebaApiException(
        unwrapped.errorCode,
        unwrapped.errorMsg.isEmpty ? '贴吧接口返回错误' : unwrapped.errorMsg,
        unwrapped.data,
      );
    }
    return unwrapped.data;
  }

  Future<void> _captureBaiduId(_TiebaResponse response) async {    final cookies = response.headers['set-cookie'];
    if (cookies == null) return;
    for (final line in cookies) {
      final first = line.split(';').first.trim();
      final index = first.indexOf('=');
      if (index <= 0) continue;
      final key = first.substring(0, index).trim().toUpperCase();
      final value = first.substring(index + 1).trim();
      if (key == 'BAIDUID' && value.isNotEmpty && device.baiduId != value) {
        device.baiduId = value;
        await onDeviceChanged?.call();
        break;
      }
    }
  }

  Map<String, dynamic> _decodeJson(_TiebaResponse response, {bool hybrid = false}) {
    if (response.text.isEmpty) {
      throw TiebaApiException(-2, '贴吧返回空响应');
    }
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.text);
      if (decoded is! Map) {
        throw const FormatException();
      }
      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw TiebaApiException(-3, '贴吧返回格式异常', response.text.substring(0, min(200, response.text.length)));
    }
    if (!hybrid) {
      final code = tiebaInt(json['error_code']);
      if (code != 0) {
        throw TiebaApiException(
          code,
          '${json['error_msg'] ?? json['error'] ?? '贴吧接口返回错误'}',
          json,
        );
      }
    }
    return json;
  }

  Future<Map<String, dynamic>> _postOfficial(
    String path,
    Map<String, String> params, {
    List<String> drop = const [],
    String? clientVersion,
    String? userAgent,
    Map<String, String> extraHeaders = const {},
  }) async {
    final merged = <String, String>{
      ..._baseParams(),
      ..._deviceParams(),
      if (clientVersion != null) '_client_version': clientVersion,
      ..._randomSt(),
      ...params,
    };
    for (final key in drop) {
      merged.remove(key);
    }
    final response = await _send(
      url: '$_officialHost$path',
      method: 'POST',
      headers: _officialHeaders(userAgent: userAgent, extra: extraHeaders),
      body: encodeSignedFormBody(merged),
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '贴吧接口 HTTP ${response.status}');
    }
    await _captureBaiduId(response);
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> _postNewJson(
    String path,
    Map<String, String> params,
  ) async {
    final merged = <String, String>{
      ..._baseParams(),
      'cuid': device.finalCuidValue,
      'cuid_galaxy2': device.finalCuidValue,
      'from': 'baidu_appstore',
      '_client_version': '8.2.2',
      ..._randomSt(),
      ...params,
    };
    final headers = _officialHeaders(userAgent: 'bdtb for Android 8.2.2');
    headers['cookie'] = 'ka=open';
    headers['Pragma'] = 'no-cache';
    headers['cuid'] = device.finalCuidValue;
    final response = await _send(
      url: '$_officialHost$path',
      method: 'POST',
      headers: headers,
      body: encodeSignedFormBody(merged),
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '贴吧接口 HTTP ${response.status}');
    }
    await _captureBaiduId(response);
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> _postMiniJson(
    String path,
    Map<String, String> params, {
    String version = '7.2.0.0',
    Map<String, String> extraHeaders = const {},
  }) async {
    final merged = <String, String>{
      ..._baseParams(),
      'cuid': device.finalCuidValue,
      'cuid_galaxy2': device.finalCuidValue,
      'from': '1021636m',
      '_client_version': version,
      'subapp_type': 'mini',
      ..._randomSt(),
      ...params,
    };
    final headers = _officialHeaders(
      userAgent: 'bdtb for Android $version',
      extra: extraHeaders,
    );
    headers['cookie'] = 'ka=open';
    headers['Pragma'] = 'no-cache';
    headers['cuid'] = device.finalCuidValue;
    headers['cuid_galaxy2'] = device.finalCuidValue;
    final response = await _send(
      url: '$_officialHost$path',
      method: 'POST',
      headers: headers,
      body: encodeSignedFormBody(merged),
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '贴吧接口 HTTP ${response.status}');
    }
    await _captureBaiduId(response);
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> _getHybridJson(
    String path,
    Map<String, String> query, {
    String referer = '',
  }) async {
    final pairs = query.entries
        .where((entry) => entry.value.isNotEmpty)
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
    final url = 'https://tieba.baidu.com$path${pairs.isEmpty ? '' : '?$pairs'}';
    final response = await _send(
      url: url,
      method: 'GET',
      headers: {
        'User-Agent': device.webUserAgent('tieba/12.52.1.0 skin/default'),
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'X-Requested-With': 'com.baidu.tieba',
        if (referer.isNotEmpty) 'Referer': referer,
        if (device.webCookie.isNotEmpty) 'cookie': device.webCookie,
      },
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '贴吧接口 HTTP ${response.status}');
    }
    return _decodeJson(response, hybrid: true);
  }

  Future<Map<String, dynamic>> frsPage({
    required String kw,
    int pn = 0,
    int rn = 30,
    Map<String, String> extra = const {},
  }) {
    return _postOfficial('/c/f/frs/page', {
      'kw': kw,
      'rn': '$rn',
      'pn': '$pn',
      'cmd': '301001',
      'format': 'json',
      ...extra,
    });
  }

  Future<Map<String, dynamic>> pbPage({
    required int tid,
    int pn = 1,
    int rn = 15,
  }) {
    return _postOfficial('/c/f/pb/page', {
      'kz': '$tid',
      'pn': '$pn',
      'rn': '$rn',
      'cmd': '302001',
      'format': 'json',
    });
  }

  Future<Map<String, dynamic>> pbFloor({
    required int tid,
    required int pid,
    int pn = 1,
    int rn = 20,
  }) {
    return _postOfficial('/c/f/pb/floor', {
      'kz': '$tid',
      'pid': '$pid',
      'pn': '$pn',
      'rn': '$rn',
      'cmd': '302002',
      'format': 'json',
    });
  }

  Future<Map<String, dynamic>> verifyLogin({
    required String bduss,
    String stoken = '',
  }) async {
    final json = await _postOfficial(
      '/c/s/login',
      {
        'bdusstoken': '$bduss|null',
        'stoken': stoken,
        'channel_id': '',
        'channel_uid': '',
        'authsid': 'null',
      },
      drop: ['BDUSS'],
      clientVersion: '11.10.8.6',
      userAgent: 'bdtb for Android 11.10.8.6',
      extraHeaders: const {'cookie': 'ka=open'},
    );
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final anti = json['anti'] is Map
        ? Map<String, dynamic>.from(json['anti'] as Map)
        : <String, dynamic>{};
    final uid = '${user['id'] ?? ''}';
    if (uid.isEmpty || uid == '0') {
      throw TiebaApiException(-6, '${json['error_msg'] ?? 'BDUSS 校验失败，请重新登录'}');
    }
    var tbs = '${anti['tbs'] ?? ''}';
    if (tbs.isEmpty) {
      tbs = await _fetchWebTbs(bduss, stoken);
    }
    return {
      'uid': uid,
      'name': '${user['name'] ?? ''}',
      'nameShow': '${user['name_show'] ?? user['name'] ?? ''}',
      'portrait': '${user['portrait'] ?? ''}',
      'tbs': tbs,
      'fansNum': tiebaInt(user['fans_num']),
      'concernNum': tiebaInt(user['concern_num']),
      'postNum': tiebaInt(user['post_num']),
      'raw': json,
    };
  }

  Future<String> _fetchWebTbs(String bduss, String stoken) async {
    try {
      final cookies = ['BDUSS=$bduss'];
      if (stoken.isNotEmpty) cookies.add('STOKEN=$stoken');
      if (device.baiduId.isNotEmpty) cookies.add('BAIDUID=${device.baiduId}');
      final response = await _send(
        url: 'https://tieba.baidu.com/dc/common/tbs',
        method: 'GET',
        headers: {
          'User-Agent': device.webUserAgent(),
          'Referer': 'https://tieba.baidu.com/',
          'cookie': cookies.join('; '),
        },
      );
      final json = jsonDecode(response.text);
      return '${json['tbs'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> signForum({
    required int forumId,
    required String forumName,
  }) async {
    final json = await _postOfficial(
      '/c/c/forum/sign',
      {
        'fid': '$forumId',
        'kw': forumName,
        'tbs': device.tbs,
      },
      drop: const ['oaid'],
      clientVersion: '11.10.8.6',
      userAgent: 'bdtb for Android 11.10.8.6',
      extraHeaders: {
        'cookie': 'ka=open',
        if (device.uid.isNotEmpty) 'client_user_token': device.uid,
      },
    );
    final info = json['user_info'] is Map
        ? Map<String, dynamic>.from(json['user_info'] as Map)
        : <String, dynamic>{};
    return {
      'success': true,
      'bonus': tiebaInt(info['sign_bonus_point']),
      'contSignNum': tiebaInt(info['cont_sign_num']),
      'rank': tiebaInt(info['user_sign_rank']),
    };
  }

  Future<Map<String, dynamic>> toggleForumLike({
    required int forumId,
    required String forumName,
    required bool like,
  }) {
    final headers = {
      if (device.uid.isNotEmpty) 'client_user_token': device.uid,
    };
    if (like) {
      return _postMiniJson('/c/c/forum/like', {
        'fid': '$forumId',
        'kw': forumName,
        'tbs': device.tbs,
      }, extraHeaders: headers);
    }
    return _postOfficial(
      '/c/c/forum/unfavolike',
      {
        'fid': '$forumId',
        'kw': forumName,
        'tbs': device.tbs,
        if (device.stoken.isNotEmpty) 'stoken': device.stoken,
      },
      drop: const ['oaid'],
      clientVersion: '11.10.8.6',
      userAgent: 'bdtb for Android 11.10.8.6',
      extraHeaders: {'cookie': 'ka=open', ...headers},
    );
  }

  Future<List<Map<String, dynamic>>> followedForums() async {
    if (device.bduss.isEmpty) return [];
    try {
      final all = await _followedForumsGuide();
      if (all.isNotEmpty) return all;
    } catch (_) {
      // Older clients also expose the same list through /c/f/forum/like.
    }
    try {
      final fallback = await _followedForumsLike();
      if (fallback.isNotEmpty) return fallback;
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> _followedForumsGuide() async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page <= 20; page += 1) {
      final json = await _postOfficial('/c/f/forum/forumGuide', {
        'sort_type': '3',
        'call_from': '4',
        'page_no': '$page',
        'res_num': '50',
        'top_forum_num': '0',
        if (device.tbs.isNotEmpty) 'tbs': device.tbs,
        if (device.stoken.isNotEmpty) 'stoken': device.stoken,
      });
      final list = json['like_forum'] is List
          ? (json['like_forum'] as List).whereType<Map>()
          : const <Map>[];
      all.addAll(list.map((e) => Map<String, dynamic>.from(e)));
      final hasMore = json['like_forum_has_more'] == 1 || json['like_forum_has_more'] == '1';
      if (!hasMore || list.isEmpty) break;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _followedForumsLike() async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page <= 20; page += 1) {
      final json = await _postOfficial('/c/f/forum/like', {
        'page_no': '$page',
        'page_size': '50',
        if (device.uid.isNotEmpty) 'uid': device.uid,
      });
      final tree = json['forum_list'] is Map
          ? Map<String, dynamic>.from(json['forum_list'] as Map)
          : const <String, dynamic>{};
      final items = <Map>[];
      final nonGcon = tree['non-gconforum'];
      if (nonGcon is List) items.addAll(nonGcon.whereType<Map>());
      final gcon = tree['gconforum'];
      if (gcon is List) items.addAll(gcon.whereType<Map>());
      all.addAll(items.map((e) => Map<String, dynamic>.from(e)));
      final hasMore = json['has_more'] == 1 || json['has_more'] == '1';
      if (!hasMore || items.isEmpty) break;
    }
    return all;
  }

  Future<void> webSignForum(String forumName) async {
    if (forumName.trim().isEmpty) throw TiebaApiException(-4, '缺少吧信息');
    var tbs = device.tbs;
    if (tbs.isEmpty) {
      tbs = await _fetchWebTbs(device.bduss, device.stoken);
      if (tbs.isNotEmpty) device.tbs = tbs;
    }
    if (tbs.isEmpty) throw TiebaApiException(-5, '登录状态缺少写权限（tbs），请重新登录');
    final cookieParts = <String>[
      if (device.bduss.isNotEmpty) 'BDUSS=${device.bduss}',
      if (device.stoken.isNotEmpty) 'STOKEN=${device.stoken}',
      if (device.baiduId.isNotEmpty) 'BAIDUID=${device.baiduId}',
    ];
    final response = await _send(
      url: 'https://tieba.baidu.com/sign/add',
      method: 'POST',
      headers: {
        'User-Agent': device.webUserAgent('tieba/$_clientVersion'),
        'Referer':
            'https://tieba.baidu.com/f?kw=${Uri.encodeComponent(forumName)}',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'cookie': cookieParts.join('; '),
      },
      body:
          'ie=utf-8&kw=${Uri.encodeComponent(forumName)}&tbs=${Uri.encodeComponent(tbs)}',
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '签到 HTTP ${response.status}');
    }
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.text);
      if (decoded is! Map) throw const FormatException();
      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw TiebaApiException(-3, '签到返回格式异常');
    }
    final code = tiebaInt(json['no'] ?? json['error_code']);
    final message = '${json['error'] ?? json['error_msg'] ?? ''}';
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : const <String, dynamic>{};
    final errno = tiebaInt(data['errno']);
    if (code != 0 || errno != 0) {
      final extra = '${data['errmsg'] ?? data['error_msg'] ?? ''}';
      throw TiebaApiException(
        code != 0 ? code : errno,
        extra.isNotEmpty ? extra : (message.isNotEmpty ? message : '签到失败'),
        json,
      );
    }
  }

  Future<int> mSignForums(List<int> forumIds) async {
    if (forumIds.isEmpty) return 0;
    final json = await _postOfficial(
      '/c/c/forum/msign',
      {
        'forum_ids': forumIds.join(','),
        'tbs': device.tbs,
        'authsid': 'null',
        'stoken': device.stoken,
        'user_id': device.uid,
      },
      clientVersion: '11.10.8.6',
      userAgent: 'bdtb for Android 11.10.8.6',
    );
    final info = json['info'] is List ? json['info'] as List : const [];
    return info.where((item) => item is Map && (item['signed'] == 1 || item['signed'] == '1' || item['signed'] == true)).length;
  }

  Future<List<Map<String, dynamic>>> threadStore({
    int pageSize = 20,
    int offset = 0,
  }) async {
    if (device.bduss.isEmpty) throw TiebaApiException(-7, '请先登录贴吧账号');
    final json = await _postOfficial(
      '/c/f/post/threadstore',
      {
        'rn': '$pageSize',
        'offset': '$offset',
        'stoken': device.stoken,
        'user_id': device.uid,
      },
      drop: const ['oaid'],
      clientVersion: '11.10.8.6',
      userAgent: 'bdtb for Android 11.10.8.6',
      extraHeaders: {
        'cookie': 'ka=open',
        if (device.uid.isNotEmpty) 'client_user_token': device.uid,
      },
    );
    final list = json['store_thread'];
    if (list is! List) return [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addThreadStore({required int threadId, int postId = 0}) {
    return _postOfficial(
      '/c/c/post/addstore',
      {
        'data': jsonEncode([
          {'tid': '$threadId', 'pid': '$postId', 'status': 1},
        ]),
        'stoken': device.stoken,
        if (device.tbs.isNotEmpty) 'tbs': device.tbs,
        if (device.uid.isNotEmpty) 'user_id': device.uid,
      },
      drop: const ['oaid'],
      extraHeaders: {
        'cookie': 'ka=open',
        if (device.uid.isNotEmpty) 'client_user_token': device.uid,
      },
    );
  }

  Future<void> removeThreadStore({
    required int threadId,
    int forumId = 0,
  }) {
    return _postOfficial(
      '/c/c/post/rmstore',
      {
        'tid': '$threadId',
        'fid': forumId > 0 ? '$forumId' : 'null',
        'tbs': device.tbs,
        'stoken': device.stoken,
        'user_id': device.uid,
      },
      drop: const ['oaid'],
      extraHeaders: {
        'cookie': 'ka=open',
        if (device.uid.isNotEmpty) 'client_user_token': device.uid,
      },
    );
  }

  Future<Map<String, dynamic>> opAgree({
    required int threadId,
    int postId = 0,
    int opType = 0,
    int objType = 3,
  }) {
    return _postMiniJson(
      '/c/c/agree/opAgree',
      {
        'thread_id': '$threadId',
        'post_id': '$postId',
        'op_type': '$opType',
        'obj_type': '$objType',
        'agree_type': '2',
        'cuid_gid': '',
        if (device.tbs.isNotEmpty) 'tbs': device.tbs,
        if (device.stoken.isNotEmpty) 'stoken': device.stoken,
      },
      version: '8.0.8.0',
      extraHeaders: {
        if (device.uid.isNotEmpty) 'client_user_token': device.uid,
      },
    );
  }

  Future<Map<String, dynamic>> toggleFollowUser({
    required String portrait,
    required bool follow,
  }) {
    return _postOfficial(
      follow ? '/c/c/user/follow' : '/c/c/user/unfollow',
      {
        'portrait': portrait,
        'tbs': device.tbs,
        'authsid': 'null',
        'stoken': device.stoken,
        'from_type': '2',
        'in_live': '0',
      },
      clientVersion: '11.10.8.6',
      userAgent: 'bdtb for Android 11.10.8.6',
    );
  }

  Future<({List<Map<String, dynamic>> items, bool hasMore})> replyMe({
    int pn = 1,
  }) async {
    final json = await _postNewJson('/c/u/feed/replyme', {'pn': '$pn'});
    final page = json['page'] is Map ? json['page'] as Map : const {};
    return (
      items: (json['reply_list'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      hasMore: page['has_more'] == 1 || page['has_more'] == '1',
    );
  }

  Future<({List<Map<String, dynamic>> items, bool hasMore})> atMe({
    int pn = 1,
  }) async {
    final json = await _postNewJson('/c/u/feed/atme', {'pn': '$pn'});
    final page = json['page'] is Map ? json['page'] as Map : const {};
    return (
      items: (json['at_list'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      hasMore: page['has_more'] == 1 || page['has_more'] == '1',
    );
  }

  Future<({List<Map<String, dynamic>> items, bool hasMore})> followList({
    String uid = '',
    int pn = 1,
  }) async {
    final json = await _postOfficial('/c/u/follow/followList', {
      'pn': '$pn',
      if (uid.isNotEmpty) 'uid': uid,
    });
    return (
      items: (json['follow_list'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      hasMore: json['has_more'] == 1 || json['has_more'] == '1',
    );
  }

  Future<({List<Map<String, dynamic>> items, bool hasMore})> fansList({
    String uid = '',
    int pn = 1,
  }) async {
    final json = await _postOfficial('/c/u/fans/page', {
      'pn': '$pn',
      if (uid.isNotEmpty) 'uid': uid,
    });
    return (
      items: (json['user_list'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      hasMore: json['has_more'] == 1 ||
          json['has_more'] == '1' ||
          (json['page'] is Map && (json['page'] as Map)['has_more'] == 1),
    );
  }

  Future<Map<String, dynamic>> searchForum(String keyword) async {
    final word = keyword.trim();
    if (word.isEmpty) return {'exact': null, 'fuzzy': []};
    final json = await _getHybridJson(
      '/mo/q/search/forum',
      {'word': word},
      referer: _searchReferer(word),
    );
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final exact = data['exactMatch'];
    var fuzzy = data['fuzzyMatch'];
    if (fuzzy is Map) fuzzy = fuzzy.values.toList();
    final exactItem = exact is Map
        ? Map<String, dynamic>.from(exact)
        : exact is List && exact.isNotEmpty && exact.first is Map
            ? Map<String, dynamic>.from(exact.first as Map)
            : null;
    return {
      'exact': exactItem,
      'fuzzy': fuzzy is List
          ? fuzzy.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [],
    };
  }

  Future<({List<Map<String, dynamic>> items, bool hasMore})> searchThread({
    required String keyword,
    int pn = 1,
    int order = 2,
    int filter = 1,
    String forumName = '',
  }) async {
    final word = keyword.trim();
    if (word.isEmpty) {
      return (items: const <Map<String, dynamic>>[], hasMore: false);
    }
    final inForum = forumName.isNotEmpty;
    final json = await _getHybridJson(
      '/mo/q/search/thread',
      {
        'word': word,
        'pn': '$pn',
        'st': '$order',
        'tt': '$filter',
        'ct': inForum ? '2' : '1',
        if (!inForum) 'is_use_zonghe': '1',
        'cv': inForum ? '12.52.1.0' : '99.9.101',
        if (inForum) 'fname': forumName,
        if (inForum) 'rn': '20',
      },
      referer: inForum
          ? 'https://tieba.baidu.com/f?kw=${Uri.encodeComponent(forumName)}'
          : _searchReferer(word),
    );
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final list = (data['post_list'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return (
      items: list,
      hasMore: '${data['has_more'] ?? 0}' != '0' || list.length >= 10,
    );
  }

  Future<List<Map<String, dynamic>>> searchUser(String keyword) async {
    final word = keyword.trim();
    if (word.isEmpty) return [];
    final json = await _getHybridJson(
      '/mo/q/search/user',
      {'word': word},
      referer: _searchReferer(word),
    );
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final result = <Map<String, dynamic>>[];
    final exact = data['exactMatch'];
    if (exact is Map && '${exact['name'] ?? ''}'.isNotEmpty) {
      result.add(Map<String, dynamic>.from(exact));
    } else if (exact is List) {
      result.addAll(
        exact
            .whereType<Map>()
            .where((entry) => '${entry['name'] ?? ''}'.isNotEmpty)
            .map((entry) => Map<String, dynamic>.from(entry)),
      );
    }
    final fuzzy = data['fuzzyMatch'];
    if (fuzzy is List) {
      result.addAll(fuzzy.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    } else if (fuzzy is Map) {
      result.addAll(fuzzy.values.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    }
    return result;
  }

  Future<Map<String, dynamic>> getUserInfo(int uid) async {
    if (uid <= 0) throw TiebaApiException(-4, '缺少用户 id');
    final data = await _postProto(
      '/c/u/user/getuserinfo?cmd=303024&format=protobuf',
      encodeGetUserInfoRequest(
        device: device,
        uid: uid,
        bduss: device.bduss,
        stoken: device.stoken,
        zid: device.zid,
      ),
    );
    final user = decodeUserInfoData(data);
    if (user == null || tiebaInt(user['id']) == 0) {
      throw TiebaApiException(-6, '用户资料解析失败', data);
    }
    return user;
  }

  Future<List<Map<String, dynamic>>> personalized({
    int page = 1,
    int? loadType,
  }) async {
    final targetPage = page <= 0 ? 1 : page;
    final request = encodePersonalizedRequest(
      device: device,
      loadType: loadType ?? (targetPage > 1 ? 2 : 1),
      page: targetPage,
      bduss: device.bduss,
      stoken: device.stoken,
      tbs: device.tbs,
      zid: device.zid,
    );
    final data = await _postProto(
      '/c/f/excellent/personalized?cmd=309264',
      request,
    );
    return decodePersonalizedData(data);
  }

  Future<({
    List<({int id, String name, int discuss})> topics,
    List<Map<String, dynamic>> threads,
    List<({int id, String name, String code})> tabs,
  })> hotThreads({
    String tabCode = 'all',
    String tabId = '1',
  }) async {
    final request = encodeHotThreadListRequest(
      device: device,
      tabCode: tabCode,
      tabId: tabId,
      bduss: device.bduss,
      stoken: device.stoken,
    );
    final data = await _postProto(
      '/c/f/forum/hotThreadList?cmd=309661',
      request,
      version: tiebaVersionV11,
      signed: true,
    );
    return decodeHotThreadListData(data);
  }

  Future<({Map<String, dynamic>? user, String tbs})> userProfile({
    int uid = 0,
    String portrait = '',
  }) async {
    final selfUid = int.tryParse(device.uid) ?? 0;
    final targetUid = uid > 0 ? uid : selfUid;
    if (targetUid <= 0) throw TiebaApiException(-4, '缺少用户 id');
    final request = encodeProfileRequest(
      device: device,
      selfUid: selfUid,
      targetUid: targetUid,
      targetPortrait: portrait,
      page: 1,
      bduss: device.bduss,
      stoken: device.stoken,
      tbs: device.tbs,
      zid: device.zid,
    );
    final data = await _postProto(
      '/c/u/user/profile?cmd=303012&format=protobuf',
      request,
    );
    final result = decodeProfileData(data);
    if (result.user == null || tiebaInt(result.user!['id']) == 0) {
      throw TiebaApiException(-6, '用户主页解析失败', data);
    }
    return result;
  }

  Future<void> addPost({
    required int forumId,
    required String forumName,
    required int threadId,
    required String content,
    int quotePostId = 0,
    int subPostId = 0,
    int replyUid = 0,
  }) async {
    if (forumId <= 0 || threadId <= 0 || content.trim().isEmpty) {
      throw TiebaApiException(-4, '缺少回帖参数');
    }
    if (device.bduss.isEmpty) throw TiebaApiException(-5, '请先登录贴吧账号');
    if (device.tbs.isEmpty) throw TiebaApiException(-5, '登录状态缺少写权限（tbs），请重新登录');
    final request = encodeAddPostRequest(
      device: device,
      forumId: forumId,
      forumName: forumName,
      threadId: threadId,
      content: content,
      tbs: device.tbs,
      bduss: device.bduss,
      stoken: device.stoken,
      zid: device.zid,
      nameShow: device.nameShow,
      quotePostId: quotePostId,
      subPostId: subPostId,
      replyUid: replyUid,
    );
    await _postProto(
      '/c/c/post/add?cmd=309731&format=protobuf',
      request,
      signed: true,
      isPost: true,
    );
  }

  Future<void> addThread({
    required int forumId,
    required String forumName,
    required String title,
    required String content,
  }) async {
    if (forumId <= 0 || forumName.isEmpty || content.trim().isEmpty) {
      throw TiebaApiException(-4, '缺少发帖参数');
    }
    if (title.trim().isEmpty) throw TiebaApiException(-4, '标题不能为空');
    if (device.bduss.isEmpty) throw TiebaApiException(-5, '请先登录贴吧账号');
    if (device.tbs.isEmpty) throw TiebaApiException(-5, '登录状态缺少写权限（tbs），请重新登录');
    final request = encodeAddThreadRequest(
      device: device,
      forumId: forumId,
      forumName: forumName,
      title: title.trim(),
      content: content,
      tbs: device.tbs,
      bduss: device.bduss,
      stoken: device.stoken,
      zid: device.zid,
      nameShow: device.nameShow,
    );
    await _postProto(
      '/c/c/thread/add?cmd=309730&format=protobuf',
      request,
      signed: true,
      isPost: true,
    );
  }

  Future<({String picId, int width, int height})> uploadPicture({
    required Uint8List bytes,
    required String forumName,
    int width = 1080,
    int height = 1080,
    void Function(double progress)? onProgress,
  }) async {
    if (device.bduss.isEmpty) throw TiebaApiException(-5, '请先登录贴吧账号');
    if (bytes.isEmpty) throw TiebaApiException(-4, '图片内容为空');
    const chunkSize = 512000;
    final fileMd5 = bytesToHex(md5Bytes(bytes));
    final totalChunks = (bytes.length / chunkSize).ceil().clamp(1, 1 << 20);
    Map<String, dynamic> lastJson = const {};
    for (var i = 0; i < totalChunks; i += 1) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(start, bytes.length);
      final chunk = Uint8List.sublistView(bytes, start, end);
      final isFinish = i == totalChunks - 1;
      final fields = <String, String>{
        ..._baseParams(),
        '_client_version': tiebaVersionV12,
        'active_timestamp': '${device.activeTimestamp}',
        'android_id': device.base64AndroidIdValue,
        if (device.baiduId.isNotEmpty) 'baiduid': device.baiduId,
        'brand': device.brand,
        'cmode': '1',
        'cuid': device.newCuidValue,
        'cuid_galaxy2': device.newCuidValue,
        'cuid_gid': '',
        'c3_aid': device.c3Aid,
        'event_day': device.eventDay,
        'extra': '',
        'first_install_time': '${device.firstInstallTime}',
        'framework_ver': '3340042',
        'from': 'tieba',
        'is_teenager': '0',
        'last_update_time': '${device.lastUpdateTime}',
        'mac': '02:00:00:00:00:00',
        if (device.sampleId.isNotEmpty) 'sample_id': device.sampleId,
        'start_scheme': '',
        'start_type': '1',
        'oaid': device.oaidJson,
        'alt': 'json',
        'chunkNo': '${i + 1}',
        'forum_name': forumName,
        'groupId': '1',
        'height': '${height > 0 ? height : 1080}',
        'width': '${width > 0 ? width : 1080}',
        'isFinish': isFinish ? '1' : '0',
        'is_bjh': '0',
        'pic_water_type': '0',
        'resourceId': '$fileMd5$chunkSize',
        'saveOrigin': '0',
        'size': '${bytes.length}',
        'small_flow_fname': forumName,
      };
      final body = _buildMultipart(
        fields: fields,
        signed: true,
        fileBytes: chunk,
        fileField: 'chunk',
      );
      final response = await _sendBinary(
        url: '$_officialHost/c/s/uploadPicture',
        headers: {
          'User-Agent': 'bdtb for Android $tiebaVersionV12',
          'cookie': device.baiduId.isNotEmpty
              ? 'ka=open;BAIDUID=${device.baiduId}'
              : 'ka=open',
          'Content-Type': 'multipart/form-data; boundary=$_tiebaBoundary',
        },
        body: body,
      );
      if (response.status >= 400) {
        throw TiebaApiException(response.status, '图片上传 HTTP ${response.status}');
      }
      if (response.bytes.isEmpty) {
        throw TiebaApiException(-2, '图片上传返回空响应');
      }
      Map<String, dynamic> json;
      try {
        final decoded = jsonDecode(utf8.decode(response.bytes));
        if (decoded is! Map) throw const FormatException();
        json = Map<String, dynamic>.from(decoded);
      } catch (_) {
        throw TiebaApiException(-3, '图片上传返回格式异常');
      }
      final code = tiebaInt(json['error_code'] ?? json['errno'] ?? json['no']);
      if (code != 0) {
        var message = '${json['error_msg'] ?? json['errmsg'] ?? ''}';
        final error = json['error'];
        if (message.isEmpty && error is String) message = error;
        if (message.isEmpty && error is Map) {
          message = '${error['errmsg'] ?? error['usermsg'] ?? ''}';
        }
        throw TiebaApiException(code, message.isEmpty ? '图片上传失败' : message, json);
      }
      lastJson = json;
      onProgress?.call((i + 1) / totalChunks);
    }
    final info = lastJson['info'] is Map
        ? Map<String, dynamic>.from(lastJson['info'] as Map)
        : lastJson;
    final origin = info['origin_pic'] is Map
        ? Map<String, dynamic>.from(info['origin_pic'] as Map)
        : info;
    final picId = '${info['pic_id_encode'] ?? info['pic_id'] ?? ''}';
    if (picId.isEmpty) {
      throw TiebaApiException(-6, '图片上传未返回 pic_id', lastJson);
    }
    return (
      picId: picId,
      width: tiebaInt(origin['width']) > 0 ? tiebaInt(origin['width']) : width,
      height: tiebaInt(origin['height']) > 0 ? tiebaInt(origin['height']) : height,
    );
  }

  Future<Map<String, dynamic>> webSessionInfo({
    required String bduss,
    String stoken = '',
    String baiduId = '',
  }) async {
    final cookies = <String>['BDUSS=$bduss'];
    if (stoken.isNotEmpty) cookies.add('STOKEN=$stoken');
    if (baiduId.isNotEmpty) cookies.add('BAIDUID=$baiduId');
    final response = await _send(
      url: 'https://tieba.baidu.com/mo/q/newmoindex',
      method: 'GET',
      headers: {
        'User-Agent': device.webUserAgent('tieba/$_clientVersion'),
        'Referer': 'https://tieba.baidu.com/',
        'Accept': 'application/json, text/plain, */*',
        'cookie': cookies.join('; '),
      },
    );
    if (response.status >= 400) {
      throw TiebaApiException(response.status, '贴吧接口 HTTP ${response.status}');
    }
    final decoded = jsonDecode(response.text);
    if (decoded is! Map) {
      throw TiebaApiException(-3, '贴吧登录状态解析失败');
    }
    final json = Map<String, dynamic>.from(decoded);
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final loginFlag = data['is_login'] ?? data['isLogin'] ?? json['is_login'];
    final loggedIn = loginFlag == true || '$loginFlag'.toLowerCase() == 'true' || '$loginFlag' == '1';
    if (!loggedIn) {
      throw TiebaApiException(-6, '百度登录状态无效，请重新登录');
    }
    final user = data['user_info'] is Map
        ? Map<String, dynamic>.from(data['user_info'] as Map)
        : data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : data;
    final uid = '${user['id'] ?? user['user_id'] ?? data['user_id'] ?? data['uid'] ?? ''}';
    if (uid.isEmpty || uid == '0') {
      throw TiebaApiException(-6, '登录状态缺少用户信息');
    }
    return {
      'uid': uid,
      'name': '${user['name'] ?? user['user_name'] ?? ''}',
      'nameShow': '${user['name_show'] ?? user['show_nickname'] ?? user['name'] ?? ''}',
      'portrait': '${user['portrait'] ?? ''}',
      'tbs': '${data['tbs'] ?? json['tbs'] ?? ''}',
      'fansNum': tiebaInt(user['fans_num']),
      'concernNum': tiebaInt(user['concern_num']),
      'postNum': tiebaInt(user['post_num']),
    };
  }

  String _searchReferer(String word) =>
      'https://tieba.baidu.com/mo/q/searchpage?word=${Uri.encodeComponent(word)}';
}