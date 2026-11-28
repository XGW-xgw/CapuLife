const weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

String pad2(int value) => value.toString().padLeft(2, '0');

DateTime startOfDay(DateTime input) =>
    DateTime(input.year, input.month, input.day);

DateTime? parseDateKey(String? input) {
  if (input == null || input.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(input);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String formatDateKey([DateTime? input]) {
  final date = input ?? DateTime.now();
  return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
}

String formatDateCN(
  DateTime input, {
  bool withYear = false,
  bool withWeekday = false,
  bool pad = false,
}) {
  final month = pad ? pad2(input.month) : '${input.month}';
  final day = pad ? pad2(input.day) : '${input.day}';
  final base = '${withYear ? '${input.year}年' : ''}$month月$day日';
  return withWeekday ? '$base 星期${weekLabels[input.weekday % 7]}' : base;
}

String weekdayCN(DateTime input) => '星期${weekLabels[input.weekday % 7]}';

int diffDays(String target, {DateTime? base}) {
  final a = parseDateKey(target);
  if (a == null) return 0;
  final b = startOfDay(base ?? DateTime.now());
  return a.difference(b).inDays;
}

class CountdownText {
  const CountdownText({
    required this.days,
    required this.label,
    required this.suffix,
    required this.state,
  });

  final int days;
  final String label;
  final String suffix;
  final String state;
}

CountdownText countdownText(String target, {DateTime? base}) {
  final days = diffDays(target, base: base);
  if (days > 0) {
    return CountdownText(days: days, label: '还有', suffix: '天', state: 'future');
  }
  if (days == 0) {
    return const CountdownText(days: 0, label: '就是', suffix: '今天', state: 'today');
  }
  return CountdownText(
    days: days.abs(),
    label: '已经',
    suffix: '天前',
    state: 'past',
  );
}

String formatDateCNFromKey(String input, {bool withWeekday = false}) {
  final date = parseDateKey(input);
  if (date == null) return input;
  return formatDateCN(date, withWeekday: withWeekday);
}

String formatRelativeTime(int timestamp) {
  if (timestamp == 0) return '';
  final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
  if (diff < 60000) return '刚刚';
  if (diff < 3600000) return '${(diff / 60000).floor()} 分钟前';
  if (diff < 86400000) return '${(diff / 3600000).floor()} 小时前';
  if (diff < 86400000 * 7) return '${(diff / 86400000).floor()} 天前';
  return formatDateCN(DateTime.fromMillisecondsSinceEpoch(timestamp));
}

String clockText(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${pad2(date.hour)}:${pad2(date.minute)}';
}

String minutesAgo(int minutes) => '$minutes 分钟前';

DateTime? parseClock(String? value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value ?? '');
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return DateTime(2000, 1, 1, hour, minute);
}

String greetingFor(DateTime date) {
  final hour = date.hour;
  if (hour < 5) return '夜深了';
  if (hour < 9) return '早上好';
  if (hour < 12) return '上午好';
  if (hour < 14) return '中午好';
  if (hour < 18) return '下午好';
  if (hour < 23) return '晚上好';
  return '夜深了';
}

String greetingNoteFor(DateTime date) {
  final hour = date.hour;
  if (hour < 9) return '早一点出发，校园的风还没醒。';
  if (hour < 12) return '把要紧的事排在前面，剩下的慢慢来。';
  if (hour < 18) return '今天的光线很好，适合完成一件小事。';
  return '把今天收好，明天还有新的航线。';
}

String heroTimeOfDay(DateTime date) {
  final hour = date.hour;
  if (hour >= 5 && hour < 9) return 'dawn';
  if (hour >= 9 && hour < 17) return 'day';
  if (hour >= 17 && hour < 20) return 'dusk';
  return 'night';
}

class SemesterWeekInfo {
  const SemesterWeekInfo({
    required this.week,
    required this.phase,
    required this.progress,
    required this.totalWeeks,
  });

  final int week;
  final String phase;
  final double progress;
  final int totalWeeks;
}

SemesterWeekInfo semesterWeek(
  String semesterStart,
  int totalWeeks, {
  DateTime? date,
}) {  final start = parseDateKey(semesterStart);
  final today = startOfDay(date ?? DateTime.now());
  if (start == null) {
    return SemesterWeekInfo(
      week: 1,
      phase: 'active',
      progress: 0,
      totalWeeks: totalWeeks,
    );
  }
  final startMonday = start.subtract(Duration(days: (start.weekday + 6) % 7));
  final dayDiff = today.difference(startOfDay(startMonday)).inDays;
  final week = (dayDiff / 7).floor() + 1;
  if (dayDiff < 0) {
    return SemesterWeekInfo(
      week: 0,
      phase: 'before',
      progress: 0,
      totalWeeks: totalWeeks,
    );
  }
  if (week > totalWeeks) {
    return SemesterWeekInfo(
      week: week,
      phase: 'after',
      progress: 1,
      totalWeeks: totalWeeks,
    );
  }
  return SemesterWeekInfo(
    week: week,
    phase: 'active',
    progress: (week / (totalWeeks == 0 ? 1 : totalWeeks)).clamp(0, 1),
    totalWeeks: totalWeeks,
  );
}

DateTime semesterStartForNow([DateTime? now]) {
  final value = now ?? DateTime.now();
  final year = value.year;
  final month = value.month;
  DateTime date;
  if (month >= 8) {
    // The original uses JS month 8 (September) for the autumn semester.
    date = DateTime(year, 9, 1);
  } else if (month <= 1) {
    date = DateTime(year - 1, 9, 1);
  } else {
    // JS month 1 = February in the original source.
    date = DateTime(year, 2, 24);
  }
  final offset = (date.weekday + 6) % 7;
  return date.subtract(Duration(days: offset));
}

DateTime nextCetDate([DateTime? now]) {
  final value = now ?? DateTime.now();
  final candidates = <DateTime>[];
  for (final year in [value.year, value.year + 1]) {
    // JS months 5 and 11 are June and December.
    for (final month in [6, 12]) {
      final first = DateTime(year, month, 1);
      final jsDay = first.weekday % 7;
      final offset = (6 - jsDay + 7) % 7;
      candidates.add(DateTime(year, month, 1 + offset + 14));
    }
  }
  final today = startOfDay(value);
  return candidates.firstWhere(
    (date) => !date.isBefore(today),
    orElse: () => candidates.last,
  );
}

DateTime weekStartDate(String semesterStart, int week) {
  final start = parseDateKey(semesterStart) ?? startOfDay(DateTime.now());
  final monday = start.subtract(Duration(days: (start.weekday + 6) % 7));
  return monday.add(Duration(days: (week.clamp(1, 53) - 1) * 7));
}

DateTime dateForWeekDay(String semesterStart, int week, int weekday) {
  final monday = weekStartDate(semesterStart, week);
  return monday.add(Duration(days: weekday.clamp(1, 7) - 1));
}
