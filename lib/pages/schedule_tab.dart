import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/cap_course.dart';
import '../data/cap_store.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_reveal.dart';
import '../widgets/pressable.dart';
import '../widgets/schedule_week_board.dart';
import 'academic_sync_page.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  DateTime _now = DateTime.now();
  int _week = 1;
  int _day = 1;
  bool _weekMode = false;
  int _contentDirection = 1;
  bool _initialized = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final store = CapScope.of(context);
    final info = store.weekInfoAt(_now);
    _week = _initialWeek(info);
    _day = _now.weekday;
    _initialized = true;
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  static int _initialWeek(SemesterWeekInfo info) {
    if (info.phase == 'before') return 1;
    if (info.phase == 'after') return info.totalWeeks;
    return info.week.clamp(1, math.max(1, info.totalWeeks));
  }

  int _clampWeek(CapStore store, int week) =>
      week.clamp(1, math.max(1, store.settings.totalWeeks));

  void _selectDay(int day) {
    final next = day.clamp(1, 7);
    if (next == _day) return;
    setState(() {
      _contentDirection = next > _day ? 1 : -1;
      _day = next;
    });
  }

  void _changeWeek(CapStore store, int delta) {
    final next = _clampWeek(store, _week + delta);
    if (next == _week) return;
    setState(() {
      _contentDirection = delta > 0 ? 1 : -1;
      _week = next;
    });
  }

  void _backToToday(CapStore store) {
    final info = store.weekInfoAt(_now);
    setState(() {
      _contentDirection = 1;
      _week = _initialWeek(info);
      _day = _now.weekday;
      _weekMode = false;
    });
  }

  void _swipeSchedule(CapStore store, double velocity) {
    if (velocity.abs() < 120) return;
    if (_weekMode) {
      _changeWeek(store, velocity < 0 ? 1 : -1);
    } else {
      _selectDay(_day + (velocity < 0 ? 1 : -1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final info = store.weekInfoAt(_now);
    final semesterLabel = (store.scheduleMeta['semesterName'] as String? ?? '')
        .trim();
    final phaseLabel = semesterLabel.isNotEmpty
        ? semesterLabel
        : info.phase == 'before'
        ? '未开学'
        : info.phase == 'after'
        ? '已结课'
        : '进行中';
    final weekDays = List.generate(7, (index) {
      final date = dateForWeekDay(
        store.settings.semesterStart,
        _week,
        index + 1,
      );
      return _DayInfo(
        day: index + 1,
        label: capWeekLabelsShort[index],
        date: date,
        isToday:
            date.year == _now.year &&
            date.month == _now.month &&
            date.day == _now.day,
      );
    });
    final dayCourses = store.coursesForDay(_week, _day);
    final weeklyCount = store.weekInfoAt(_now).phase == 'active'
        ? store.courses.where((course) => course.isInWeek(_week)).length
        : 0;
    final weekRange = weekDays.isEmpty
        ? ''
        : '${weekDays.first.date.day} – ${weekDays.last.date.day} 日';
    final selectedDate = dateForWeekDay(
      store.settings.semesterStart,
      _week,
      _day,
    );
    final isCurrentWeek =
        info.phase == 'active' && _week == info.week;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: safeTop + 10,
        bottom: safeBottom + capRpx(context, 230),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 36)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIMETABLE · $phaseLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w700,
                        letterSpacing: capRpx(context, 20) * 0.18,
                        color: AppColors.muted,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    Text(
                      '课表',
                      style: TextStyle(
                        fontSize: capRpx(context, 60),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, 60) * -0.04,
                        height: 1.05,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 20)),
              Row(
                children: [
                  _circleAction(
                    context,
                    icon: 'plus',
                    onTap: () => _openManual(store),
                  ),
                  SizedBox(width: capRpx(context, 12)),
                  _circleAction(
                    context,
                    icon: 'settings',
                    onTap: () => _openSettings(store),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            capRpx(context, 28),
            capRpx(context, 24),
            capRpx(context, 28),
            0,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Pressable(
                    onTap: () => _pickWeek(store),
                    child: AnimatedContainer(
                      duration: capsuleMotionFast,
                      curve: capsuleSpringCurve,
                      height: capRpx(context, 46),
                      padding: EdgeInsets.symmetric(
                        horizontal: capRpx(context, 14),
                      ),
                      decoration: BoxDecoration(
                        color: isCurrentWeek
                            ? AppColors.accentSoft
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isCurrentWeek
                              ? AppColors.accent.withValues(alpha: 0.22)
                              : AppColors.line,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '第 $_week 周',
                            style: TextStyle(
                              fontSize: capRpx(context, 21),
                              fontWeight: FontWeight.w800,
                              letterSpacing: capRpx(context, 21) * -0.02,
                              color: isCurrentWeek
                                  ? AppColors.accent
                                  : AppColors.ink,
                            ),
                          ),
                          CapIcon(
                            'chevron-down',
                            size: capRpx(context, 21),
                            color: isCurrentWeek
                                ? AppColors.accent
                                : AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: capRpx(context, 10)),
                  _weekArrow(
                    context,
                    icon: 'chevron-left',
                    onTap: () => _changeWeek(store, -1),
                  ),
                  SizedBox(width: capRpx(context, 4)),
                  _weekArrow(
                    context,
                    icon: 'chevron-right',
                    onTap: () => _changeWeek(store, 1),
                  ),
                  if (!isCurrentWeek) ...[
                    SizedBox(width: capRpx(context, 8)),
                    Pressable(
                      onTap: () => _backToToday(store),
                      child: Container(
                        height: capRpx(context, 40),
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 11),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            CapIcon(
                              'target',
                              size: capRpx(context, 18),
                              color: AppColors.accent,
                            ),
                            SizedBox(width: capRpx(context, 5)),
                            Text(
                              '本周',
                              style: TextStyle(
                                fontSize: capRpx(context, 17),
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Pressable(
                    onTap: () => _showSyncNotice(context),
                    child: Container(
                      height: capRpx(context, 42),
                      padding: EdgeInsets.symmetric(
                        horizontal: capRpx(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          CapIcon(
                            'download',
                            size: capRpx(context, 18),
                            color: AppColors.accent,
                          ),
                          SizedBox(width: capRpx(context, 4)),
                          Text(
                            '同步',
                            style: TextStyle(
                              fontSize: capRpx(context, 17),
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: capRpx(context, 12)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$weekRange · $weeklyCount 门课',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.muted,
                        letterSpacing: capRpx(context, 17) * 0.01,
                      ),
                    ),
                  ),
                  _Segmented(
                    weekMode: _weekMode,
                    onChanged: (value) => setState(() {
                      _contentDirection = 1;
                      _weekMode = value;
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!_weekMode) _daySelector(context, weekDays),
        _animatedScheduleBody(
          context,
          store,
          weekDays,
          dayCourses,
          selectedDate,
          isCurrentWeek,
        ),
        SizedBox(height: capRpx(context, 28)),
        Center(
          child: Text(
            '课表数据来自学校教务系统，仅保存在本机',
            style: TextStyle(
              fontSize: capRpx(context, 18),
              color: AppColors.mutedSoft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleAction(
    BuildContext context, {
    required String icon,
    required VoidCallback onTap,
  }) {
    final size = capRpx(context, 68);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: capRpx(context, 14),
              offset: Offset(0, capRpx(context, 4)),
            ),
          ],
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 29), color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _weekArrow(
    BuildContext context, {
    required String icon,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 46),
        height: capRpx(context, 46),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.line, width: 1),
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 24), color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _daySelector(BuildContext context, List<_DayInfo> weekDays) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 4),
        capRpx(context, 28),
        capRpx(context, 16),
      ),
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 8)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 22)),
          border: Border.all(color: AppColors.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: capRpx(context, 14),
              offset: Offset(0, capRpx(context, 4)),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / weekDays.length;
            final active = (_day - 1).clamp(0, weekDays.length - 1);
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: capsuleMotion,
                  curve: capsuleSpringCurve,
                  left: active * cellWidth,
                  top: 0,
                  bottom: 0,
                  width: cellWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(capRpx(context, 16)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.16),
                          blurRadius: capRpx(context, 18),
                          offset: Offset(0, capRpx(context, 8)),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final day in weekDays)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectDay(day.day),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: capRpx(context, 10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  day.label,
                                  style: TextStyle(
                                    fontSize: capRpx(context, 18),
                                    fontWeight: FontWeight.w600,
                                    color: _day == day.day
                                        ? Colors.white
                                        : AppColors.muted,
                                  ),
                                ),
                                SizedBox(height: capRpx(context, 5)),
                                Text(
                                  '${day.date.day}',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: capRpx(context, 30),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: capRpx(context, 30) * -0.04,
                                    color: _day == day.day
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: capRpx(context, 5)),
                                Container(
                                  width: capRpx(context, 5),
                                  height: capRpx(context, 5),
                                  decoration: BoxDecoration(
                                    color: day.isToday
                                        ? (_day == day.day
                                              ? AppColors.gold
                                              : AppColors.mint)
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _animatedScheduleBody(
    BuildContext context,
    CapStore store,
    List<_DayInfo> weekDays,
    List<CapCourse> dayCourses,
    DateTime selectedDate,
    bool isCurrentWeek,
  ) {
    final key = ValueKey(
      '${_weekMode ? 'week' : 'day'}-$_week-$_day',
    );
    final content = _weekMode
        ? _weekView(context, store, weekDays, isCurrentWeek)
        : _dayView(context, store, weekDays, dayCourses, selectedDate);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) =>
          _swipeSchedule(store, details.primaryVelocity ?? 0),
      child: AnimatedSwitcher(
        duration: capsuleMotion,
        switchInCurve: capsuleSpringCurve,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(_contentDirection * 0.07, 0.01),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: key, child: content),
      ),
    );
  }

  Widget _dayView(
    BuildContext context,
    CapStore store,
    List<_DayInfo> weekDays,
    List<CapCourse> courses,
    DateTime selectedDate,
  ) {
    final selected = weekDays[_day - 1];
    final title =
        '周${selected.label} · ${formatDateCN(selectedDate)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 4),
        capRpx(context, 28),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: capRpx(context, 30),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, 30) * -0.02,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 4)),
                    Text(
                      courses.isEmpty
                          ? '这一天还没有课程'
                          : '${courses.length} 个课程安排',
                      style: TextStyle(
                        fontSize: capRpx(context, 19),
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: () => _openManual(store),
                child: Container(
                  width: capRpx(context, 52),
                  height: capRpx(context, 52),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line, width: 1),
                  ),
                  child: Center(
                    child: CapIcon(
                      'plus',
                      size: capRpx(context, 25),
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 16)),
          if (courses.isEmpty)
            _emptyDay(context, store)
          else
            for (var i = 0; i < courses.length; i += 1)
              CapReveal(
                index: i,
                offset: const Offset(0, 10),
                child: _dayCourseCard(context, store, courses[i]),
              ),
          SizedBox(height: capRpx(context, 18)),
          Row(
            children: [
              CapIcon(
                'info',
                size: capRpx(context, 22),
                color: AppColors.mutedSoft,
              ),
              SizedBox(width: capRpx(context, 8)),
              Text(
                '左右滑动切换日期，周次与真实教学周同步。',
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyDay(BuildContext context, CapStore store) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 30),
        capRpx(context, 28),
        capRpx(context, 26),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 32)),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.075),
            blurRadius: capRpx(context, 34),
            offset: Offset(0, capRpx(context, 12)),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 112),
            height: capRpx(context, 112),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 34)),
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: capRpx(context, 68),
                  height: capRpx(context, 68),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          Text(
            store.courses.isEmpty ? '还没有同步课表' : '这一天没有排课',
            style: TextStyle(
              fontSize: capRpx(context, 30),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            store.courses.isEmpty
                ? '从 WebVPN 登录并进入教务系统后，点提取即可导入课表。'
                : '适合自习、休息，或者给自己加一节想学的课。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 20),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 22)),
          Row(
            children: [
              Expanded(
                child: _sheetAction(
                  context,
                  primary: true,
                  icon: 'download',
                  label: '从 WebVPN 同步',
                  onTap: () => _showSyncNotice(context),
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: _sheetAction(
                  context,
                  primary: false,
                  icon: 'plus',
                  label: '手动添加',
                  onTap: () => _openManual(store),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetAction(
    BuildContext context, {
    required bool primary,
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 66),
        decoration: BoxDecoration(
          color: primary ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 18)),
          border: Border.all(
            color: primary ? AppColors.ink : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CapIcon(
              icon,
              size: capRpx(context, 23),
              color: primary ? const Color(0xFFFFF8EA) : AppColors.ink,
            ),
            SizedBox(width: capRpx(context, 6)),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 21),
                fontWeight: FontWeight.w700,
                color: primary ? const Color(0xFFFFF8EA) : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCourseCard(
    BuildContext context,
    CapStore store,
    CapCourse course,
  ) {
    final palette = coursePaletteFor(course.name);
    final range = course.clockRange;
    final minutes = _now.hour * 60 + _now.minute;
    final isNow = range != null &&
        minutes >= range.start &&
        minutes <= range.end &&
        course.isInWeek(store.weekInfoAt(_now).week);
    final parts = course.timeText.split('–');
    final start = parts.first.trim();
    final end = parts.length > 1 ? parts[1].trim() : '';
    return Pressable(
      onTap: () => _openCourseDetail(store, course),
      child: Padding(
        padding: EdgeInsets.only(top: capRpx(context, 16)),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            capRpx(context, 16),
            capRpx(context, 16),
            capRpx(context, 16),
            capRpx(context, 16),
          ),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(capRpx(context, 24)),
            border: Border.all(color: palette.line.withValues(alpha: 0.16), width: 1),
            boxShadow: [
              BoxShadow(
                color: palette.line.withValues(alpha: 0.08),
                blurRadius: capRpx(context, 18),
                offset: Offset(0, capRpx(context, 8)),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: capRpx(context, 4),
                height: capRpx(context, 58),
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              SizedBox(
                width: capRpx(context, 82),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      start.isEmpty ? '—' : start,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    if (end.isNotEmpty)
                      Text(
                        end,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: capRpx(context, 17),
                          color: palette.ink.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: capRpx(context, 27),
                              fontWeight: FontWeight.w800,
                              letterSpacing: capRpx(context, 27) * -0.015,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        if (isNow)
                          Container(
                            height: capRpx(context, 34),
                            padding: EdgeInsets.symmetric(
                              horizontal: capRpx(context, 10),
                            ),
                            decoration: BoxDecoration(
                              color: palette.soft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: capRpx(context, 7),
                                  height: capRpx(context, 7),
                                  decoration: BoxDecoration(
                                    color: palette.line,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: capRpx(context, 5)),
                                Text(
                                  '进行中',
                                  style: TextStyle(
                                    fontSize: capRpx(context, 16),
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(width: capRpx(context, 8)),
                        Text(
                          course.sectionText,
                          style: TextStyle(
                            fontSize: capRpx(context, 17),
                            fontWeight: FontWeight.w600,
                            color: palette.ink.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: capRpx(context, 7)),
                    Row(
                      children: [
                        CapIcon(
                          'map-pin',
                          size: capRpx(context, 20),
                          color: palette.ink.withValues(alpha: 0.7),
                        ),
                        SizedBox(width: capRpx(context, 6)),
                        Expanded(
                          child: Text(
                            course.room.isEmpty ? '地点待定' : course.room,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: capRpx(context, 19),
                              color: palette.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: capRpx(context, 6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.teacher.isEmpty ? '教师未录入' : course.teacher,
                            style: TextStyle(
                              fontSize: capRpx(context, 18),
                              color: palette.ink.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Text(
                          course.weekText,
                          style: TextStyle(
                            fontSize: capRpx(context, 18),
                            color: palette.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekView(
    BuildContext context,
    CapStore store,
    List<_DayInfo> weekDays,
    bool isCurrentWeek,
  ) {
    return ScheduleWeekBoard(
      week: _week,
      weekDays: [
        for (final day in weekDays)
          ScheduleWeekDay(
            day: day.day,
            label: day.label,
            date: day.date,
            isToday: day.isToday,
          ),
      ],
      courses: store.courses,
      onDayTap: (day) {
        setState(() {
          _day = day;
          _weekMode = false;
        });
      },
      onCourseTap: (course) => _openCourseDetail(store, course),
      onGroupTap: (courses) => _openWeekGroup(store, courses),
    );
  }

  void _openWeekGroup(CapStore store, List<CapCourse> courses) {
    if (courses.isEmpty) return;
    if (courses.length == 1) {
      _openCourseDetail(store, courses.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _sheetShell(
        sheetContext,
        title: '这个时间有 ${courses.length} 门课',
        subtitle: '选择要查看的课程',
        child: Column(
          children: [
            for (final course in courses)
              WeekGroupCourseTile(
                course: course,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openCourseDetail(store, course);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWeek(CapStore store) async {
    final total = math.max(1, store.settings.totalWeeks);
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheetShell(
        context,
        title: '选择周次',
        subtitle: '共 $total 周',
        child: SizedBox(
          height: 360,
          child: ListView.builder(
            itemCount: total,
            itemBuilder: (context, index) => ListTile(
              title: Text('第 ${index + 1} 周'),
              trailing: index + 1 == _week
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(index + 1),
            ),
          ),
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() => _week = value);
    }
  }

  void _showSyncNotice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: capWebViewRouteName),
        builder: (_) => const AcademicSyncPage(),
      ),
    );
  }

  Future<void> _openSettings(CapStore store) async {
    var semesterStart = store.settings.semesterStart;
    var totalWeeks = store.settings.totalWeeks;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickDate() async {
            final current = parseDateKey(semesterStart) ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: current,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setSheetState(() => semesterStart = formatDateKey(picked));
            }
          }

          return _sheetShell(
            context,
            title: '课表设置',
            subtitle: '周次以开学第一周的周一为起点',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(context, '开学日期'),
                Pressable(
                  onTap: pickDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 16),
                      vertical: capRpx(context, 14),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(capRpx(context, 16)),
                      border: Border.all(color: AppColors.line, width: 1),
                    ),
                    child: Row(
                      children: [
                        CapIcon(
                          'calendar-days',
                          size: capRpx(context, 27),
                          color: AppColors.muted,
                        ),
                        SizedBox(width: capRpx(context, 10)),
                        Expanded(
                          child: Text(
                            semesterStart,
                            style: TextStyle(
                              fontSize: capRpx(context, 22),
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        CapIcon(
                          'chevron-right',
                          size: capRpx(context, 24),
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: capRpx(context, 22)),
                _fieldLabel(context, '学期总周数'),
                Row(
                  children: [
                    _stepperButton(
                      context,
                      icon: 'minus',
                      onTap: () => setSheetState(
                        () => totalWeeks = math.max(1, totalWeeks - 1),
                      ),
                    ),
                    SizedBox(
                      width: capRpx(context, 80),
                      child: Text(
                        '$totalWeeks',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: capRpx(context, 34),
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    _stepperButton(
                      context,
                      icon: 'plus',
                      onTap: () => setSheetState(
                        () => totalWeeks = math.min(30, totalWeeks + 1),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '当前第 $_week 周',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 22)),
                _fieldLabel(context, '课表数据'),
                Container(
                  padding: EdgeInsets.all(capRpx(context, 16)),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(capRpx(context, 16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (store.scheduleMeta['semesterName'] as String? ??
                                          '')
                                      .trim()
                                      .isEmpty
                                  ? '尚未同步'
                                  : '${store.scheduleMeta['semesterName']}',
                              style: TextStyle(
                                fontSize: capRpx(context, 21),
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: capRpx(context, 3)),
                            Text(
                              store.courses.isEmpty
                                  ? '还没有导入课表'
                                  : '本地共 ${store.courses.length} 门课',
                              style: TextStyle(
                                fontSize: capRpx(context, 18),
                                color: AppColors.mutedSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Pressable(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('清空课表'),
                              content: const Text('只会删除本机课表，不影响教务系统中的数据。'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('清空'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            store.clearCourses();
                            setSheetState(() {});
                          }
                        },
                        child: Container(
                          width: capRpx(context, 52),
                          height: capRpx(context, 52),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              capRpx(context, 14),
                            ),
                            border: Border.all(color: AppColors.line, width: 1),
                          ),
                          child: Center(
                            child: CapIcon(
                              'trash-2',
                              size: capRpx(context, 24),
                              color: AppColors.coral,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: capRpx(context, 24)),
                SizedBox(
                  width: double.infinity,
                  child: _sheetAction(
                    context,
                    primary: true,
                    icon: 'check',
                    label: '保存设置',
                    onTap: () {
                      store.updateSettings(
                        semesterStart: semesterStart,
                        totalWeeks: totalWeeks,
                      );
                      setState(() {
                        _week = _clampWeek(store, _week);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: capRpx(context, 8)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 19),
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _stepperButton(
    BuildContext context, {
    required String icon,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 56),
        height: capRpx(context, 56),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 16)),
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 25), color: AppColors.ink),
        ),
      ),
    );
  }

  Future<void> _openManual(CapStore store, {CapCourse? editing}) async {
    final result = await showModalBottomSheet<CapCourse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualCourseSheet(
        store: store,
        editing: editing,
        initialDay: _day,
      ),
    );
    if (result != null && mounted) {
      store.upsertCourse(result);
      setState(() {
        _day = result.day.clamp(1, 7);
        if (!result.isInWeek(_week)) _week = result.startWeek.clamp(1, 30);
      });
    }
  }

  Future<void> _openCourseDetail(CapStore store, CapCourse course) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheetShell(
        context,
        title: course.name,
        subtitle: course.sectionText,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(context, '上课时间',
                '周${capWeekLabelsShort[course.day - 1]} ${course.timeText}'),
            _detailRow(context, '上课地点', course.room.isEmpty ? '待定' : course.room),
            _detailRow(context, '任课教师',
                course.teacher.isEmpty ? '未录入' : course.teacher),
            _detailRow(context, '上课周次', course.weekText),
            _detailRow(context, '课程编号', course.code.isEmpty ? '未提供' : course.code),
            SizedBox(height: capRpx(context, 18)),
            Row(
              children: [
                Expanded(
                  child: _sheetAction(
                    context,
                    primary: false,
                    icon: 'x',
                    label: '关闭',
                    onTap: () => Navigator.of(context).pop('close'),
                  ),
                ),
                SizedBox(width: capRpx(context, 12)),
                Expanded(
                  child: _sheetAction(
                    context,
                    primary: true,
                    icon: 'pencil',
                    label: '编辑课程',
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 10)),
            Pressable(
              onTap: () => Navigator.of(context).pop('delete'),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  '删除本地课程',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: capRpx(context, 21),
                    fontWeight: FontWeight.w700,
                    color: AppColors.coral,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _openManual(store, editing: course);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除课程'),
          content: const Text('仅从本机课表移除，可重新同步恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
      if (ok == true) store.removeCourse(course.id);
    }
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: capRpx(context, 9)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: capRpx(context, 150),
            child: Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 20),
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: capRpx(context, 21),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayInfo {
  const _DayInfo({
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

class _Segmented extends StatelessWidget {
  const _Segmented({required this.weekMode, required this.onChanged});

  final bool weekMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(capRpx(context, 3)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: [
          _segItem(context, '周', weekMode, () => onChanged(true)),
          _segItem(context, '日', !weekMode, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segItem(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: capsuleMotionFast,
        curve: capsuleSpringCurve,
        width: capRpx(context, 54),
        height: capRpx(context, 38),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: capRpx(context, 18),
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

Widget _sheetShell(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
}) {
  return Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.86,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(capRpx(context, 30)),
      ),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 28),
          capRpx(context, 14),
          capRpx(context, 28),
          capRpx(context, 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: capRpx(context, 72),
                height: capRpx(context, 6),
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 18)),
            Text(
              title,
              style: TextStyle(
                fontSize: capRpx(context, 34),
                fontWeight: FontWeight.w800,
                letterSpacing: capRpx(context, 34) * -0.02,
                color: AppColors.ink,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 5)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: capRpx(context, 19),
                  color: AppColors.muted,
                ),
              ),
            ],
            SizedBox(height: capRpx(context, 20)),
            child,
          ],
        ),
      ),
    ),
  );
}

class _ManualCourseSheet extends StatefulWidget {
  const _ManualCourseSheet({
    required this.store,
    required this.initialDay,
    this.editing,
  });

  final CapStore store;
  final int initialDay;
  final CapCourse? editing;

  @override
  State<_ManualCourseSheet> createState() => _ManualCourseSheetState();
}

class _ManualCourseSheetState extends State<_ManualCourseSheet> {
  late final TextEditingController _name;
  late final TextEditingController _room;
  late final TextEditingController _teacher;
  late final TextEditingController _startWeek;
  late final TextEditingController _endWeek;
  late int _day;
  late int _startSection;
  late int _span;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _name = TextEditingController(text: editing?.name ?? '');
    _room = TextEditingController(text: editing?.room ?? '');
    _teacher = TextEditingController(text: editing?.teacher ?? '');
    _day = editing?.day ?? widget.initialDay.clamp(1, 7);
    _startSection = editing?.startSection ?? 1;
    _span = editing?.span ?? 2;
    _startWeek = TextEditingController(
      text: '${editing?.startWeek ?? 1}',
    );
    _endWeek = TextEditingController(
      text: '${editing?.endWeek ?? widget.store.settings.totalWeeks}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _teacher.dispose();
    _startWeek.dispose();
    _endWeek.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    final start = _startSection.clamp(1, capPeriods.length);
    final span = _span.clamp(1, capPeriods.length - start + 1);
    final startWeek = (int.tryParse(_startWeek.text.trim()) ?? 1).clamp(1, 30);
    final endWeek =
        (int.tryParse(_endWeek.text.trim()) ?? widget.store.settings.totalWeeks)
            .clamp(startWeek, 30);
    final startPeriod = capPeriods[start - 1];
    final endPeriod = capPeriods[start + span - 2];
    final existing = widget.editing;
    final now = DateTime.now().millisecondsSinceEpoch;
    final course = CapCourse(
      id: existing?.id ??
          'manual_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: _name.text.trim(),
      room: _room.text.trim(),
      teacher: _teacher.text.trim(),
      day: _day,
      startSection: start,
      span: span,
      startWeek: startWeek,
      endWeek: endWeek,
      startTime: startPeriod.start,
      endTime: endPeriod.end,
      source: existing?.source ?? 'manual',
      updatedAt: now,
    );
    Navigator.of(context).pop(course);
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context,
      title: widget.editing == null ? '添加课程' : '编辑课程',
      subtitle: '手动添加的课程只保存在本机',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(context, '课程名称'),
          _textField(context, _name, '例如：机械设计基础'),
          SizedBox(height: capRpx(context, 16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, '上课地点'),
                    _textField(context, _room, '教 1-307'),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, '任课教师'),
                    _textField(context, _teacher, '选填'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 16)),
          _fieldLabel(context, '星期'),
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: capRpx(context, 4)),
                    child: Pressable(
                      onTap: () => setState(() => _day = i),
                      child: Container(
                        height: capRpx(context, 52),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _day == i
                              ? AppColors.ink
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(
                            capRpx(context, 12),
                          ),
                        ),
                        child: Text(
                          capWeekLabelsShort[i - 1],
                          style: TextStyle(
                            fontSize: capRpx(context, 19),
                            fontWeight: FontWeight.w700,
                            color: _day == i ? Colors.white : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: capRpx(context, 16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, '开始节次'),
                    _dropdown(
                      context,
                      value: '第 $_startSection 节',
                      onTap: () async {
                        final value = await _pickNumber(
                          context,
                          title: '开始节次',
                          values: List.generate(capPeriods.length, (i) => i + 1),
                          selected: _startSection,
                          label: (v) => '第 $v 节',
                        );
                        if (value != null) {
                          setState(() {
                            _startSection = value;
                            _span = _span.clamp(
                              1,
                              capPeriods.length - _startSection + 1,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, '连上'),
                    _dropdown(
                      context,
                      value: '$_span 节',
                      onTap: () async {
                        final max = capPeriods.length - _startSection;
                        final value = await _pickNumber(
                          context,
                          title: '连上节次',
                          values: List.generate(max, (i) => i + 1),
                          selected: _span,
                          label: (v) => '$v 节',
                        );
                        if (value != null) setState(() => _span = value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, '起始周'),
                    _textField(context, _startWeek, '1', number: true),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(context, '结束周'),
                    _textField(context, _endWeek, '18', number: true),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 24)),
          Row(
            children: [
              Expanded(
                child: _sheetAction(
                  context,
                  primary: false,
                  icon: 'x',
                  label: '取消',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: _sheetAction(
                  context,
                  primary: true,
                  icon: 'check',
                  label: widget.editing == null ? '保存课程' : '保存修改',
                  onTap: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetAction(
    BuildContext context, {
    required bool primary,
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 66),
        decoration: BoxDecoration(
          color: primary ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 18)),
          border: Border.all(
            color: primary ? AppColors.ink : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CapIcon(
              icon,
              size: capRpx(context, 23),
              color: primary ? const Color(0xFFFFF8EA) : AppColors.ink,
            ),
            SizedBox(width: capRpx(context, 6)),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 21),
                fontWeight: FontWeight.w700,
                color: primary ? const Color(0xFFFFF8EA) : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: capRpx(context, 7)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 19),
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _textField(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        fontSize: capRpx(context, 22),
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: capRpx(context, 22),
          color: AppColors.mutedSoft,
        ),
        filled: true,
        fillColor: AppColors.surfaceSoft,
        contentPadding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 16),
          vertical: capRpx(context, 15),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 16)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdown(
    BuildContext context, {
    required String value,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 56),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 16)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: capRpx(context, 21),
                  color: AppColors.ink,
                ),
              ),
            ),
            CapIcon(
              'chevron-down',
              size: capRpx(context, 22),
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickNumber(
    BuildContext context, {
    required String title,
    required List<int> values,
    required int selected,
    required String Function(int) label,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheetShell(
        context,
        title: title,
        child: SizedBox(
          height: 360,
          child: ListView.builder(
            itemCount: values.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(label(values[index])),
              trailing: values[index] == selected
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(values[index]),
            ),
          ),
        ),
      ),
    );
  }
}
