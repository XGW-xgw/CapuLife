import 'dart:async';

import 'package:flutter/services.dart';

import '../data/cap_store.dart';
import '../utils/cap_date.dart';

class CapReminders {
  static const _channel = MethodChannel('capulife/notifications');

  static int requestCodeFor(String key) {
    var hash = 0x811c9dc5;
    for (final code in key.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static Future<void> schedule({
    required String key,
    required String title,
    required String content,
    required int at,
  }) async {
    if (at <= DateTime.now().millisecondsSinceEpoch) {
      await cancel(key);
      return;
    }
    try {
      await _channel.invokeMethod('schedule', {
        'id': requestCodeFor(key),
        'at': at,
        'title': title,
        'content': content,
      });
    } catch (_) {}
  }

  static Future<void> cancel(String key) async {
    try {
      await _channel.invokeMethod('cancel', {'id': requestCodeFor(key)});
    } catch (_) {}
  }

  static int? todoReminderAt(CapTodo item) {
    if (!item.reminder || item.done) return null;
    var at = item.reminderAt;
    if (at == 0 && item.dueDate.isNotEmpty) {
      final date = parseDateKey(item.dueDate);
      final clock = parseClock(item.dueTime.isEmpty ? '09:00' : item.dueTime);
      if (date != null) {
        at = DateTime(
          date.year,
          date.month,
          date.day,
          clock?.hour ?? 9,
          clock?.minute ?? 0,
        ).millisecondsSinceEpoch;
      }
    }
    return at == 0 ? null : at;
  }

  static String todoKey(String id) => 'todo:$id';

  static Future<void> syncTodo(CapTodo item) async {
    final at = todoReminderAt(item);
    final key = todoKey(item.id);
    if (at == null) {
      await cancel(key);
      return;
    }
    await schedule(
      key: key,
      title: '待办提醒',
      content: item.title,
      at: at,
    );
  }

  static int? countdownReminderAt(CapCountdown item) {
    if (!item.reminder) return null;
    final date = parseDateKey(item.targetDate);
    if (date == null) return null;
    final clock = parseClock(item.reminderTime.isEmpty ? '20:00' : item.reminderTime);
    return DateTime(
      date.year,
      date.month,
      date.day - item.leadDays.clamp(0, 30),
      clock?.hour ?? 20,
      clock?.minute ?? 0,
    ).millisecondsSinceEpoch;
  }

  static String countdownKey(String id) => 'cd:$id';

  static Future<void> syncCountdown(CapCountdown item) async {
    final at = countdownReminderAt(item);
    final key = countdownKey(item.id);
    if (at == null) {
      await cancel(key);
      return;
    }
    final dayLabel = item.leadDays > 0 ? '还有 ${item.leadDays} 天' : '就是今天';
    await schedule(
      key: key,
      title: item.title,
      content: '$dayLabel · ${item.targetDate.replaceAll('-', '/')} ${item.targetTime}'.trim(),
      at: at,
    );
  }

  static Future<void> syncCourseReminders(CapStore store) async {
    final now = DateTime.now();
    for (var offset = 0; offset <= 7; offset += 1) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final info = store.weekInfoAt(date);
      if (info.phase != 'active') continue;
      final courses = store.coursesForDay(info.week, date.weekday);
      for (final course in courses) {
        final clock = parseClock(course.startClock);
        if (clock == null) continue;
        final at = DateTime(
          date.year,
          date.month,
          date.day,
          clock.hour,
          clock.minute,
        ).subtract(const Duration(minutes: 15));
        if (!at.isAfter(now)) continue;
        await schedule(
          key: 'course:${course.id}:${formatDateKey(date)}',
          title: '上课提醒',
          content:
              '${course.name}${course.room.isEmpty ? '' : ' · ${course.room}'} · 15 分钟后上课',
          at: at.millisecondsSinceEpoch,
        );
      }
    }
  }

  /// Re-arms upcoming reminders after a cold start or an app update.
  static Future<void> warmStart(CapStore store) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final horizon = now + const Duration(days: 30).inMilliseconds;
    for (final item in store.countdowns) {
      final at = countdownReminderAt(item);
      if (at != null && at > now && at < horizon) {
        await syncCountdown(item);
      }
    }
    for (final item in store.todos) {
      if (item.done) continue;
      final at = todoReminderAt(item);
      if (at != null && at > now && at < horizon) {
        await syncTodo(item);
      }
    }
    await syncCourseReminders(store);
  }
}
