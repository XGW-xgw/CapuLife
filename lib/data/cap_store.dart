import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/cap_date.dart';
import 'cap_course.dart';
import 'cap_ledger.dart';
import 'cap_storage.dart';

export 'cap_ledger.dart' show CapLedger, CapLedgerSummary, formatMoney;

class CapSettings {
  CapSettings({
    required this.semesterStart,
    required this.totalWeeks,
    required this.showBalance,
    this.reduceMotion = false,
    this.rememberAcademic = true,
    this.reminderPermissionAsked = false,
    Map<String, dynamic>? ai,
    Map<String, dynamic>? update,
    this.autoLedger = true,
    List<String>? captureApps,
  }) : ai = ai ?? {'enabled': false, 'baseUrl': '', 'model': '', 'apiKey': ''},
       update =
           update ??
           {
             'enabled': true,
             'repo': 'XGW-xgw/CapuLife',
             'lastCheckAt': 0,
             'skippedVersion': '',
           },
       captureApps =
           captureApps ??
           [
             'com.tencent.mm',
             'com.eg.android.AlipayGphone',
             'com.unionpay',
           ];

  String semesterStart;
  int totalWeeks;
  bool showBalance;
  bool reduceMotion;
  bool rememberAcademic;
  bool reminderPermissionAsked;
  Map<String, dynamic> ai;
  Map<String, dynamic> update;
  bool autoLedger;
  List<String> captureApps;

  Map<String, dynamic> toJson() => {
    'semesterStart': semesterStart,
    'totalWeeks': totalWeeks,
    'showBalance': showBalance,
    'reduceMotion': reduceMotion,
    'rememberAcademic': rememberAcademic,
    'reminderPermissionAsked': reminderPermissionAsked,
    'ai': ai,
    'update': update,
    'autoLedger': autoLedger,
    'captureApps': captureApps,
  };

  factory CapSettings.fromJson(Map<String, dynamic>? json) => CapSettings(
    semesterStart:
        json?['semesterStart'] as String? ?? formatDateKey(semesterStartForNow()),
    totalWeeks: (json?['totalWeeks'] as num?)?.toInt() ?? 20,
    showBalance: json?['showBalance'] as bool? ?? true,
    reduceMotion: json?['reduceMotion'] as bool? ?? false,
    rememberAcademic: json?['rememberAcademic'] as bool? ?? true,
    reminderPermissionAsked:
        json?['reminderPermissionAsked'] as bool? ?? false,
    ai: json?['ai'] is Map
        ? Map<String, dynamic>.from(json!['ai'] as Map)
        : null,
    update: json?['update'] is Map
        ? Map<String, dynamic>.from(json!['update'] as Map)
        : null,
    autoLedger: json?['autoLedger'] as bool? ?? true,
    captureApps: json?['captureApps'] is List
        ? ((json!['captureApps'] as List).map((e) => '$e').toList())
        : null,
  );
}

class CapCountdown {
  CapCountdown({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.targetDate,
    this.targetTime = '09:00',
    this.tag = '',
    this.skin = 'paper',
    this.customImage = '',
    this.reminder = false,
    this.reminderTime = '20:00',
    this.leadDays = 1,
    this.pinned = false,
    this.note = '',
    required this.createdAt,
  });

  String id;
  String title;
  String subtitle;
  String targetDate;
  String targetTime;
  String tag;
  String skin;
  String customImage;
  bool reminder;
  String reminderTime;
  int leadDays;
  bool pinned;
  String note;
  int createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'targetDate': targetDate,
    'targetTime': targetTime,
    'tag': tag,
    'skin': skin,
    'customImage': customImage,
    'reminder': reminder,
    'reminderTime': reminderTime,
    'leadDays': leadDays,
    'pinned': pinned,
    'note': note,
    'createdAt': createdAt,
  };

  factory CapCountdown.fromJson(Map<String, dynamic> json) => CapCountdown(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    targetDate: json['targetDate'] as String? ?? formatDateKey(),
    targetTime: json['targetTime'] as String? ?? '09:00',
    tag: json['tag'] as String? ?? '',
    skin: json['skin'] as String? ?? 'paper',
    customImage: json['customImage'] as String? ?? '',
    reminder: json['reminder'] as bool? ?? false,
    reminderTime: json['reminderTime'] as String? ?? '20:00',
    leadDays: (json['leadDays'] as num?)?.toInt() ?? 1,
    pinned: json['pinned'] as bool? ?? false,
    note: json['note'] as String? ?? '',
    createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
  );
}

