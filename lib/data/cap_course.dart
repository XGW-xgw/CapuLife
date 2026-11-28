import 'dart:math' as math;

import 'package:flutter/material.dart';

class CapPeriod {
  const CapPeriod(this.num, this.start, this.end);

  final int num;
  final String start;
  final String end;
}

const capPeriods = [
  CapPeriod(1, '08:40', '09:25'),
  CapPeriod(2, '09:35', '10:20'),
  CapPeriod(3, '10:35', '11:20'),
  CapPeriod(4, '11:30', '12:15'),
  CapPeriod(5, '14:00', '14:45'),
  CapPeriod(6, '14:55', '15:40'),
  CapPeriod(7, '15:55', '16:40'),
  CapPeriod(8, '16:50', '17:35'),
  CapPeriod(9, '19:00', '19:45'),
  CapPeriod(10, '19:55', '20:40'),
  CapPeriod(11, '20:55', '21:30'),
];

const capWeekLabelsShort = ['一', '二', '三', '四', '五', '六', '日'];

class CoursePalette {
  const CoursePalette({
    required this.bg,
    required this.ink,
    required this.line,
    required this.soft,
  });

  final Color bg;
  final Color ink;
  final Color line;
  final Color soft;
}

const coursePalettes = [
  CoursePalette(
    bg: Color(0xFFEAF0FD),
    ink: Color(0xFF173E97),
    line: Color(0xFF2C5BC7),
    soft: Color(0x1A2C5BC7),
  ),
  CoursePalette(
    bg: Color(0xFFEAF4EF),
    ink: Color(0xFF155C49),
    line: Color(0xFF2C8069),
    soft: Color(0x1A2C8069),
  ),
  CoursePalette(
    bg: Color(0xFFFBF0DF),
    ink: Color(0xFF815317),
    line: Color(0xFFC08834),
    soft: Color(0x1FC08834),
  ),
  CoursePalette(
    bg: Color(0xFFF5EDF8),
    ink: Color(0xFF6A3B7A),
    line: Color(0xFF8E5CA0),
    soft: Color(0x1A8E5CA0),
  ),
  CoursePalette(
    bg: Color(0xFFF9ECEA),
    ink: Color(0xFF873B2E),
    line: Color(0xFFC25E49),
    soft: Color(0x1AC25E49),
  ),
  CoursePalette(
    bg: Color(0xFFEAF3F5),
    ink: Color(0xFF255E6B),
    line: Color(0xFF3F8392),
    soft: Color(0x1A3F8392),
  ),
];

