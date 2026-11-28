import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cap_course.dart';
import '../data/cap_store.dart';
import '../services/cap_reminders.dart';
import '../theme.dart';
import '../utils/webview_extract.dart';
import '../widgets/app_header.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_page.dart';
import '../widgets/cap_toast.dart';
import '../widgets/cap_webview.dart';

class AcademicSyncPage extends StatefulWidget {
  const AcademicSyncPage({super.key});

  @override
  State<AcademicSyncPage> createState() => _AcademicSyncPageState();
}

class _AcademicSyncPageState extends State<AcademicSyncPage> {
  static const _webvpnUrl = 'https://webvpn.cap.edu.cn';
  static bool _tutorialShown = false;
  static final Map<String, String> _scriptCache = {};

  final GlobalKey<CapWebViewState> _webKey = GlobalKey<CapWebViewState>();
  bool _extracting = false;
  bool _webLoaded = false;
  int _progress = 0;
  String _chunkId = '';
  int _chunkTotal = 0;
  final Map<int, String> _chunkParts = {};
  Timer? _extractTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_tutorialShown) {
        _tutorialShown = true;
        _showTutorial(forced: true);
      }
    });
  }

  @override
  void dispose() {
    _extractTimer?.cancel();
    super.dispose();
  }

  String get _pageTitle => '同步课表';
  String get _pageSubtitle => '登录 → 教务 → 提取 → 运行 → 课表';

  List<String> get _steps => const ['登录', '教务', '提取', '运行', '我的课表'];

  void _showTutorial({bool forced = false}) {
    const content =
        '1. 登录 WebVPN\n2. 进入教务系统\n3. 点「提取」\n4. 点「运行」\n5. 打开「我的课表」确认课程后导入\n\n提示：如果还在运行页或门户页，请先进入「我的课表」再点提取。';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '同步课表教程',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.65,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '开始同步',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    final web = _webKey.currentState;
    if (web == null) return;
    await web.reload();
  }

  Future<String> _loadScript() async {
    const name = 'schedule_extract';
    final cached = _scriptCache[name];
    if (cached != null) return cached;
    final text = await rootBundle.loadString('assets/js/$name.js');
    _scriptCache[name] = text;
    return text;
  }

  Future<void> _extract() async {
    if (_extracting) return;
    final web = _webKey.currentState;
    if (web == null || !_webLoaded) {
      showCapToast(context, '网页还没有准备好');
      return;
    }
    setState(() {
      _extracting = true;
      _chunkId = '';
      _chunkTotal = 0;
      _chunkParts.clear();
    });
    _extractTimer?.cancel();
    _extractTimer = Timer(
      Duration(seconds: 12),
      () {
        if (!mounted || !_extracting) return;
        setState(() => _extracting = false);
        _showTimeoutDialog();
      },
    );
    try {
      final script = await _loadScript();
      if (!mounted) return;
      const functionName = 'scheduleExtract';
      await web.evalJs(titleBridgeHook);
      final injected = '(function(){\n$script\n$functionName();\n})();';
      final result = await web.evalJs(injected);
      if (result == null && mounted) {
        _finishExtract();
        showCapToast(context, '注入提取脚本失败');
      }
    } catch (_) {
      _finishExtract();
      if (mounted) showCapToast(context, '注入提取脚本失败');
    }
  }

  void _finishExtract() {
    _extractTimer?.cancel();
    _extractTimer = null;
    if (!mounted) return;
    setState(() => _extracting = false);
  }

  void _showTimeoutDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '提取超时',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '请确认已经进入教务系统的课表页面，再点一次提取。',
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _handleTitle(String title) {
    if (title.startsWith('__CAP_CHUNK__:')) {
      _handleChunk(title);
      return;
    }
    if (title.startsWith('__CAP_SCHEDULE__:')) {
      final rest = title.substring('__CAP_SCHEDULE__:'.length);
      final index = rest.indexOf(':');
      if (index < 0) return;
      _handleExtractText(rest.substring(index + 1));
    }
  }

  void _handleChunk(String title) {
    final rest = title.substring('__CAP_CHUNK__:'.length);
    final p1 = rest.indexOf(':');
    final p2 = p1 >= 0 ? rest.indexOf(':', p1 + 1) : -1;
    final p3 = p2 >= 0 ? rest.indexOf(':', p2 + 1) : -1;
    if (p1 < 0 || p2 < 0 || p3 < 0) return;
    final id = rest.substring(0, p1);
    final index = int.tryParse(rest.substring(p1 + 1, p2)) ?? -1;
    final total = int.tryParse(rest.substring(p2 + 1, p3)) ?? -1;
    final part = rest.substring(p3 + 1);
    if (id.isEmpty || index < 0 || total <= 0 || index >= total) return;
    if (_chunkId != id) {
      _chunkId = id;
      _chunkTotal = total;
      _chunkParts.clear();
    }
    _chunkParts[index] = part;
    if (_chunkParts.length < _chunkTotal) return;
    final joined = List<String>.generate(
      _chunkTotal,
      (i) => _chunkParts[i] ?? '',
    ).join();
    _chunkId = '';
    _chunkTotal = 0;
    _chunkParts.clear();
    String text;
    try {
      text = utf8.decode(base64Decode(joined), allowMalformed: true);
    } catch (_) {
      text = '';
    }
    if (text.isEmpty) {
      _finishExtract();
      if (mounted) {
        showCapToast(context, '数据解析异常');
      }
      return;
    }
    _handleExtractText(text);
  }

  void _handleExtractText(String text) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      data = null;
    }
    if (data == null) {
      _finishExtract();
      if (mounted) showCapToast(context, '数据解析异常');
      return;
    }
    _finishExtract();
    if (!mounted) return;
    _handleScheduleResult(data);
  }

  Future<void> _handleScheduleResult(Map<String, dynamic> data) async {
    final store = CapScope.of(context);
    final rawList = data['list'] is List ? data['list'] as List : const [];
    if (rawList.isEmpty) {
      _showEmptyResult(
        title: '暂未获取到课表',
        content: '请确认已经进入教务系统的课表页面，再点右上角提取。',
        diag: data['diag'],
      );
      return;
    }
    final periods = <CapPeriod>[];
    if (data['periods'] is List) {
      for (final item in data['periods'] as List) {
        if (item is! Map) continue;
        final numValue = (item['num'] as num?)?.toInt() ?? 0;
        final start = '${item['start'] ?? ''}';
        final end = '${item['end'] ?? ''}';
        if (numValue > 0 && start.isNotEmpty && end.isNotEmpty) {
          periods.add(CapPeriod(numValue, start, end));
        }
      }
    }
    final parsed = <CapCourse>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < rawList.length; i += 1) {
      final item = rawList[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = '${map['n'] ?? map['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final weeks = <int>[];
      final rawWeeks = map['w'] ?? map['weeks'];
      if (rawWeeks is List) {
        for (final value in rawWeeks) {
          final week = (value as num?)?.toInt() ?? 0;
          if (week >= 1 && week <= 40) weeks.add(week);
        }
      }
      final rawDay =
          (map['d'] as num?)?.toInt() ?? (map['day'] as num?)?.toInt() ?? 1;
      final day = rawDay >= 1 && rawDay <= 7 ? rawDay : 1;
      final rawSection =
          (map['s'] as num?)?.toInt() ??
          (map['startSection'] as num?)?.toInt() ??
          1;
      final startSection = rawSection >= 1 && rawSection <= 12 ? rawSection : 1;
      final rawSpan =
          (map['p'] as num?)?.toInt() ?? (map['span'] as num?)?.toInt() ?? 2;
      final span = rawSpan >= 1 && rawSpan <= 12 ? rawSpan : 1;
      var startWeek =
          (map['sw'] as num?)?.toInt() ??
          (map['startWeek'] as num?)?.toInt() ??
          (weeks.isEmpty ? 1 : weeks.reduce((a, b) => a < b ? a : b));
      startWeek = startWeek.clamp(1, 40);
      var endWeek =
          (map['ew'] as num?)?.toInt() ??
          (map['endWeek'] as num?)?.toInt() ??
          (weeks.isEmpty ? 18 : weeks.reduce((a, b) => a > b ? a : b));
      endWeek = endWeek.clamp(startWeek, 40);
      parsed.add(
        CapCourse(
          id: '${map['id'] ?? 'jw_${now}_$i'}',
          name: name,
          teacher: '${map['t'] ?? map['teacher'] ?? ''}',
          room: '${map['r'] ?? map['room'] ?? ''}',
          code: '${map['code'] ?? map['courseCode'] ?? ''}',
          day: day,
          startSection: startSection,
          span: span,
          startWeek: startWeek,
          endWeek: endWeek,
          oddEven:
              (map['oe'] as num?)?.toInt() ??
              (map['oddEven'] as num?)?.toInt() ??
              0,
          startTime: '${map['st'] ?? map['startTime'] ?? ''}',
          endTime: '${map['et'] ?? map['endTime'] ?? ''}',
          weeks: weeks,
          source: 'webvpn',
          updatedAt: now,
        ),
      );
    }
    final anchored = anchorCoursesByTime(
      parsed,
      periods.isEmpty ? capPeriods : periods,
    );
    final courses = <CapCourse>[];
    final seen = <String>{};
    for (final course in anchored) {
      final key =
          '${course.name}|${course.room}|${course.day}|${course.startSection}|${course.span}|${course.startWeek}|${course.endWeek}|${course.oddEven}|${course.weeks.join(',')}';
      if (!seen.add(key)) continue;
      courses.add(course);
    }
    if (courses.isEmpty) {
      _showEmptyResult(
        title: '暂未获取到课表',
        content: '请确认已经进入教务系统的课表页面，再点右上角提取。',
        diag: data['diag'],
      );
      return;
    }
    final merged = parsed.length - courses.length;
    final withRoom = courses.where((course) => course.room.isNotEmpty).length;
    final withWeeks = courses.where((course) => course.weeks.isNotEmpty).length;
    final term = '${data['term'] ?? ''}';
    final semStart = '${data['semStart'] ?? ''}';
    final maxEndWeek = courses.fold<int>(
      store.settings.totalWeeks,
      (max, course) => course.endWeek > max ? course.endWeek : max,
    );
    final totalWeeks = maxEndWeek.clamp(18, 30);
    final detail = courses
        .asMap()
        .entries
        .map((entry) => _courseBrief(entry.key + 1, entry.value))
        .join('\n');
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '提取成功',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: capRpx(context, 800)),
          child: SingleChildScrollView(
            child: Text(
              '共识别 ${parsed.length} 条排课${merged > 0 ? '，去重合并 $merged 条重复' : ''}${term.isEmpty ? '' : '（$term）'}，$withWeeks 条含精确周次，$withRoom 条含教室。是否导入本地课表？',
              style: TextStyle(
                fontSize: capRpx(context, 22),
                height: 1.65,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: detail));
              if (dialogContext.mounted) {
                showCapToast(context, '明细已复制');
              }
            },
            child: const Text('复制明细', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'import'),
            child: const Text('导入', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (action != 'import' || !mounted) return;
    if (semStart.isNotEmpty) {
      store.updateSettings(semesterStart: semStart);
    }
    store.saveSyncedCourses(
      courses,
      semesterName: term,
      semesterStart: semStart,
      totalWeeks: totalWeeks,
      source: 'webvpn',
    );
    CapReminders.syncCourseReminders(store);
    showCapToast(context, '已导入 ${courses.length} 门课');
    Navigator.of(context).pop();
  }

  String _courseBrief(int index, CapCourse course) {
    const days = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final day = course.day >= 1 && course.day <= 7 ? days[course.day] : '周?';
    final weeks = course.weeks.isNotEmpty
        ? course.weeks.join(',')
        : '${course.startWeek}-${course.endWeek}周';
    final time = course.startTime.isEmpty ? '' : ' ${course.startTime}';
    return '$index. $day${course.startSection}-${course.endSection}节 ${course.name}${course.room.isEmpty ? '' : ' ${course.room}'}$time [$weeks]';
  }

  void _showEmptyResult({
    required String title,
    required String content,
    dynamic diag,
  }) {
    if (!mounted) return;
    final diagnostic = diag is Map ? jsonEncode(diag) : '$diag';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.65,
            color: AppColors.muted,
          ),
        ),
        actions: [
          if (diagnostic.isNotEmpty && diagnostic != 'null')
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: diagnostic));
                if (dialogContext.mounted) {
                  showCapToast(context, '诊断信息已复制');
                }
              },
              child: const Text('复制诊断', style: TextStyle(color: AppColors.muted)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CapPage(
      child: Stack(
        children: [
          Column(
            children: [
              CapAppHeader(
                title: _pageTitle,
                subtitle: _pageSubtitle,
                back: true,
                right: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headIcon(context, 'refresh-cw', _reload),
                    SizedBox(width: capRpx(context, 6)),
                    _extractPill(context),
                  ],
                ),
              ),
              _stepsBar(context),
              SizedBox(
                height: capRpx(context, 10),
                child: _progress > 0 && _progress < 100
                    ? LinearProgressIndicator(
                        value: _progress / 100,
                        minHeight: 1,
                        backgroundColor: Colors.transparent,
                        color: AppColors.accent,
                      )
                    : null,
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: CapWebView(
                    key: _webKey,
                    url: _webvpnUrl,
                    onTitle: _handleTitle,
                    onLoaded: (_) {
                      if (mounted) setState(() => _webLoaded = true);
                    },
                    onStarted: (_) {},
                    onProgress: (value) {
                      if (mounted) setState(() => _progress = value);
                    },
                    onError: (url, message) {
                      if (!mounted) return;
                      showCapToast(context, '页面加载失败，可点刷新重试');
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_extracting)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x24081221),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 30),
                      vertical: capRpx(context, 22),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE60B1422),
                      borderRadius: BorderRadius.circular(capRpx(context, 18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: capRpx(context, 28),
                          height: capRpx(context, 28),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFF6F0E2),
                          ),
                        ),
                        SizedBox(width: capRpx(context, 12)),
                        Text(
                          '正在读取课表…',
                          style: TextStyle(
                            fontSize: capRpx(context, 23),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFFBF2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headIcon(BuildContext context, String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 58),
        height: capRpx(context, 58),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 28), color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _extractPill(BuildContext context) {
    return GestureDetector(
      onTap: _extracting ? null : _extract,
      child: Opacity(
        opacity: _extracting ? 0.7 : 1,
        child: Container(
          height: capRpx(context, 58),
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              CapIcon(
                _extracting ? 'loader-circle' : 'download',
                size: capRpx(context, 24),
                color: Colors.white,
              ),
              SizedBox(width: capRpx(context, 4)),
              Text(
                _extracting ? '提取中' : '提取',
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepsBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        0,
        capRpx(context, 28),
        capRpx(context, 10),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 12),
          vertical: capRpx(context, 10),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 16)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _steps.length; i += 1) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: EdgeInsets.symmetric(horizontal: capRpx(context, 6)),
                    color: AppColors.line,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: capRpx(context, 24),
                    height: capRpx(context, 24),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: capRpx(context, 14),
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: capRpx(context, 5)),
                  Text(
                    _steps[i],
                    style: TextStyle(
                      fontSize: capRpx(context, 16),
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
            GestureDetector(
              onTap: () => _showTutorial(forced: true),
              child: Padding(
                padding: EdgeInsets.only(left: capRpx(context, 8)),
                child: Text(
                  '教程',
                  style: TextStyle(
                    fontSize: capRpx(context, 16),
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}