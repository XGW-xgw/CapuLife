import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../utils/cap_date.dart';

const _systems = <String, Map<String, String>>{
  'longquan': {
    'label': '龙泉校区',
    'short': '龙泉',
    'base': 'https://axf.cap.edu.cn:8082/electric',
  },
  'xindu': {
    'label': '新都校区',
    'short': '新都',
    'base': 'http://cdhkzyjsdx.acrel-eem.com/prepayment',
    'projectId': '1',
  },
};

class ElectricityRoom {
  ElectricityRoom({
    required this.id,
    required this.system,
    required this.campusLabel,
    required this.building,
    required this.floor,
    required this.roomName,
    required this.dormName,
    required this.payload,
  });

  final String id;
  final String system;
  final String campusLabel;
  final String building;
  final String floor;
  final String roomName;
  final String dormName;
  final Map<String, dynamic> payload;
}

class ElectricityBalance {
  ElectricityBalance({
    required this.ok,
    this.system = '',
    this.val,
    this.unit = '',
    this.dayUse,
    this.updatedAt,
    this.trend,
    this.trendError,
    this.error,
  });

  final bool ok;
  final String system;
  final dynamic val;
  final String unit;
  final dynamic dayUse;
  final int? updatedAt;
  final Map<String, dynamic>? trend;
  final Map<String, dynamic>? trendError;
  final Map<String, dynamic>? error;
}

class ElectricityProgress {
  const ElectricityProgress({
    required this.type,
    this.system = '',
    this.phase = '',
    this.loaded = 0,
    this.total = 0,
    this.count = 0,
  });

  final String type;
  final String system;
  final String phase;
  final int loaded;
  final int total;
  final int count;
}

class ElectricityException implements Exception {
  ElectricityException(this.code, this.message, {this.errors});

  final String code;
  final String message;
  final Map<String, String>? errors;

  @override
  String toString() => message;
}

class ElectricityService {
  ElectricityService._();

  static final ElectricityService instance = ElectricityService._();

  static const listTimeout = Duration(seconds: 30);
  static const balanceTimeout = Duration(seconds: 15);
  static const cacheTtl = Duration(minutes: 5);

  final Map<String, List<ElectricityRoom>> _cache = {};
  final Map<String, DateTime> _cacheAt = {};
  Future<List<ElectricityRoom>>? _inflight;
  List<Map<String, String>> _lastListErrors = [];

  List<Map<String, String>> get lastErrors => _lastListErrors;

  Future<List<ElectricityRoom>> listRooms({
    bool force = false,
    void Function(ElectricityProgress event)? onProgress,
  }) {
    if (_inflight != null) return _inflight!;
    final now = DateTime.now();
    final stale = <String>[
      for (final system in _systems.keys)
        if (force ||
            !_cache.containsKey(system) ||
            _cacheAt[system] == null ||
            now.difference(_cacheAt[system]!).compareTo(cacheTtl) > 0)
          system,
    ];
    if (stale.isEmpty) {
      final cached = _collectRooms();
      onProgress?.call(
        ElectricityProgress(type: 'cache', count: cached.length),
      );
      return Future.value(cached);
    }
    final future = _loadSystems(stale, onProgress);
    _inflight = future;
    return future.whenComplete(() => _inflight = null);
  }

  Future<List<ElectricityRoom>> _loadSystems(
    List<String> systems,
    void Function(ElectricityProgress event)? onProgress,
  ) async {
    final errors = <String, ElectricityException>{};
    for (final system in systems) {
      onProgress?.call(
        ElectricityProgress(type: 'system-start', system: system),
      );
      try {
        final rooms = system == 'longquan'
            ? await _loadLongquanRooms(onProgress)
            : await _loadXinduRooms(onProgress);
        _cache[system] = rooms;
        _cacheAt[system] = DateTime.now();
      } catch (error) {
        final exception = error is ElectricityException
            ? error
            : ElectricityException('UNKNOWN', '$error');
        errors[system] = exception;
      }
      onProgress?.call(
        ElectricityProgress(type: 'system-done', system: system),
      );
    }
    _lastListErrors = [
      for (final entry in errors.entries)
        {'system': entry.key, 'code': entry.value.code, 'message': entry.value.message},
    ];
    final rooms = _collectRooms();
    if (rooms.isEmpty) {
      final detail = errors.values.map((e) => e.message).join('；');
      throw ElectricityException(
        'LIST_FAILED',
        detail.isEmpty ? '两个电费系统都没有返回寝室数据' : detail,
        errors: {for (final e in errors.entries) e.key: e.value.message},
      );
    }
    return rooms;
  }

