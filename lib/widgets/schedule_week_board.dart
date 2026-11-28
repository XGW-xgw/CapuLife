import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/cap_course.dart';
import '../theme.dart';
import 'cap_icon.dart';
import 'pressable.dart';

class ScheduleWeekDay {
  const ScheduleWeekDay({
    required this.day,
    required this.label,
    required this.date,
    required this.isToday,
  });

  final int day;
  final String label;
  final DateTime date;
  final bool isToday;
}

class ScheduleWeekGroup {
  const ScheduleWeekGroup({
    required this.start,
    required this.end,
    required this.courses,
    required this.primary,
  });

  final int start;
  final int end;
  final List<CapCourse> courses;
  final CapCourse primary;
}

class ScheduleWeekBoard extends StatelessWidget {
  const ScheduleWeekBoard({
    super.key,
    required this.week,
    required this.weekDays,
    required this.courses,
    required this.onDayTap,
    required this.onCourseTap,
    required this.onGroupTap,
  });

  final int week;
  final List<ScheduleWeekDay> weekDays;
  final List<CapCourse> courses;
  final ValueChanged<int> onDayTap;
  final ValueChanged<CapCourse> onCourseTap;
  final ValueChanged<List<CapCourse>> onGroupTap;

  List<CapCourse> _coursesFor(int day) {
    final list = courses
        .where((course) => course.day == day && course.isInWeek(week))
        .toList()
      ..sort((a, b) {
        final startA = math.max(1, a.startSection);
        final startB = math.max(1, b.startSection);
        if (startA != startB) return startA.compareTo(startB);
        return a.name.compareTo(b.name);
      });
    return list;
  }