CoursePalette coursePaletteFor(String name) {
  var hash = 0;
  for (var i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return coursePalettes[hash % coursePalettes.length];
}

class CapCourse {
  CapCourse({
    required this.id,
    required this.name,
    this.room = '',
    this.teacher = '',
    this.code = '',
    required this.day,
    this.startSection = 1,
    this.span = 2,
    this.startWeek = 1,
    this.endWeek = 18,
    this.startTime = '',
    this.endTime = '',
    this.oddEven = 0,
    this.weeks = const [],
    this.source = 'manual',
    this.updatedAt = 0,
  });

  String id;
  String name;
  String room;
  String teacher;
  String code;
  int day;
  int startSection;
  int span;
  int startWeek;
  int endWeek;
  String startTime;
  String endTime;
  int oddEven;
  List<int> weeks;
  String source;
  int updatedAt;

  List<int> get normalizedWeeks {
    if (weeks.isNotEmpty) {
      return weeks.where((n) => n >= 1 && n <= 40).toList();
    }
    final start = math.max(1, startWeek);
    final end = math.max(start, endWeek);
    final list = <int>[];
    for (var week = start; week <= end; week++) {
      if (oddEven == 1 && week.isEven) continue;
      if (oddEven == 2 && week.isOdd) continue;
      list.add(week);
    }
    return list;
  }

  bool isInWeek(int week) {
    final list = normalizedWeeks;
    return list.isEmpty || list.contains(week);
  }

  int get endSection => startSection + span.clamp(1, 99) - 1;

  String get sectionText {
    final s = math.max(1, startSection);
    final e = s + math.max(1, span) - 1;
    return span > 1 ? '第 $s-$e 节' : '第 $s 节';
  }

  CapPeriod? get startPeriod => startSection >= 1 && startSection <= capPeriods.length
      ? capPeriods[startSection - 1]
      : null;

  CapPeriod? get endPeriod => endSection >= 1 && endSection <= capPeriods.length
      ? capPeriods[endSection - 1]
      : null;

  String get startClock {
    final period = startPeriod;
    if (period != null) return period.start;
    return startTime;
  }

  String get endClock {
    final period = endPeriod;
    if (period != null) return period.end;
    return endTime;
  }

  /// If the stored clock disagrees with the stored section, prefer the clock:
  /// the exact class time is what the user checks, and the grid is only a row
  /// approximation. A 30-minute tolerance matches the extractor's anchor rule.
  void alignSectionsToTimes([List<CapPeriod> periods = capPeriods]) {
    int? minutesOf(String value) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
      if (match == null) return null;
      return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    }

    CapPeriod? nearest(int minutes, bool start) {
      CapPeriod? hit;
      var best = 31;
      for (final period in periods) {
        final value = minutesOf(start ? period.start : period.end);
        if (value == null) continue;
        final diff = (value - minutes).abs();
        if (diff < best) {
          best = diff;
          hit = period;
        }
      }
      return hit;
    }

    final startMinutes = minutesOf(startTime);
    if (startMinutes != null) {
      final hit = nearest(startMinutes, true);
      if (hit != null) startSection = hit.num;
    }
    final endMinutes = minutesOf(endTime);
    if (endMinutes != null) {
      final hit = nearest(endMinutes, false);
      if (hit != null && hit.num >= startSection) {
        span = hit.num - startSection + 1;
      }
    }
  }

  /// Keep the stored clock in sync with the section row. The timetable grid is
  /// section-based, so any custom/imported minute offset must not make the
  /// detail text disagree with the row it is drawn on.
  void alignTimesToPeriods([List<CapPeriod> periods = capPeriods]) {
    if (startSection >= 1 && startSection <= periods.length) {
      startTime = periods[startSection - 1].start;
    }
    final last = endSection;
    if (last >= 1 && last <= periods.length) {
      endTime = periods[last - 1].end;
    }
  }

  String get timeText {
    final start = startClock;
    final end = endClock;
    if (start.isNotEmpty && end.isNotEmpty) return '$start – $end';
    return start;
  }

  String get weekText {
    final list = normalizedWeeks;
    if (list.isEmpty) return '全学期';
    final first = list.first;
    final last = list.last;
    if (list.length == last - first + 1) return '第 $first-$last 周';
    if (oddEven == 1) return '第 $first-$last 周 · 单周';
    if (oddEven == 2) return '第 $first-$last 周 · 双周';
    return '${list.join('、')} 周';
  }

  ({int start, int end})? get clockRange {
    final start = _minutes(startClock);
    var end = _minutes(endClock);
    if (start == null) return null;
    end ??= start + 45;
    if (end <= start) end = start + 45;
    return (start: start, end: end);
  }

  static int? _minutes(String time) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'room': room,
    'teacher': teacher,
    'code': code,
    'day': day,
    'startSection': startSection,
    'span': span,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'startTime': startTime,
    'endTime': endTime,
    'oddEven': oddEven,
    'weeks': weeks,
    'source': source,
    'updatedAt': updatedAt,
  };

  factory CapCourse.fromJson(Map<String, dynamic> json) {
    final course = CapCourse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      room: json['room'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      code: json['code'] as String? ?? '',
      day: (json['day'] as num?)?.toInt() ?? 1,
      startSection: (json['startSection'] as num?)?.toInt() ?? 1,
      span: (json['span'] as num?)?.toInt() ?? 2,
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      endWeek: (json['endWeek'] as num?)?.toInt() ?? 18,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      oddEven: (json['oddEven'] as num?)?.toInt() ?? 0,
      weeks: ((json['weeks'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      source: json['source'] as String? ?? 'manual',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
    course.alignSectionsToTimes();
    course.alignTimesToPeriods();
    return course;
  }
}

int _clockToMinutes(String? value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value ?? '');
  if (match == null) return -1;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

int _normalizePlaceholderSection(int num) {
  if (num <= 4) return num;
  if (num == 5) return 4;
  if (num <= 9) return num - 1;
  if (num == 10) return 8;
  return num - 2;
}

/// 用上课时间在校历节次表里反查节次，纠正教务的占位行号/编号体系差异。
List<CapCourse> anchorCoursesByTime(
  List<CapCourse> list, [
  List<CapPeriod> periods = capPeriods,
]) {
  final table = periods.where((p) => _clockToMinutes(p.start) >= 0).toList();
  if (table.isEmpty) return list;
  final maxNum = table.fold<int>(0, (peak, p) => math.max<int>(peak, p.num));
  CapPeriod? nearest(int minutes, bool useStart) {
    CapPeriod? hit;
    var best = 31;
    for (final item in table) {
      final target = _clockToMinutes(useStart ? item.start : item.end);
      if (target < 0) continue;
      final diff = (target - minutes).abs();
      if (diff < best) {
        best = diff;
        hit = item;
      }
    }
    return hit;
  }

  return list.map((course) {
    final startMinutes = _clockToMinutes(course.startTime);
    if (startMinutes < 0) {
      final start = course.startSection;
      final int end = start + math.max<int>(1, course.span) - 1;
      if (start > 0 && end > maxNum) {
        final fixedStart = _normalizePlaceholderSection(start);
        final fixedEnd = math.min<int>(
          _normalizePlaceholderSection(end),
          maxNum,
        );
        if (fixedStart >= 1 && fixedEnd >= fixedStart) {
          course.startSection = fixedStart;
          course.span = fixedEnd - fixedStart + 1;
        }
      }
      return course;
    }
    final startHit = nearest(startMinutes, true);
    if (startHit == null) return course;
    final startSection = startHit.num;
    final endMinutes = _clockToMinutes(course.endTime);
    var span = math.max(1, course.span);
    if (endMinutes >= 0) {
      final endHit = nearest(endMinutes, false);
      if (endHit != null && endHit.num >= startSection) {
        span = endHit.num - startSection + 1;
      }
    }
    course
      ..startSection = startSection
      ..span = span;
    return course;
  }).toList();
}