  List<ElectricityRoom> _collectRooms() {
    final list = <ElectricityRoom>[];
    for (final system in _systems.keys) {
      list.addAll(_cache[system] ?? const []);
    }
    list.sort(compareRooms);
    return list;
  }

  void clearCache() {
    _cache.clear();
    _cacheAt.clear();
    _lastListErrors = [];
  }

  Future<List<ElectricityRoom>> _loadLongquanRooms(
    void Function(ElectricityProgress event)? onProgress,
  ) async {
    final errors = <Map<String, String>>[];
    final rooms = <ElectricityRoom>[];
    final areas = await _requestLongquanOptions('/getData/getAreas', const {}, '区域');
    if (areas.isEmpty) {
      throw ElectricityException('API', '未获取到电费区域');
    }
    for (final area in areas) {
      List<Map<String, String>> architectures;
      try {
        architectures = await _requestLongquanOptions(
          '/getData/getArchitectures',
          {'areaId': area['key']!},
          '楼栋',
        );
      } catch (error) {
        errors.add({'code': 'PARSE', 'message': '$error'});
        continue;
      }
      for (final architecture in architectures) {
        List<Map<String, String>> floors;
        try {
          floors = await _requestLongquanOptions(
            '/getData/getFloors',
            {'areaId': area['key']!, 'architectureId': architecture['key']!},
            '楼层',
          );
        } catch (error) {
          errors.add({'code': 'PARSE', 'message': '$error'});
          continue;
        }
        onProgress?.call(
          ElectricityProgress(
            type: 'progress',
            system: 'longquan',
            phase: 'floors',
            loaded: floors.length,
            total: floors.length,
          ),
        );
        for (final floor in floors) {
          List<Map<String, String>> options;
          try {
            options = await _requestLongquanOptions(
              '/getData/getRooms',
              {
                'areaId': area['key']!,
                'architectureId': architecture['key']!,
                'floorId': floor['key']!,
              },
              '寝室',
            );
          } catch (error) {
            errors.add({'code': 'PARSE', 'message': '$error'});
            continue;
          }
          final building = architecture['name']!;
          final floorNameRaw = floor['name']!;
          final floorName = floorNameRaw.startsWith(building)
              ? floorNameRaw.substring(building.length).trim()
              : floorNameRaw;
          for (final option in options) {
            final name = option['name'] ?? '';
            if (name.isEmpty) continue;
            final payload = <String, dynamic>{
              'system': 'longquan',
              'areaId': area['key'],
              'areaName': area['name'],
              'architectureId': architecture['key'],
              'architectureName': building,
              'floorId': floor['key'],
              'floorName': floorName,
              'roomId': option['key'],
            };
            rooms.add(
              _makeRoom(
                system: 'longquan',
                building: building,
                floor: floorName,
                roomName: name,
                payload: payload,
              ),
            );
          }
          onProgress?.call(
            ElectricityProgress(
              type: 'progress',
              system: 'longquan',
              phase: 'rooms',
              loaded: rooms.length,
              total: rooms.length,
            ),
          );
        }
      }
    }
    if (rooms.isEmpty) {
      throw ElectricityException(
        'LIST_FAILED',
        errors.isEmpty ? '未获取到寝室列表' : errors.first['message']!,
        errors: {
          for (var i = 0; i < errors.length; i += 1) 'longquan-$i': errors[i]['message']!,
        },
      );
    }
    return rooms;
  }