class CapTodo {
  CapTodo({
    required this.id,
    required this.title,
    this.note = '',
    this.done = false,
    this.doneAt = 0,
    required this.createdAt,
    this.updatedAt = 0,
    this.dueDate = '',
    this.dueTime = '',
    this.reminder = false,
    this.reminderAt = 0,
    this.tags = const [],
    this.priority = 0,
    this.source = 'manual',
    this.sourceApp = '',
    this.sourceId = '',
    this.url = '',
  });

  String id;
  String title;
  String note;
  bool done;
  int doneAt;
  int createdAt;
  int updatedAt;
  String dueDate;
  String dueTime;
  bool reminder;
  int reminderAt;
  List<String> tags;
  int priority;
  String source;
  String sourceApp;
  String sourceId;
  String url;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'done': done,
    'doneAt': doneAt,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'dueDate': dueDate,
    'dueTime': dueTime,
    'reminder': reminder,
    'reminderAt': reminderAt,
    'tags': tags,
    'priority': priority,
    'source': source,
    'sourceApp': sourceApp,
    'sourceId': sourceId,
    'url': url,
  };

  factory CapTodo.fromJson(Map<String, dynamic> json) => CapTodo(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    note: json['note'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    doneAt: (json['doneAt'] as num?)?.toInt() ?? 0,
    createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    dueDate: json['dueDate'] as String? ?? '',
    dueTime: json['dueTime'] as String? ?? '',
    reminder: json['reminder'] as bool? ?? false,
    reminderAt: (json['reminderAt'] as num?)?.toInt() ?? 0,
    tags: ((json['tags'] as List?) ?? const []).map((e) => '$e').toList(),
    priority: (json['priority'] as num?)?.toInt() ?? 0,
    source: json['source'] as String? ?? 'manual',
    sourceApp: json['sourceApp'] as String? ?? '',
    sourceId: json['sourceId'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );
}

class CapTodoStats {
  const CapTodoStats({
    required this.total,
    required this.done,
    required this.pending,
    required this.percent,
  });

  final int total;
  final int done;
  final int pending;
  final int percent;
}

class CapStore extends ChangeNotifier {
  CapStore._({
    required this.settings,
    required this.countdowns,
    required this.todos,
    required this.courses,
    required this.scheduleMeta,
    required this.ledger,
    required this.electricity,
    this.extra = const {},
  });

  CapSettings settings;
  List<CapCountdown> countdowns;
  List<CapTodo> todos;
  List<CapCourse> courses;
  Map<String, dynamic> scheduleMeta;
  CapLedger ledger;
  Map<String, dynamic> electricity;

  /// Root keys owned by later migration batches (grades, academic…)
  /// are preserved verbatim so switching builds never drops user data.
  Map<String, dynamic> extra;

  Timer? _saveTimer;
  bool _loaded = false;

  static Future<CapStore> load() async {
    Map<String, dynamic>? saved;
    try {
      final raw = await CapStorage.read();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) saved = decoded;
      }
    } catch (_) {}
    final store = CapStore._fromSaved(saved);
    store._loaded = true;
    if (saved == null ||
        saved.containsKey('grades') ||
        saved.containsKey('homework')) {
      unawaited(store.save());
    }
    return store;
  }

  factory CapStore.inMemory({Map<String, dynamic>? saved}) {
    final store = CapStore._fromSaved(saved);
    store._loaded = true;
    return store;
  }

  factory CapStore._fromSaved(Map<String, dynamic>? saved) {
    final defaults = _defaults();
    final countdowns = saved?['countdowns'];
    final todos = saved?['todos'];
    final courses = saved?['courses'];
    final extra = <String, dynamic>{};
    if (saved != null) {
      for (final entry in saved.entries) {
        if (!const {
          'version',
          'settings',
          'countdowns',
          'todos',
          'courses',
          'scheduleMeta',
          'ledger',
          'electricity',
          'grades',
          'homework',
        }.contains(entry.key)) {
          extra[entry.key] = entry.value;
        }
      }
    }
    return CapStore._(
      settings: CapSettings.fromJson(
        saved?['settings'] is Map
            ? Map<String, dynamic>.from(saved!['settings'] as Map)
            : null,
      ),
      countdowns: countdowns is List
          ? countdowns
                .whereType<Map>()
                .map((e) => CapCountdown.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : defaults.countdowns,
      todos: todos is List
          ? todos
                .whereType<Map>()
                .map((e) => CapTodo.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : <CapTodo>[],
      courses: courses is List
          ? courses
                .whereType<Map>()
                .map((e) => CapCourse.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : <CapCourse>[],
      scheduleMeta: saved?['scheduleMeta'] is Map
          ? Map<String, dynamic>.from(saved!['scheduleMeta'] as Map)
          : {'semesterName': '', 'syncedAt': 0, 'source': ''},
      ledger: CapLedger.fromJson(
        saved?['ledger'] is Map
            ? Map<String, dynamic>.from(saved!['ledger'] as Map)
            : null,
      ),
      electricity: saved?['electricity'] is Map
          ? Map<String, dynamic>.from(saved!['electricity'] as Map)
          : {'binding': null, 'balance': null},
      extra: extra,
    );
  }


  static CapStore _defaults() {
    final now = DateTime.now();
    final cet = nextCetDate(now);
    final cetKey = formatDateKey(cet);
    return CapStore._(
      settings: CapSettings.fromJson(null),
      countdowns: [
        CapCountdown(
          id: 'default_cet4',
          title: '大学英语四级',
          subtitle: 'CET-4',
          targetDate: cetKey,
          targetTime: '09:00',
          tag: '四六级',
          skin: 'paper',
          reminder: true,
          pinned: true,
          note: '按往年规律预置，可在考试院公布后修改日期。',
          createdAt: now.millisecondsSinceEpoch,
        ),
        CapCountdown(
          id: 'default_cet6',
          title: '大学英语六级',
          subtitle: 'CET-6',
          targetDate: cetKey,
          targetTime: '15:00',
          tag: '四六级',
          skin: 'blossom',
          reminder: true,
          note: '按往年规律预置，可在考试院公布后修改日期。',
          createdAt: now.millisecondsSinceEpoch + 1,
        ),
      ],
      todos: [],
      courses: [],
      scheduleMeta: {'semesterName': '', 'syncedAt': 0, 'source': ''},
      ledger: CapLedger.defaults(),
      electricity: {'binding': null, 'balance': null},
    );
  }

  SemesterWeekInfo weekInfoAt(DateTime now) =>
      semesterWeek(settings.semesterStart, settings.totalWeeks, date: now);

  List<CapCourse> coursesForDay(int week, int day) {
    final target = day.clamp(1, 7);
    final list = courses
        .where((course) => course.day == target && course.isInWeek(week))
        .toList();
    list.sort((a, b) => a.startSection.compareTo(b.startSection));
    return list;
  }

  List<CapCourse> todayCoursesAt(DateTime now) {
    final info = weekInfoAt(now);
    if (info.phase != 'active') return [];
    return coursesForDay(info.week, now.weekday);
  }

  CapCourse? currentCourseAt(DateTime now, List<CapCourse> todayCourses) {
    final minutes = now.hour * 60 + now.minute;
    for (final course in todayCourses) {
      final range = course.clockRange;
      if (range != null && minutes >= range.start && minutes <= range.end) {
        return course;
      }
    }
    return null;
  }

  CapCourse? nextCourseAt(DateTime now, List<CapCourse> todayCourses) {
    final minutes = now.hour * 60 + now.minute;
    final sorted = [...todayCourses]
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
    for (final course in sorted) {
      final range = course.clockRange;
      if (range != null && range.start > minutes) return course;
    }
    return null;
  }

  int weeklyCourseCount(int week) {
    return courses.where((course) => course.isInWeek(week)).length;
  }

  void updateSettings({
    String? semesterStart,
    int? totalWeeks,
    bool? showBalance,
    bool? reduceMotion,
    bool? rememberAcademic,
    bool? reminderPermissionAsked,
    Map<String, dynamic>? ai,
    Map<String, dynamic>? update,
    bool? autoLedger,
    List<String>? captureApps,
  }) {
    if (semesterStart != null) settings.semesterStart = semesterStart;
    if (totalWeeks != null) {
      settings.totalWeeks = totalWeeks.clamp(1, 30);
    }
    if (showBalance != null) settings.showBalance = showBalance;
    if (reduceMotion != null) settings.reduceMotion = reduceMotion;
    if (rememberAcademic != null) {
      settings.rememberAcademic = rememberAcademic;
    }
    if (reminderPermissionAsked != null) {
      settings.reminderPermissionAsked = reminderPermissionAsked;
    }
    if (ai != null) settings.ai = {...settings.ai, ...ai};
    if (update != null) settings.update = {...settings.update, ...update};
    if (autoLedger != null) settings.autoLedger = autoLedger;
    if (captureApps != null) {
      settings.captureApps = [...captureApps];
    }
    _changed();
  }

  void upsertCourse(CapCourse course) {
    course.alignTimesToPeriods();
    final index = courses.indexWhere((item) => item.id == course.id);
    if (index >= 0) {
      courses[index] = course;
    } else {
      courses = [...courses, course];
    }
    _changed();
  }

  void removeCourse(String id) {
    courses = courses.where((item) => item.id != id).toList();
    _changed();
  }

  void saveSyncedCourses(
    List<CapCourse> incoming, {
    String semesterName = '',
    String semesterStart = '',
    int? totalWeeks,
    String source = 'webvpn',
  }) {
    final manual = courses
        .where((item) => item.id.startsWith('manual_'))
        .toList();
    for (final course in incoming) {
      course.alignTimesToPeriods();
    }
    for (final course in manual) {
      course.alignTimesToPeriods();
    }
    courses = [...incoming, ...manual];
    scheduleMeta = {
      ...scheduleMeta,
      'semesterName': semesterName,
      'syncedAt': DateTime.now().millisecondsSinceEpoch,
      'source': source,
    };
    if (semesterStart.isNotEmpty) settings.semesterStart = semesterStart;
    if (totalWeeks != null) {
      settings.totalWeeks = totalWeeks.clamp(1, 30);
    }
    _changed();
  }

  void clearCourses() {
    courses = [];
    scheduleMeta = {
      ...scheduleMeta,
      'semesterName': '',
      'syncedAt': 0,
      'source': 'cleared',
    };
    _changed();
  }

  /* ------------------------------ countdowns ----------------------------- */

  List<CapCountdown> get countdownsSorted {
    final list = [...countdowns];
    list.sort((a, b) {
      final aPast = diffDays(a.targetDate) < 0 ? 1 : 0;
      final bPast = diffDays(b.targetDate) < 0 ? 1 : 0;
      if (aPast != bPast) return aPast - bPast;
      return a.targetDate.compareTo(b.targetDate);
    });
    return list;
  }

  List<String> get allCountdownTags {
    final set = <String>{};
    for (final item in countdowns) {
      if (item.tag.isNotEmpty) set.add(item.tag);
    }
    return set.toList();
  }

  CapCountdown? get nearestCountdown {
    if (countdowns.isEmpty) return null;
    final list = [...countdowns];
    list.sort((a, b) {
      final byDate = a.targetDate.compareTo(b.targetDate);
      if (byDate != 0) return byDate;
      return a.targetTime.compareTo(b.targetTime);
    });
    final today = formatDateKey();
    final future = list.where((item) => item.targetDate.compareTo(today) >= 0);
    if (future.isNotEmpty) return future.first;
    return list.last;
  }

  int? get nearestCountdownDays {
    final item = nearestCountdown;
    if (item == null) return null;
    return diffDays(item.targetDate);
  }

  CapCountdown? upsertCountdown(CapCountdown input) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = CapCountdown(
      id: input.id.isEmpty
          ? 'cd_${now.toRadixString(36)}_${math.Random().nextInt(0xFFFF).toRadixString(36)}'
          : input.id,
      title: input.title.trim().length > 30
          ? input.title.trim().substring(0, 30)
          : input.title.trim(),
      subtitle: input.subtitle.trim().length > 20
          ? input.subtitle.trim().substring(0, 20)
          : input.subtitle.trim(),
      targetDate: input.targetDate.isEmpty ? formatDateKey() : input.targetDate,
      targetTime: input.targetTime.isEmpty ? '09:00' : input.targetTime,
      tag: input.tag.trim().length > 10
          ? input.tag.trim().substring(0, 10)
          : input.tag.trim(),
      skin: input.skin.isEmpty ? 'paper' : input.skin,
      customImage: input.skin == 'custom' ? input.customImage : '',
      reminder: input.reminder,
      reminderTime: input.reminderTime.isEmpty ? '20:00' : input.reminderTime,
      leadDays: input.leadDays.clamp(0, 30),
      pinned: input.pinned,
      note: input.note.trim().length > 80
          ? input.note.trim().substring(0, 80)
          : input.note.trim(),
      createdAt: input.createdAt == 0 ? now : input.createdAt,
    );
    final index = countdowns.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      countdowns[index] = item;
    } else {
      countdowns = [...countdowns, item];
    }
    _changed();
    return item;
  }

  void removeCountdown(String id) {
    countdowns = countdowns.where((item) => item.id != id).toList();
    _changed();
  }

  void togglePinCountdown(String id) {
    final index = countdowns.indexWhere((item) => item.id == id);
    if (index < 0) return;
    countdowns[index].pinned = !countdowns[index].pinned;
    _changed();
  }

  /* -------------------------------- todos -------------------------------- */

  List<CapTodo> get pendingTodos {
    final list = todos.where((item) => !item.done).toList();
    list.sort((a, b) {
      final aDue = a.dueDate.isEmpty ? '9999-99-99' : a.dueDate;
      final bDue = b.dueDate.isEmpty ? '9999-99-99' : b.dueDate;
      final byDate = aDue.compareTo(bDue);
      if (byDate != 0) return byDate;
      return a.priority.compareTo(b.priority);
    });
    return list;
  }

  List<CapTodo> todayTodosAt(DateTime now) {
    final today = formatDateKey(now);
    return pendingTodos
        .where((item) => item.dueDate.isEmpty || item.dueDate.compareTo(today) <= 0)
        .toList();
  }

  CapTodoStats get todoStats {
    final total = todos.length;
    final done = todos.where((item) => item.done).length;
    return CapTodoStats(
      total: total,
      done: done,
      pending: total - done,
      percent: total == 0 ? 0 : ((done / total) * 100).round(),
    );
  }

  CapTodoStats todayDoneStatsAt(DateTime now) {
    final today = formatDateKey(now);
    final due = todos
        .where(
          (item) =>
              item.dueDate == today ||
              (item.dueDate.isEmpty &&
                  formatDateKey(
                        DateTime.fromMillisecondsSinceEpoch(
                          item.createdAt == 0
                              ? DateTime.now().millisecondsSinceEpoch
                              : item.createdAt,
                        ),
                      ) ==
                      today),
        )
        .toList();
    final done = due.where((item) => item.done).length;
    return CapTodoStats(
      total: due.length,
      done: done,
      pending: due.length - done,
      percent: due.isEmpty ? 0 : ((done / due.length) * 100).round(),
    );
  }

  CapTodo? addTodo({
    String? id,
    required String title,
    String note = '',
    String dueDate = '',
    String dueTime = '',
    List<String> tags = const [],
    bool reminder = false,
    int reminderAt = 0,
    int? priority,
    String source = 'manual',
    String sourceApp = '',
    String sourceId = '',
    String url = '',
    int? createdAt,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final clean = title.trim();
    if (clean.isEmpty) return null;
    final item = CapTodo(
      id: (id == null || id.isEmpty)
          ? 'td_${now.toRadixString(36)}_${math.Random().nextInt(0xFFFF).toRadixString(36)}'
          : id,
      title: clean.length > 80 ? clean.substring(0, 80) : clean,
      note: note.trim().length > 300 ? note.trim().substring(0, 300) : note.trim(),
      createdAt: createdAt ?? now,
      updatedAt: now,
      dueDate: dueDate,
      dueTime: dueTime,
      tags: tags.take(4).toList(),
      priority: priority ?? todos.length,
      reminder: reminder,
      reminderAt: reminderAt,
      source: source,
      sourceApp: sourceApp,
      sourceId: sourceId,
      url: url,
    );
    todos = [...todos, item];
    _changed();
    return item;
  }

  List<CapTodo> addTodos(List<CapTodo> inputs) {
    final created = <CapTodo>[];
    for (final input in inputs) {
      final item = addTodo(
        title: input.title,
        note: input.note,
        dueDate: input.dueDate,
        dueTime: input.dueTime,
        tags: input.tags,
        reminder: input.reminder,
        reminderAt: input.reminderAt,
        source: input.source,
        sourceApp: input.sourceApp,
        sourceId: input.sourceId,
        url: input.url,
      );
      if (item != null) created.add(item);
    }
    return created;
  }

  CapTodo? upsertTodo(CapTodo input) {
    final index = todos.indexWhere((item) => item.id == input.id);
    if (index < 0) {
      return addTodo(
        title: input.title,
        note: input.note,
        dueDate: input.dueDate,
        dueTime: input.dueTime,
        tags: input.tags,
        reminder: input.reminder,
        reminderAt: input.reminderAt,
        priority: input.priority,
        source: input.source,
        sourceApp: input.sourceApp,
        sourceId: input.sourceId,
        url: input.url,
        createdAt: input.createdAt,
      );
    }
    final current = todos[index];
    final wasDone = current.done;
    input.title = input.title.trim();
    input.note = input.note.trim();
    if (input.title.isEmpty) return null;
    input.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (input.done && !wasDone) input.doneAt = DateTime.now().millisecondsSinceEpoch;
    if (!input.done) input.doneAt = 0;
    todos[index] = input;
    _changed();
    return input;
  }

  void toggleTodo(String id) {
    final index = todos.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final item = todos[index];
    item.done = !item.done;
    item.doneAt = item.done ? DateTime.now().millisecondsSinceEpoch : 0;
    item.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _changed();
  }

  void removeTodo(String id) {
    todos = todos.where((item) => item.id != id).toList();
    _changed();
  }

  void moveTodoBefore(String sourceId, String targetId) {
    if (sourceId.isEmpty || targetId.isEmpty || sourceId == targetId) return;
    final from = todos.indexWhere((item) => item.id == sourceId);
    if (from < 0) return;
    var to = todos.indexWhere((item) => item.id == targetId);
    if (to < 0) return;
    final moved = todos.removeAt(from);
    to = todos.indexWhere((item) => item.id == targetId);
    todos.insert(to < 0 ? todos.length : to, moved);
    for (var i = 0; i < todos.length; i += 1) {
      todos[i].priority = i;
    }
    _changed();
  }

  /* -------------------------------- ledger ------------------------------- */

  CapLedgerSummary ledgerSummaryAt(DateTime now) =>
      ledgerSummary(ledger, now: now);

  List<CapTransaction> transactionsInCurrentPeriod([DateTime? now]) {
    final period = budgetPeriod(ledger.budget, now: now);
    return transactionsInPeriod(ledger, period);
  }

  CapTransaction? upsertLedgerTransaction({
    String? id,
    required String type,
    required int amountCents,
    String? categoryId,
    String note = '',
    String payee = '',
    int timestamp = 0,
    bool budgetExcluded = false,
    int aaShares = 0,
    String source = 'manual',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeType = type == 'income' ? 'income' : 'expense';
    final cents = math.max(0, amountCents.round());
    if (cents == 0) return null;
    final item = CapTransaction(
      id: (id == null || id.isEmpty)
          ? 'tx_${now.toRadixString(36)}_${math.Random().nextInt(0xFFFF).toRadixString(36)}'
          : id,
      type: safeType,
      amountCents: cents,
      categoryId:
          (categoryId == null || categoryId.isEmpty)
              ? (safeType == 'income' ? 'inc_living' : 'cat_food')
              : categoryId,
      note: note.trim().length > 60 ? note.trim().substring(0, 60) : note.trim(),
      payee: payee.trim().length > 24
          ? payee.trim().substring(0, 24)
          : payee.trim(),
      timestamp: timestamp == 0 ? now : timestamp,
      budgetExcluded: safeType == 'expense' ? budgetExcluded : false,
      aaShares: safeType == 'expense' ? aaShares.clamp(0, 50) : 0,
      source: source,
      createdAt: now,
      updatedAt: now,
    );
    final index = ledger.transactions.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      final old = ledger.transactions[index];
      item.createdAt = old.createdAt == 0 ? now : old.createdAt;
      ledger.transactions[index] = item;
    } else {
      ledger.transactions.add(item);
    }
    ledger.meta['lastCategoryId'] = item.categoryId;
    ledger.meta['updatedAt'] = now;
    _changed();
    return item;
  }

  void removeLedgerTransaction(String id) {
    ledger.transactions.removeWhere((item) => item.id == id);
    _changed();
  }

  void setLedgerBudget(Map<String, dynamic> patch) {
    ledger.budget = {...ledger.budget, ...patch};
    _changed();
  }

  LedgerCategory? addLedgerCategory({
    required String name,
    String type = 'expense',
  }) {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final safeType = type == 'income' ? 'income' : 'expense';
    for (final item in ledger.categories) {
      if (item.type == safeType && item.name == clean) return item;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = LedgerCategory(
      id: 'cat_${now.toRadixString(36)}_${math.Random().nextInt(0xFFFF).toRadixString(36)}',
      name: clean.length > 8 ? clean.substring(0, 8) : clean,
      type: safeType,
      icon: safeType == 'income' ? 'wallet' : 'tag',
      color: safeType == 'income' ? '#2C8069' : '#747B82',
      sortOrder: ledger.categories.length,
      builtin: false,
    );
    ledger.categories.add(item);
    _changed();
    return item;
  }

  void addLedgerPending(Map<String, dynamic> item) {
    final id = '${item['id'] ?? ''}';
    if (id.isEmpty) return;
    if (ledger.pending.any((entry) => '${entry['id'] ?? ''}' == id)) return;
    ledger.pending.add({...item});
    _changed();
  }

  CapTransaction? confirmLedgerCapture(
    String id, {
    String? categoryId,
    String? note,
    int? timestamp,
  }) {
    final index = ledger.pending.indexWhere((item) => '${item['id']}' == id);
    if (index < 0) return null;
    final item = ledger.pending[index];
    final saved = upsertLedgerTransaction(
      type: '${item['type'] ?? 'expense'}',
      amountCents: (item['amountCents'] as num?)?.toInt() ?? 0,
      categoryId: categoryId ?? '${item['categoryId'] ?? 'cat_other'}',
      note: note ?? '${item['merchant'] ?? item['title'] ?? ''}',
      payee: '${item['payee'] ?? ''}',
      timestamp: timestamp ?? (item['at'] as num?)?.toInt() ?? 0,
      source: '${item['source'] ?? 'notification'}',
    );
    if (saved == null) return null;
    ledger.pending.removeAt(index);
    final key = '${item['merchant'] ?? ''}'.trim().toLowerCase();
    if (key.isNotEmpty && saved.type == 'expense') {
      ledger.merchantRules[key] = saved.categoryId;
    }
    _changed();
    return saved;
  }

  void dismissLedgerCapture(String id) {
    ledger.pending.removeWhere((item) => '${item['id']}' == id);
    _changed();
  }

  /* ------------------------------ electricity ---------------------------- */

  String get electricityValue {
    final balance = electricity['balance'];
    if (balance is! Map) return '--';
    final value = balance['val'];
    if (value == null || '$value'.isEmpty) return '--';
    if (!settings.showBalance) return '••';
    return '$value';
  }

  String get electricityUnit {
    final balance = electricity['balance'];
    if (balance is! Map) return '';
    return '${balance['unit'] ?? ''}';
  }

  String get electricityHint {
    final binding = electricity['binding'];
    if (binding is! Map) return '绑定寝室';
    final dormName = '${binding['dormName'] ?? ''}';
    return dormName.isEmpty ? '查看用电' : dormName;
  }

  void setElectricityBinding(Map<String, dynamic>? binding) {
    electricity['binding'] = binding;
    if (binding == null) electricity['balance'] = null;
    _changed();
  }

  void setElectricityBalance(Map<String, dynamic>? balance) {
    electricity['balance'] = balance;
    _changed();
  }

  /// Local daily sampling for the Longquan meter, which has no daily API.
  /// Mirrors `src/utils/electricityTrend.js`.
  void recordElectricitySample(
    Map<String, dynamic> binding,
    Map<String, dynamic> balance,
  ) {
    final id = '${binding['id'] ?? ''}';
    if (id.isEmpty) return;
    final value = double.tryParse('${balance['val'] ?? ''}');
    if (value == null || !value.isFinite) return;
    final timestamp =
        (balance['updatedAt'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final samples = electricity['samples'] is Map
        ? Map<String, dynamic>.from(electricity['samples'] as Map)
        : <String, dynamic>{};
    final list = samples[id] is List
        ? (samples[id] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final dayUse = double.tryParse('${balance['dayUse'] ?? ''}');
    final sample = <String, dynamic>{
      't': timestamp,
      'v': value,
      'u': '${balance['unit'] ?? '度'}',
      'd': dayUse,
      's': '${balance['system'] ?? binding['system'] ?? ''}',
    };
    if (list.isNotEmpty) {
      final last = list.last;
      final lastValue = (last['v'] as num?)?.toDouble();
      final lastAt = (last['t'] as num?)?.toInt() ?? 0;
      if (lastValue != null &&
          (lastValue - value).abs() < 0.005 &&
          timestamp - lastAt < 10 * 60 * 1000) {
        last['t'] = timestamp;
        last['d'] = sample['d'];
        last['s'] = sample['s'];
      } else {
        list.add(sample);
      }
    } else {
      list.add(sample);
    }
    if (list.length > 600) {
      list.removeRange(0, list.length - 600);
    }
    samples[id] = list;
    electricity['samples'] = samples;
    _changed();
  }

  List<Map<String, dynamic>> localElectricityUsage(
    Map<String, dynamic>? binding, {
    int limitDays = 31,
  }) {
    final id = '${binding?['id'] ?? ''}';
    if (id.isEmpty) return [];
    final samples = electricity['samples'] is Map
        ? electricity['samples'] as Map
        : const {};
    final raw = samples[id];
    if (raw is! List) return [];
    final list = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(
          (e) =>
              ((e['t'] as num?)?.toInt() ?? 0) > 0 &&
              double.tryParse('${e['v'] ?? ''}') != null,
        )
        .toList()
      ..sort(
        (a, b) => ((a['t'] as num?)?.toInt() ?? 0).compareTo(
          (b['t'] as num?)?.toInt() ?? 0,
        ),
      );
    if (list.isEmpty) return [];
    if (list.length == 1) {
      final only = list.first;
      final dayUse = double.tryParse('${only['d'] ?? ''}');
      if (dayUse != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          (only['t'] as num).toInt(),
        );
        return [
          {
            'date': formatDateKey(date),
            'value': math.max(0.0, dayUse),
            'source': 'local',
          },
        ];
      }
      return [];
    }
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final item in list) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        (item['t'] as num).toInt(),
      );
      byDate.putIfAbsent(formatDateKey(date), () => []).add(item);
    }
    final dates = byDate.keys.toList()..sort();
    final result = <Map<String, dynamic>>[];
    double? previousLastValue;
    final cutoff = DateTime.now()
        .subtract(Duration(days: math.max(1, limitDays)))
        .millisecondsSinceEpoch;
    for (final key in dates) {
      final entries = byDate[key]!;
      final last = entries.last;
      final dayUse = double.tryParse('${last['d'] ?? ''}');
      double? value;
      if (dayUse != null) {
        value = math.max(0.0, dayUse);
      } else if (previousLastValue != null) {
        final current = double.tryParse('${last['v'] ?? ''}');
        if (current != null) {
          value = math.max(0.0, previousLastValue - current);
        }
      }
      final current = double.tryParse('${last['v'] ?? ''}');
      if (current != null) previousLastValue = current;
      final timestamp = DateTime.parse('${key}T12:00:00').millisecondsSinceEpoch;
      if (timestamp < cutoff) continue;
      if (value != null) {
        result.add({
          'date': key,
          'value': double.parse(value.toStringAsFixed(2)),
          'source': 'local',
        });
      }
    }
    return result;
  }

  void setAutoLedger(bool enabled) {
    updateSettings(autoLedger: enabled);
  }

  /* ------------------------------- lifecycle ----------------------------- */

  void resetAllData() {
    final fresh = _defaults();
    settings = fresh.settings;
    countdowns = fresh.countdowns;
    todos = fresh.todos;
    courses = fresh.courses;
    scheduleMeta = fresh.scheduleMeta;
    ledger = fresh.ledger;
    electricity = fresh.electricity;
    extra = {};
    _changed();
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 80), () {
      unawaited(save());
    });
  }

  Future<void> save() async {
    if (!_loaded) return;
    final payload = <String, dynamic>{
      ...extra,
      'version': 2,
      'settings': settings.toJson(),
      'countdowns': countdowns.map((item) => item.toJson()).toList(),
      'todos': todos.map((item) => item.toJson()).toList(),
      'courses': courses.map((item) => item.toJson()).toList(),
      'scheduleMeta': scheduleMeta,
      'ledger': ledger.toJson(),
      'electricity': electricity,
    };
    try {
      await CapStorage.write(jsonEncode(payload));
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

class CapScope extends InheritedNotifier<CapStore> {
  const CapScope({
    super.key,
    required CapStore store,
    required super.child,
  }) : super(notifier: store);

  static CapStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CapScope>();
    assert(scope != null, 'CapScope is missing above this widget');
    return scope!.notifier!;
  }
}