  List<ScheduleWeekGroup> _group(List<CapCourse> input) {
    final groups = <ScheduleWeekGroup>[];
    for (final course in input) {
      final start = math.max(1, course.startSection);
      final span = math.max(1, course.span);
      final end = start + span - 1;
      final hits = groups
          .where((group) => start <= group.end && end >= group.start)
          .toList();
      if (hits.isEmpty) {
        groups.add(
          ScheduleWeekGroup(
            start: start,
            end: end,
            courses: [course],
            primary: course,
          ),
        );
        continue;
      }
      var mergedStart = start;
      var mergedEnd = end;
      final mergedCourses = <CapCourse>[course];
      for (final group in hits) {
        mergedStart = math.min(mergedStart, group.start);
        mergedEnd = math.max(mergedEnd, group.end);
        mergedCourses.addAll(group.courses);
        groups.remove(group);
      }
      mergedCourses.sort(
        (a, b) => math.max(1, b.span).compareTo(math.max(1, a.span)),
      );
      groups.add(
        ScheduleWeekGroup(
          start: mergedStart,
          end: mergedEnd,
          courses: mergedCourses,
          primary: mergedCourses.first,
        ),
      );
    }
    groups.sort((a, b) => a.start.compareTo(b.start));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = capRpx(context, 76);
    final groupsByDay = <int, List<ScheduleWeekGroup>>{
      for (final day in weekDays) day.day: _group(_coursesFor(day.day)),
    };
    final range = weekDays.isEmpty
        ? ''
        : '${weekDays.first.date.day} – ${weekDays.last.date.day} 日';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 14),
          capRpx(context, 16),
          capRpx(context, 14),
          capRpx(context, 18),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
          border: Border.all(color: AppColors.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: capRpx(context, 24),
              offset: Offset(0, capRpx(context, 10)),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(bottom: capRpx(context, 8)),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.line, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: capRpx(context, 56),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: capRpx(context, 3)),
                        child: Text(
                          '节次',
                          style: TextStyle(
                            fontSize: capRpx(context, 13),
                            color: AppColors.mutedSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < weekDays.length; i += 1) ...[
                    if (i > 0) SizedBox(width: capRpx(context, 4)),
                    Expanded(
                      child: Pressable(
                        onTap: () => onDayTap(weekDays[i].day),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            0,
                            capRpx(context, 4),
                            0,
                            capRpx(context, 2),
                          ),
                          decoration: BoxDecoration(
                            color: weekDays[i].isToday
                                ? AppColors.accent.withValues(alpha: 0.055)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              capRpx(context, 10),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                weekDays[i].label,
                                style: TextStyle(
                                  fontSize: capRpx(context, 15),
                                  fontWeight: FontWeight.w700,
                                  color: weekDays[i].isToday
                                      ? AppColors.accent
                                      : AppColors.muted,
                                ),
                              ),
                              Text(
                                '${weekDays[i].date.day}',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: capRpx(context, 17),
                                  fontWeight: FontWeight.w800,
                                  color: weekDays[i].isToday
                                      ? AppColors.accent
                                      : AppColors.ink,
                                ),
                              ),
                              Container(
                                width: capRpx(context, 4),
                                height: capRpx(context, 4),
                                decoration: BoxDecoration(
                                  color:
                                      (groupsByDay[weekDays[i].day] ?? const [])
                                              .isNotEmpty
                                          ? AppColors.gold
                                          : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: capRpx(context, 8)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: capRpx(context, 48),
                  child: Column(
                    children: [
                      for (final period in capPeriods)
                        SizedBox(
                          height: rowHeight,
                          child: Padding(
                            padding: EdgeInsets.only(top: capRpx(context, 6)),
                            child: Column(
                              children: [
                                Text(
                                  '${period.num}',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: capRpx(context, 16),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.muted,
                                  ),
                                ),
                                Text(
                                  period.start,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: capRpx(context, 12),
                                    color: AppColors.mutedSoft,
                                    height: 1.3,
                                  ),
                                ),
                                Opacity(
                                  opacity: 0.58,
                                  child: Text(
                                    period.end,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: capRpx(context, 12),
                                      color: AppColors.mutedSoft,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var dayIndex = 0;
                    dayIndex < weekDays.length;
                    dayIndex += 1) ...[
                  SizedBox(width: capRpx(context, 4)),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: weekDays[dayIndex].isToday
                            ? AppColors.accent.withValues(alpha: 0.045)
                            : const Color(0x73F5F2EA),
                        borderRadius: BorderRadius.circular(capRpx(context, 12)),
                      ),
                      child: SizedBox(
                        height: rowHeight * capPeriods.length,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _WeekGridLinePainter(
                                  rows: capPeriods.length,
                                  rowHeight: rowHeight,
                                  color: AppColors.ink.withValues(alpha: 0.055),
                                ),
                              ),
                            ),
                            for (final group
                                in groupsByDay[weekDays[dayIndex].day] ??
                                    const <ScheduleWeekGroup>[])
                              Positioned(
                                top: (group.start - 1) * rowHeight,
                                left: capRpx(context, 2),
                                right: capRpx(context, 2),
                                height:
                                    (group.end - group.start + 1) * rowHeight -
                                    capRpx(context, 8),
                                child: Pressable(
                                  onTap: () => onGroupTap(group.courses),
                                  child: Container(
                                    clipBehavior: Clip.hardEdge,
                                    padding: EdgeInsets.fromLTRB(
                                      capRpx(context, 5),
                                      capRpx(
                                        context,
                                        group.courses.length > 1 ? 14 : 6,
                                      ),
                                      capRpx(context, 5),
                                      capRpx(context, 6),
                                    ),
                                    decoration: BoxDecoration(
                                      color: coursePaletteFor(group.primary.name)
                                          .bg,
                                      borderRadius: BorderRadius.circular(
                                        capRpx(context, 9),
                                      ),
                                      border: Border(
                                        left: BorderSide(
                                          color: coursePaletteFor(
                                            group.primary.name,
                                          ).line,
                                          width: capRpx(context, 3),
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                          offset: const Offset(0, 1),
                                        ),
                                        if (group.courses.length > 1)
                                          BoxShadow(
                                            color: AppColors.ink.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: capRpx(context, 12),
                                            offset: Offset(
                                              0,
                                              capRpx(context, 4),
                                            ),
                                          ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.primary.name,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: capRpx(context, 15),
                                                fontWeight: FontWeight.w800,
                                                height: 1.25,
                                                color: coursePaletteFor(
                                                  group.primary.name,
                                                ).ink,
                                              ),
                                            ),
                                            if (group.primary.room.isNotEmpty)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: capRpx(context, 2),
                                                ),
                                                child: Text(
                                                  group.primary.room,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: capRpx(context, 11),
                                                    color: coursePaletteFor(
                                                      group.primary.name,
                                                    ).ink.withValues(alpha: 0.66),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (group.courses.length > 1)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              constraints: BoxConstraints(
                                                minWidth: capRpx(context, 22),
                                                minHeight: capRpx(context, 20),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: capRpx(context, 4),
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: AppColors.ink.withValues(
                                                  alpha: 0.72,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '+${group.courses.length - 1}',
                                                style: TextStyle(
                                                  fontSize: capRpx(context, 13),
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.2,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: capRpx(context, 14)),
            Row(
              children: [
                Container(
                  width: capRpx(context, 8),
                  height: capRpx(context, 8),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: capRpx(context, 8)),
                Text(
                  '左右滑动换周 · 点课程看详情',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: AppColors.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  range,
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekGridLinePainter extends CustomPainter {
  const _WeekGridLinePainter({
    required this.rows,
    required this.rowHeight,
    required this.color,
  });

  final int rows;
  final double rowHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var row = 0; row < rows; row += 1) {
      final y = row * rowHeight + 0.5;
      var x = 0.0;
      while (x < size.width) {
        final end = math.min(x + 4, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeekGridLinePainter old) =>
      old.rows != rows || old.rowHeight != rowHeight || old.color != color;
}

class WeekGroupCourseTile extends StatelessWidget {
  const WeekGroupCourseTile({
    super.key,
    required this.course,
    required this.onTap,
  });

  final CapCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = coursePaletteFor(course.name);
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: capRpx(context, 10)),
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 16),
          vertical: capRpx(context, 14),
        ),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(capRpx(context, 18)),
          border: Border.all(
            color: palette.line.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: capRpx(context, 4),
              height: capRpx(context, 42),
              decoration: BoxDecoration(
                color: palette.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(width: capRpx(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: capRpx(context, 24),
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 3)),
                  Text(
                    [
                      course.room,
                      course.teacher,
                      course.sectionText,
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      color: palette.ink.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            CapIcon(
              'chevron-right',
              size: capRpx(context, 22),
              color: palette.ink.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