  Future<List<ElectricityRoom>> _loadXinduRooms(
    void Function(ElectricityProgress event)? onProgress,
  ) async {
    final envelope = await _requestXinduEnvelope(
      '/app/searchAllRoomNo',
      json: {
        'roomNo': '楼',
        'projectId': _systems['xindu']!['projectId'],
      },
      label: '寝室列表',
      timeout: listTimeout,
    );
    final rawList = envelope['data'] is List ? envelope['data'] as List : const [];
    if (rawList.isEmpty) {
      throw ElectricityException('API', '未获取到新都校区寝室列表');
    }
    final rooms = <ElectricityRoom>[];
    final seen = <String>{};
    for (var i = 0; i < rawList.length; i += 1) {
      final raw = rawList[i];
      if (raw is! Map) continue;
      final room = _normalizeXinduRoom(raw);
      if (room == null || !seen.add(room.id)) continue;
      rooms.add(room);
      if (i % 200 == 0) {
        onProgress?.call(
          ElectricityProgress(
            type: 'progress',
            system: 'xindu',
            phase: 'rooms',
            loaded: i + 1,
            total: rawList.length,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (rooms.isEmpty) {
      throw ElectricityException('API', '未获取到新都校区寝室列表');
    }
    return rooms;
  }

  ElectricityRoom _makeRoom({
    required String system,
    required String building,
    required String floor,
    required String roomName,
    required Map<String, dynamic> payload,
  }) {
    final id = system == 'xindu'
        ? 'xindu:${payload['roomId']}'
        : 'longquan:${payload['areaId']}:${payload['architectureId']}:${payload['floorId']}:${payload['roomId']}';
    return ElectricityRoom(
      id: id,
      system: system,
      campusLabel: _systems[system]!['label']!,
      building: building.trim(),
      floor: floor.trim(),
      roomName: roomName.trim(),
      dormName: [building, floor, roomName]
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(' · '),
      payload: payload,
    );
  }

  ElectricityRoom? _normalizeXinduRoom(Map raw) {
    final id = '${raw['id'] ?? ''}'.trim();
    final roomNo = '${raw['roomNo'] ?? ''}'.trim();
    if (id.isEmpty || roomNo.isEmpty) return null;
    final topName = '${raw['topName'] ?? ''}'.trim();
    final split = topName.indexOf('_');
    final building = split < 0 ? topName : topName.substring(0, split).trim();
    final floor = split < 0 ? '' : topName.substring(split + 1).trim();
    final buildingName = building.isEmpty ? '其他' : building;
    final floorName = floor.isEmpty ? '全部' : floor;
    final roomName = building.isNotEmpty && roomNo.startsWith(building)
        ? roomNo.substring(building.length).trim()
        : roomNo;
    final payload = <String, dynamic>{
      'system': 'xindu',
      'roomId': id,
      'roomNo': roomNo,
      'projectId': '${raw['projectId'] ?? _systems['xindu']!['projectId']}',
      'remark': raw['remark'] is String ? raw['remark'] : '',
    };
    return _makeRoom(
      system: 'xindu',
      building: buildingName,
      floor: floorName,
      roomName: roomName.isEmpty ? roomNo : roomName,
      payload: payload,
    );
  }

  List<ElectricityRoom> searchRooms(String query, List<Map<String, dynamic>> bindings) {
    final tokens = query.trim().toLowerCase().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (tokens.isEmpty) return [];
    bool matches(dynamic source) {
      if (source is! Map) return false;
      final haystack = [
        source['campusLabel'],
        source['system'] == 'xindu' ? '新都' : '龙泉',
        source['building'],
        source['floor'],
        source['roomName'],
        source['dormName'],
        source['roomNo'],
        source['id'],
      ].map((e) => '${e ?? ''}'.toLowerCase()).where((e) => e.isNotEmpty).join(' ');
      return tokens.every(haystack.contains);
    }

    final matched = <ElectricityRoom>[];
    final seen = <String>{};
    for (final room in _collectRooms()) {
      if (!matches({
        'campusLabel': room.campusLabel,
        'system': room.system,
        'building': room.building,
        'floor': room.floor,
        'roomName': room.roomName,
        'dormName': room.dormName,
        'id': room.id,
      })) {
        continue;
      }
      matched.add(room);
      seen.add(room.id);
    }
    for (final binding in bindings) {
      final id = '${binding['id'] ?? ''}';
      if (id.isEmpty || seen.contains(id) || !matches(binding)) continue;
      matched.add(_roomFromBinding(binding));
    }
    matched.sort(compareRooms);
    return matched;
  }

  ElectricityRoom _roomFromBinding(Map<String, dynamic> binding) {
    final system = '${binding['system'] ?? ''}';
    final payload = <String, dynamic>{
      'system': system,
      if (system == 'xindu') ...{
        'roomId': binding['roomId'],
        'roomNo': binding['roomNo'],
        'projectId': binding['projectId'],
        'remark': binding['remark'],
      } else ...{
        'areaId': binding['areaId'],
        'architectureId': binding['architectureId'],
        'floorId': binding['floorId'],
        'roomId': binding['roomId'],
      },
    };
    return ElectricityRoom(
      id: '${binding['id']}',
      system: system,
      campusLabel: '${binding['campusLabel'] ?? _systems[system]?['label'] ?? ''}',
      building: '${binding['building'] ?? ''}',
      floor: '${binding['floor'] ?? ''}',
      roomName: '${binding['roomName'] ?? ''}',
      dormName: '${binding['dormName'] ?? ''}',
      payload: payload,
    );
  }

  Map<String, dynamic>? createBinding(ElectricityRoom room) {
    final payload = room.payload;
    final system = room.system;
    final binding = <String, dynamic>{
      'id': room.id,
      'system': system,
      'campusLabel': room.campusLabel,
      'building': room.building,
      'floor': room.floor,
      'roomName': room.roomName,
      'dormName': room.dormName,
    };
    if (system == 'xindu') {
      binding.addAll({
        'roomId': '${payload['roomId'] ?? ''}',
        'roomNo': '${payload['roomNo'] ?? room.roomName}',
        'projectId': '${payload['projectId'] ?? _systems['xindu']!['projectId']}',
        'remark': '${payload['remark'] ?? ''}',
      });
      if ('${binding['remark']}'.isEmpty) return null;
      return binding;
    }
    binding.addAll({
      'areaId': '${payload['areaId'] ?? ''}',
      'architectureId': '${payload['architectureId'] ?? ''}',
      'floorId': '${payload['floorId'] ?? ''}',
      'roomId': '${payload['roomId'] ?? ''}',
    });
    if (['areaId', 'architectureId', 'floorId', 'roomId']
        .any((key) => '${binding[key]}'.isEmpty)) {
      return null;
    }
    return binding;
  }

  Future<ElectricityBalance> queryBalance(
    Map<String, dynamic> binding, {
    bool includeTrend = true,
  }) async {
    final system = '${binding['system'] ?? ''}';
    try {
      if (system == 'xindu') {
        return await _queryXinduBalance(binding, includeTrend: includeTrend);
      }
      if (system == 'longquan') {
        return await _queryLongquanBalance(binding);
      }
      throw ElectricityException('INVALID_BINDING', '未绑定寝室');
    } catch (error) {
      final exception = error is ElectricityException
          ? error
          : ElectricityException('UNKNOWN', '$error');
      return ElectricityBalance(
        ok: false,
        system: system,
        unit: system == 'xindu' ? '元' : '度',
        error: {'code': exception.code, 'message': exception.message},
      );
    }
  }

  Future<ElectricityBalance> _queryXinduBalance(
    Map<String, dynamic> binding, {
    required bool includeTrend,
  }) async {
    final remark = '${binding['remark'] ?? ''}';
    if (remark.isEmpty) {
      throw ElectricityException('INVALID_BINDING', '寝室信息不完整，请重新选择寝室');
    }
    final tokenEnvelope = await _requestXinduEnvelope(
      '/app/saveToken',
      json: {'param': remark},
      label: '访问令牌',
    );
    final tokenData = tokenEnvelope['data'];
    final token = tokenData is String
        ? tokenData.trim()
        : tokenData is Map && tokenData['token'] is String
        ? '${tokenData['token']}'.trim()
        : '';
    if (token.isEmpty) {
      throw ElectricityException('API', '未获取到访问令牌，请稍后再试');
    }
    final meterEnvelope = await _requestXinduEnvelope(
      '/app/MainInfoSushe',
      method: 'GET',
      header: {'token': token},
      label: '寝室余额',
    );
    final data = meterEnvelope['data'];
    final meters = data is List
        ? data
        : data is Map
        ? [data]
        : const [];
    if (meters.isEmpty) {
      throw ElectricityException('NO_METER', '未查询到该寝室的电表数据');
    }
    Map meter = meters.first as Map;
    for (final item in meters) {
      if (item is Map && '${item['meterType']}' == '1') {
        meter = item;
        break;
      }
    }
    final money = double.tryParse('${meter['money'] ?? ''}');
    if (money == null) {
      throw ElectricityException('PARSE', '余额字段异常');
    }
    final dayUse = double.tryParse('${meter['dayUse'] ?? ''}');
    Map<String, dynamic>? trend;
    Map<String, dynamic>? trendError;
    if (includeTrend) {
      try {
        trend = await _queryXinduTrend(token, meter);
      } catch (error) {
        final exception = error is ElectricityException
            ? error
            : ElectricityException('UNKNOWN', '$error');
        trendError = {'code': exception.code, 'message': exception.message};
      }
    }
    return ElectricityBalance(
      ok: true,
      system: 'xindu',
      val: money.toStringAsFixed(2),
      unit: '元',
      dayUse: dayUse,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      trend: trend,
      trendError: trendError,
    );
  }

  Future<Map<String, dynamic>> _queryXinduTrend(
    String token,
    Map meter,
  ) async {
    final meterId = meter['meterID'] ?? meter['meterId'] ?? meter['id'];
    final meterType = meter['meterType'] ?? meter['type'];
    if (meterId == null) {
      throw ElectricityException('NO_METER', '电表信息不完整，无法读取趋势');
    }
    final now = DateTime.now();
    final year = now.year;
    final monthText = pad2(now.month);
    final todayKey = '${now.year}-$monthText-${pad2(now.day)}';
    final envelope = await _requestXinduEnvelope(
      '/app/EnergyReportChart',
      method: 'POST',
      header: {'token': token, 'Content-Type': 'application/json'},
      json: {
        'ntype': 2,
        'datetime': todayKey,
        'meterid': '$meterId',
        'type': '${meterType ?? '1'}',
      },
      label: '用电趋势',
    );
    final data = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : <String, dynamic>{};
    final line = data['line'] is List ? data['line'] as List : const [];
    final days = <Map<String, dynamic>>[];
    for (final item in line) {
      if (item is! Map) continue;
      final day = int.tryParse('${item['createDate'] ?? ''}');
      final value = double.tryParse('${item['pv'] ?? ''}');
      if (day == null || day < 1 || day > 31 || value == null) continue;
      final date = '$year-$monthText-${pad2(day)}';
      if (date.compareTo(todayKey) > 0) continue;
      days.add({'date': date, 'day': day, 'value': math.max(0.0, value)});
    }
    days.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    if (days.isEmpty) {
      throw ElectricityException('PARSE', '学校暂未返回用电趋势数据');
    }
    final dayUse = double.tryParse('${meter['dayUse'] ?? ''}');
    if (dayUse != null && dayUse >= 0) {
      final today = days.last;
      if (today['date'] == todayKey &&
          (today['value'] as double) < 0.005 &&
          dayUse > 0.005) {
        today['value'] = dayUse;
      }
    }
    final serverTotal = double.tryParse('${data['powerUse'] ?? ''}');
    final sum = days.fold<double>(0, (total, item) => total + (item['value'] as double));
    return {
      'source': 'xindu',
      'unit': '度',
      'monthKey': '$year-$monthText',
      'days': days,
      'monthTotal': serverTotal ?? sum,
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'sourceLabel': '学校电表日数据',
    };
  }

  Future<ElectricityBalance> _queryLongquanBalance(
    Map<String, dynamic> binding,
  ) async {
    for (final key in ['areaId', 'architectureId', 'floorId', 'roomId']) {
      if ('${binding[key] ?? ''}'.isEmpty) {
        throw ElectricityException('INVALID_BINDING', '寝室信息不完整，请重新选择寝室');
      }
    }
    final response = await _requestJson(
      system: 'longquan',
      path: '/getData/getReserveAM',
      method: 'POST',
      form: {
        'areaId': '${binding['areaId']}',
        'architectureId': '${binding['architectureId']}',
        'floorId': '${binding['floorId']}',
        'roomId': '${binding['roomId']}',
      },
      timeout: balanceTimeout,
    );
    final envelope = _parseLongquanEnvelope(response, '余额');
    final data = envelope['data'];
    if (data is! Map) {
      throw ElectricityException('API', '未查询到该寝室的电表数据');
    }
    if (data['resultInfo'] is Map &&
        '${(data['resultInfo'] as Map)['result']}' == '3') {
      throw ElectricityException('ORDER_PROCESSING', '有订单正在处理，请稍后再查');
    }
    final remainPower = '${data['remainPower'] ?? ''}'.trim();
    if (remainPower.isEmpty) {
      throw ElectricityException('NO_READING', '电表暂无读数');
    }
    final remainName = '${data['remainName'] ?? ''}'.trim();
    return ElectricityBalance(
      ok: true,
      system: 'longquan',
      val: remainPower,
      unit: remainName.toLowerCase() == 'yuan' ? '元' : '度',
      dayUse: null,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<Map<String, String>>> _requestLongquanOptions(
    String path,
    Map<String, String> form,
    String label,
  ) async {
    final response = await _requestJson(
      system: 'longquan',
      path: path,
      method: 'POST',
      form: form,
      timeout: listTimeout,
    );
    final envelope = _parseLongquanEnvelope(response, label);
    final data = envelope['data'];
    final list = data is List ? data : const [];
    final seen = <String>{};
    final options = <Map<String, String>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final key = '${item['key'] ?? ''}'.trim();
      final name = '${item['value'] ?? ''}'.trim();
      if (key.isEmpty || name.isEmpty || !seen.add(key)) continue;
      options.add({'key': key, 'name': name});
    }
    return options;
  }

  Map<String, dynamic> _parseLongquanEnvelope(
    Map<String, dynamic> response,
    String label,
  ) {
    final respCode = '${response['respCode'] ?? ''}';
    if (respCode.isEmpty) {
      throw ElectricityException('PARSE', '获取$label数据异常');
    }
    if (respCode != '00') {
      final message = '${response['respDesc'] ?? response['respMsg'] ?? ''}'.trim();
      throw ElectricityException('API', message.isEmpty ? '获取$label失败，请稍后再试' : message);
    }
    return response;
  }

  Future<Map<String, dynamic>> _requestXinduEnvelope(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? json,
    Map<String, String>? header,
    required String label,
    Duration? timeout,
  }) async {
    final response = await _requestJson(
      system: 'xindu',
      path: path,
      method: method,
      json: json,
      header: header,
      timeout: timeout ?? balanceTimeout,
    );
    final success = response['success'];
    if (!(success == 1 || success == '1' || success == true)) {
      final message = '${response['errorMsg'] ?? ''}'.trim();
      throw ElectricityException('API', message.isEmpty ? '获取$label失败，请稍后再试' : message);
    }
    return response;
  }

  Future<Map<String, dynamic>> _requestJson({
    required String system,
    required String path,
    required String method,
    Map<String, String>? form,
    Map<String, dynamic>? json,
    Map<String, String>? header,
    required Duration timeout,
  }) async {
    final meta = _systems[system]!;
    final uri = Uri.parse('${meta['base']}$path');
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout;
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (header != null) {
        header.forEach(request.headers.set);
      }
      if (form != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(
          form.entries
              .map(
                (e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
              )
              .join('&'),
        );
      } else if (json != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(json));
      }
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ElectricityException(
          'HTTP',
          '学校电费系统返回 HTTP ${response.statusCode}',
        );
      }
      if (body.trim().isEmpty) {
        throw ElectricityException('PARSE', '学校电费系统返回数据异常');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw ElectricityException('PARSE', '学校电费系统返回数据异常');
      }
      return Map<String, dynamic>.from(decoded);
    } on ElectricityException {
      rethrow;
    } on TimeoutException {
      throw ElectricityException('TIMEOUT', '连接学校电费系统超时，请稍后再试');
    } on SocketException {
      throw ElectricityException('NETWORK', '网络连接失败，请检查网络后重试');
    } on FormatException {
      throw ElectricityException('PARSE', '学校电费系统返回数据异常');
    } catch (error) {
      throw ElectricityException('UNKNOWN', '$error');
    } finally {
      client.close(force: true);
    }
  }
}

int _floorRank(String value) {
  final text = value.trim();
  if (text.isEmpty) return 0;
  final negative =
      text.startsWith('负') || text.startsWith('地下') || text.startsWith('-');
  final match = RegExp(r'\d+').firstMatch(text);
  final number = match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  return negative ? -number : number;
}

int _naturalCompare(String left, String right) {
  final a = left.trim().toLowerCase();
  final b = right.trim().toLowerCase();
  if (a == b) return 0;
  final tokenPattern = RegExp(r'\d+|[^\d]+');
  final at = tokenPattern.allMatches(a).map((m) => m.group(0)!).toList();
  final bt = tokenPattern.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < math.min(at.length, bt.length); i += 1) {
    final x = at[i];
    final y = bt[i];
    final xNum = int.tryParse(x);
    final yNum = int.tryParse(y);
    if (xNum != null && yNum != null) {
      final diff = xNum.compareTo(yNum);
      if (diff != 0) return diff;
    } else {
      final diff = x.compareTo(y);
      if (diff != 0) return diff;
    }
  }
  return at.length.compareTo(bt.length);
}

int compareRooms(ElectricityRoom left, ElectricityRoom right) {
  var diff = _naturalCompare(left.building, right.building);
  if (diff != 0) return diff;
  diff = _floorRank(left.floor).compareTo(_floorRank(right.floor));
  if (diff != 0) return diff;
  diff = _naturalCompare(left.floor, right.floor);
  if (diff != 0) return diff;
  diff = _naturalCompare(left.roomName, right.roomName);
  if (diff != 0) return diff;
  return left.system.compareTo(right.system);
}
