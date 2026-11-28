import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/cap_course.dart';
import '../data/cap_store.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../services/cap_reminders.dart';
import '../services/electricity_service.dart';
import '../services/tieba/tieba_client.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_reveal.dart';
import '../widgets/countdown_card.dart';
import '../widgets/pressable.dart';
import '../widgets/todo_row.dart';
import 'countdown_page.dart';
import 'electricity_page.dart';
import 'ledger_page.dart';
import 'settings_page.dart';
import 'todo_page.dart';
import 'tieba/messages_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, this.onOpenTab, this.visitSignal});

  final ValueChanged<int>? onOpenTab;
  final ValueListenable<int>? visitSignal;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  DateTime _now = DateTime.now();
  Timer? _clock;
  final _quickController = TextEditingController();
  final _quickFocus = FocusNode();
  bool _quickReady = false;
  bool _tiebaLoggedIn = false;
  int _tiebaReplies = 0;
  int _tiebaAts = 0;
  TiebaClient? _tiebaClient;
  bool _electricityRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadTiebaMessages();
    widget.visitSignal?.addListener(_onHomeVisit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshHomeElectricity();
    });
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _quickController.addListener(() {
      final ready = _quickController.text.trim().isNotEmpty;
      if (ready != _quickReady) setState(() => _quickReady = ready);
    });
    _quickFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.visitSignal?.removeListener(_onHomeVisit);
    _tiebaClient?.authRevision.removeListener(_onTiebaAuthChanged);
    _clock?.cancel();
    _quickController.dispose();
    _quickFocus.dispose();
    super.dispose();
  }

  void _onHomeVisit() {
    if (!mounted) return;
    _refreshHomeElectricity();
    _loadTiebaMessages();
  }

  Future<void> _refreshHomeElectricity() async {
    final store = CapScope.of(context);
    final raw = store.electricity['binding'];
    if (raw is! Map || _electricityRefreshing) return;
    final binding = Map<String, dynamic>.from(raw);
    if (binding.isEmpty) return;
    setState(() => _electricityRefreshing = true);
    try {
      final result = await ElectricityService.instance.queryBalance(
        binding,
        includeTrend: false,
      );
      if (!mounted || !result.ok) return;
      final previous = store.electricity['balance'] is Map
          ? Map<String, dynamic>.from(store.electricity['balance'] as Map)
          : <String, dynamic>{};
      final next = <String, dynamic>{
        ...previous,
        'val': result.val,
        'unit': result.unit,
        'dayUse': result.dayUse,
        'updatedAt':
            result.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        'system': result.system,
      };
      store.recordElectricitySample(binding, next);
      store.setElectricityBalance(next);
    } catch (_) {
      // Keep the last known balance; the electricity page shows detailed errors.
    } finally {
      if (mounted) setState(() => _electricityRefreshing = false);
    }
  }

  void _onTiebaAuthChanged() {
    if (mounted) _loadTiebaMessages();
  }

  void _quickAdd() {
    final title = _quickController.text.trim();
    if (title.isEmpty) return;
    final store = CapScope.of(context);
    store.addTodo(title: title, dueDate: formatDateKey(_now));
    _quickController.clear();
    setState(() => _quickReady = false);
    _quickFocus.unfocus();
  }

  Future<void> _loadTiebaMessages() async {
    try {
      final client = _tiebaClient ?? await TiebaClient.load();
      if (!mounted) return;
      if (!identical(_tiebaClient, client)) {
        _tiebaClient?.authRevision.removeListener(_onTiebaAuthChanged);
        _tiebaClient = client;
        client.authRevision.addListener(_onTiebaAuthChanged);
      }
      if (!client.loggedIn) {
        setState(() => _tiebaLoggedIn = false);
        return;
      }
      setState(() => _tiebaLoggedIn = true);
      await client.healSession();
      final reply = await client.api.replyMe(pn: 1);
      final at = await client.api.atMe(pn: 1);
      if (!mounted) return;
      setState(() {
        _tiebaReplies = reply.items.length;
        _tiebaAts = at.items.length;
      });
    } catch (_) {
      if (mounted) setState(() => _tiebaLoggedIn = true);
    }
  }

  void _openTiebaMessages() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const TiebaMessagesPage()),
        )
        .then((_) => _loadTiebaMessages());
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final week = store.weekInfoAt(_now);
    final weekLabel = week.phase == 'before' || week.phase == 'after'
        ? week.totalWeeks
        : math.max(1, week.week);
    final nearest = store.nearestCountdown;
    final nearestDays = nearest == null
        ? null
        : diffDays(nearest.targetDate, base: _now);
    final todayCourses = store.todayCoursesAt(_now);
    final currentCourse = store.currentCourseAt(_now, todayCourses);
    final nextCourse = store.nextCourseAt(_now, todayCourses);
    final pending = store.pendingTodos;
    final todoStats = store.todoStats;
    final todayDone = store.todayDoneStatsAt(_now);
    final ledger = store.ledgerSummaryAt(_now);
    final homeTodos = pending.take(3).toList();
    final heroTitle = week.phase == 'before'
        ? '新学期还没开始'
        : week.phase == 'after'
        ? '学期已经抵达终点'
        : todayCourses.isEmpty
        ? '今天没有课'
        : currentCourse != null
        ? '正在上课'
        : '今天有 ${todayCourses.length} 节课';
    final heroSub = week.phase == 'before'
        ? '开学日期 ${store.settings.semesterStart}，先把日子排好'
        : week.phase == 'after'
        ? '把课上完，也把生活过成想要的样子'
        : currentCourse != null
        ? '${currentCourse.timeText} · ${currentCourse.name}${currentCourse.room.isEmpty ? '' : ' · ${currentCourse.room}'}'
        : nextCourse != null
        ? '下一节 ${nextCourse.startClock} · ${nextCourse.name}${nextCourse.room.isEmpty ? '' : ' · ${nextCourse.room}'}'
        : todayCourses.isNotEmpty
        ? '今天的课都在身后了，去安排一点自己的时间'
        : '把时间留给想做的事，或者去图书馆坐坐';
    final emptyCourseTitle = week.phase == 'before'
        ? '学期还没有开始'
        : week.phase == 'after'
        ? '这一学期已经结束'
        : '今天没有排课';
    final emptyCourseText = week.phase == 'before'
        ? '距离开学还有 ${math.max(0, -diffDays(store.settings.semesterStart, base: _now))} 天'
        : week.phase == 'after'
        ? '假期愉快，下一学期见'
        : '很适合自习、休息，或者把想做的事往前挪一格';
    final nearestText = nearestDays == null
        ? '--'
        : nearestDays == 0
        ? '今'
        : '${nearestDays.abs()}';
    final nearestUnit = nearestDays == null
        ? ''
        : nearestDays == 0
        ? '天'
        : nearestDays > 0
        ? '天'
        : '天前';
    final todoHint = todoStats.total == 0
        ? '从一件小事开始'
        : (todayDone.total > 0 && todayDone.done >= todayDone.total)
        ? '今天的清单已经清空'
        : '还有 ${todoStats.pending} 件在路上';
    final ledgerHint = !ledger.hasBudget
        ? '设置预算，看清这个月能花多少'
        : ledger.hint;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        top: safeTop + 10,
        bottom: safeBottom + capRpx(context, 246),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 36)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CapReveal(index: 0, child: _brandRow(context, store)),
              SizedBox(height: capRpx(context, 56)),
              CapReveal(index: 1, child: _greeting(context, weekLabel)),
            ],
          ),
        ),
        CapReveal(index: 2, child: _hero(context, weekLabel, heroTitle, heroSub)),
        CapReveal(
          index: 3,
          child: _glanceRow(
            context,
            pendingCount: pending.length,
            todayDone: todayDone,
            nearestText: nearestText,
            nearestUnit: nearestUnit,
            nearestTitle: nearest?.title ?? '添加一个日子',
            elecValue: store.electricityValue,
            elecUnit: store.electricityUnit,
            elecHint: store.electricityHint,
            elecLoading: _electricityRefreshing,
          ),
        ),
        CapReveal(
          index: 4,
          child: _ledgerGlance(context, ledger, ledgerHint),
        ),
        CapReveal(index: 5, child: _tiebaMessageGlance(context)),
        CapReveal(
          index: 6,
          child: _sectionHead(
            context,
            title: '下一个值得期待的日子',
            action: '全部倒计日',
          ),
        ),
        CapReveal(
          index: 7,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
            child: nearest == null
                ? _emptyCountdown(context)
                : CountdownCard(
                    item: nearest,
                    variant: CountdownVariant.compact,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CountdownPage()),
                    ),
                  ),
          ),
        ),
        CapReveal(
          index: 8,
          child: _sectionHead(
            context,
            title: '今天的课',
            action: '完整课表',
            onAction: () => widget.onOpenTab?.call(1),
          ),
        ),
        CapReveal(
          index: 9,
          child: _todayPanel(
            context,
            todayCourses: todayCourses,
            emptyCourseTitle: emptyCourseTitle,
            emptyCourseText: emptyCourseText,
          ),
        ),
        CapReveal(
          index: 10,
          child: _sectionHead(
            context,
            title: '今日待办',
            action: '全部待办',
            count: todoStats.pending > 0 ? '${todoStats.pending}' : null,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TodoPage()),
            ),
          ),
        ),
        CapReveal(
          index: 11,
          child: _todoPanel(
            context,
            store: store,
            homeTodos: homeTodos,
            todoStats: todoStats,
            todayDone: todayDone,
            todoHint: todoHint,
          ),
        ),
        SizedBox(height: capRpx(context, 56)),
        _footer(context),
      ],
    );
  }

  Widget _brandRow(BuildContext context, CapStore store) {
    final size = capRpx(context, 68);
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(capRpx(context, 19)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0C2E7A).withValues(alpha: 0.22),
                blurRadius: capRpx(context, 20),
                offset: Offset(0, capRpx(context, 8)),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(capRpx(context, 19)),
            child: Image.asset(
              'assets/images/logo.png',
              width: capRpx(context, 66),
              height: capRpx(context, 66),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(width: capRpx(context, 16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CapuLife',
                style: AppText.display.copyWith(
                  fontSize: capRpx(context, 42),
                  height: 1,
                  letterSpacing: capRpx(context, 42) * -0.03,
                ),
              ),
              SizedBox(height: capRpx(context, 1)),
              Text(
                '成都航空职业技术大学',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  fontWeight: FontWeight.w600,
                  letterSpacing: capRpx(context, 18) * 0.06,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: capRpx(context, 14)),
        _circleAction(
          context,
          size: size,
          icon: 'settings',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
        SizedBox(width: capRpx(context, 14)),
        _circleAction(
          context,
          size: size,
          icon: 'bell',
          dot: store.pendingTodos.isNotEmpty,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TodoPage()),
          ),
        ),
      ],
    );
  }

  Widget _circleAction(
    BuildContext context, {
    required double size,
    required String icon,
    required VoidCallback onTap,
    bool dot = false,
  }) {
    return Pressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
              child: CapIcon(
                icon,
                size: capRpx(context, 31),
                color: AppColors.ink,
              ),
            ),
          ),
          if (dot)
            Positioned(
              right: capRpx(context, 17),
              top: capRpx(context, 16),
              child: Container(
                width: capRpx(context, 12),
                height: capRpx(context, 12),
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: capRpx(context, 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _greeting(BuildContext context, int weekLabel) {
    final greeting = greetingFor(_now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              formatDateCN(_now, withWeekday: true),
              style: TextStyle(
                fontSize: capRpx(context, 22),
                fontWeight: FontWeight.w600,
                letterSpacing: capRpx(context, 22) * 0.015,
                color: AppColors.muted,
              ),
            ),
            SizedBox(width: capRpx(context, 14)),
            Text(
              '·',
              style: TextStyle(
                fontSize: capRpx(context, 24),
                color: AppColors.mutedSoft,
              ),
            ),
            SizedBox(width: capRpx(context, 14)),
            Text(
              '第 $weekLabel 周',
              style: TextStyle(
                fontSize: capRpx(context, 22),
                fontWeight: FontWeight.w600,
                letterSpacing: capRpx(context, 22) * 0.015,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        SizedBox(height: capRpx(context, 12)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: greeting,
                style: TextStyle(
                  fontSize: capRpx(context, 56),
                  fontWeight: FontWeight.w800,
                  letterSpacing: capRpx(context, 56) * -0.055,
                  height: 1.05,
                  color: AppColors.ink,
                ),
              ),
              TextSpan(
                text: '，同学',
                style: TextStyle(
                  fontSize: capRpx(context, 36),
                  fontWeight: FontWeight.w600,
                  letterSpacing: capRpx(context, 36) * -0.03,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: capRpx(context, 8)),
        Text(
          greetingNoteFor(_now),
          style: TextStyle(
            fontSize: capRpx(context, 23),
            letterSpacing: capRpx(context, 23) * 0.01,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _hero(
    BuildContext context,
    int weekLabel,
    String title,
    String sub,
  ) {
    final heroHeight = capRpx(context, 414);
    final radius = capRpx(context, 40);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 38),
        capRpx(context, 28),
        0,
      ),
      child: Container(
        height: heroHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1D36).withValues(alpha: 0.24),
              blurRadius: capRpx(context, 62),
              offset: Offset(0, capRpx(context, 28)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/hero-${heroTimeOfDay(_now)}.jpg',
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF07182F).withValues(alpha: 0.08),
                      const Color(0xFF07182F).withValues(alpha: 0.24),
                      const Color(0xFF07162B).withValues(alpha: 0.80),
                    ],
                    stops: const [0, 0.38, 1],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF07162B).withValues(alpha: 0.42),
                      const Color(0xFF07162B).withValues(alpha: 0.02),
                    ],
                    stops: const [0, 0.70],
                  ),
                ),
              ),
              Positioned(
                right: -capRpx(context, 110),
                top: capRpx(context, 88),
                child: Container(
                  width: capRpx(context, 310),
                  height: capRpx(context, 310),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.03),
                        blurRadius: 0,
                        spreadRadius: capRpx(context, 28),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.02),
                        blurRadius: 0,
                        spreadRadius: capRpx(context, 76),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  capRpx(context, 30),
                  capRpx(context, 28),
                  capRpx(context, 30),
                  capRpx(context, 26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: capRpx(context, 42),
                          padding: EdgeInsets.symmetric(
                            horizontal: capRpx(context, 16),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(alpha: 0.14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: capRpx(context, 18),
                                height: capRpx(context, 2),
                                color: const Color(0xFFF1C477),
                              ),
                              SizedBox(width: capRpx(context, 10)),
                              Text(
                                '今日航线',
                                style: TextStyle(
                                  fontSize: capRpx(context, 19),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: capRpx(context, 19) * 0.08,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'W${weekLabel.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: capRpx(context, 19),
                            letterSpacing: capRpx(context, 19) * 0.2,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${weekdayCN(_now)} · ${_now.day} 日',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w600,
                        letterSpacing: capRpx(context, 20) * 0.06,
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 8)),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 54),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, 54) * -0.045,
                        height: 1.1,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: capRpx(context, 24),
                            offset: Offset(0, capRpx(context, 8)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: capRpx(context, 8)),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 24)),
                    Row(
                      children: [
                        _heroButton(
                          context,
                          primary: true,
                          icon: 'arrow-up-right',
                          label: '查看课表',
                          onTap: () => widget.onOpenTab?.call(1),
                        ),
                        SizedBox(width: capRpx(context, 14)),
                        _heroButton(
                          context,
                          primary: false,
                          icon: 'layout-grid',
                          label: '事务中心',
                          iconFirst: true,
                          onTap: () => widget.onOpenTab?.call(2),
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

  Widget _heroButton(
    BuildContext context, {
    required bool primary,
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool iconFirst = false,
  }) {
    final fg = primary
        ? const Color(0xFF16233A)
        : Colors.white.withValues(alpha: 0.9);
    final iconWidget = CapIcon(
      icon,
      size: capRpx(context, primary ? 27 : 26),
      color: fg,
    );
    return Pressable(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 66),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 24)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: primary
              ? const Color(0xFFFFFAF0)
              : Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconFirst) ...[
              iconWidget,
              SizedBox(width: capRpx(context, 9)),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 23),
                fontWeight: FontWeight.w700,
                letterSpacing: capRpx(context, 23) * 0.01,
                color: fg,
              ),
            ),
            if (!iconFirst) ...[
              SizedBox(width: capRpx(context, 9)),
              iconWidget,
            ],
          ],
        ),
      ),
    );
  }

  Widget _glanceRow(
    BuildContext context, {
    required int pendingCount,
    required CapTodoStats todayDone,
    required String nearestText,
    required String nearestUnit,
    required String nearestTitle,
    required String elecValue,
    required String elecUnit,
    required String elecHint,
    bool elecLoading = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 22),
        capRpx(context, 28),
        0,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _GlanceCard(
                icon: 'list-checks',
                iconColor: AppColors.accent,
                iconBg: AppColors.accentSoft,
                label: '待办',
                value: '$pendingCount',
                unit: '项',
                hint: todayDone.total > 0
                    ? '今天完成 ${todayDone.done}/${todayDone.total}'
                    : '今天慢慢来',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TodoPage()),
                ),
              ),
            ),
            SizedBox(width: capRpx(context, 14)),
            Expanded(
              child: _GlanceCard(
                icon: 'hourglass',
                iconColor: const Color(0xFF9A641F),
                iconBg: AppColors.goldSoft,
                label: '倒计日',
                value: nearestText,
                unit: nearestUnit,
                hint: nearestTitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CountdownPage()),
                ),
              ),
            ),
            SizedBox(width: capRpx(context, 14)),
            Expanded(
              child: _GlanceCard(
                icon: 'zap',
                iconColor: AppColors.mint,
                iconBg: AppColors.mintSoft,
                label: '电费',
                value: elecValue,
                unit: elecUnit,
                hint: elecHint,
                loading: elecLoading,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ElectricityPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiebaMessageGlance(BuildContext context) {
    final total = _tiebaReplies + _tiebaAts;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 12),
        capRpx(context, 28),
        0,
      ),
      child: Pressable(
        onTap: _openTiebaMessages,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: capRpx(context, 20),
            vertical: capRpx(context, 16),
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(capRpx(context, 24)),
            border: Border.all(
              color: total > 0
                  ? AppColors.accent.withValues(alpha: 0.22)
                  : AppColors.line,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: capRpx(context, 52),
                height: capRpx(context, 52),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 16)),
                ),
                child: Center(
                  child: CapIcon(
                    'message-square',
                    size: capRpx(context, 25),
                    color: AppColors.accent,
                  ),
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '贴吧消息',
                      style: TextStyle(
                        fontSize: capRpx(context, 23),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      !_tiebaLoggedIn
                          ? '登录贴吧后同步回复与 @'
                          : total > 0
                              ? '回复 $_tiebaReplies · @我的 $_tiebaAts'
                              : '暂无新回复，点开查看',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Container(
                  width: capRpx(context, 34),
                  height: capRpx(context, 34),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    total > 99 ? '99+' : '$total',
                    style: TextStyle(
                      fontSize: capRpx(context, 15),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                CapIcon(
                  'chevron-right',
                  size: capRpx(context, 20),
                  color: AppColors.mutedSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ledgerGlance(
    BuildContext context,
    CapLedgerSummary ledger,
    String hint,
  ) {
    final toneColor = ledger.tone == 'low'
        ? AppColors.coral
        : ledger.tone == 'mid'
        ? const Color(0xFF9A641F)
        : AppColors.ink;
    final fillColors = ledger.tone == 'low'
        ? const [AppColors.coral, Color(0xFFE88E77)]
        : ledger.tone == 'mid'
        ? const [AppColors.gold, Color(0xFFE0B06A)]
        : const [AppColors.accent, Color(0xFF4F83E7)];
    final remainText = ledger.hasBudget
        ? formatMoney(ledger.remainingCents, compact: true)
        : '未设置';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 18),
        capRpx(context, 28),
        0,
      ),
      child: Pressable(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LedgerPage()),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(capRpx(context, 28)),
            color: AppColors.surface,
            border: Border.all(color: AppColors.line, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: capRpx(context, 26),
                offset: Offset(0, capRpx(context, 10)),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(capRpx(context, 28)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(1.02, -0.8),
                        radius: 0.9,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.14),
                          AppColors.gold.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.58],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    capRpx(context, 22),
                    capRpx(context, 20),
                    capRpx(context, 22),
                    capRpx(context, 18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: capRpx(context, 42),
                            height: capRpx(context, 42),
                            decoration: BoxDecoration(
                              color: AppColors.goldSoft,
                              borderRadius: BorderRadius.circular(
                                capRpx(context, 13),
                              ),
                            ),
                            child: Center(
                              child: CapIcon(
                                'wallet',
                                size: capRpx(context, 27),
                                color: const Color(0xFF9A641F),
                              ),
                            ),
                          ),
                          SizedBox(width: capRpx(context, 10)),
                          Text(
                            '记账',
                            style: TextStyle(
                              fontSize: capRpx(context, 23),
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(width: capRpx(context, 10)),
                          Flexible(
                            child: Text(
                              ledger.monthLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: capRpx(context, 17),
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedSoft,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '明细',
                            style: TextStyle(
                              fontSize: capRpx(context, 19),
                              color: AppColors.muted,
                            ),
                          ),
                          CapIcon(
                            'chevron-right',
                            size: capRpx(context, 22),
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                      SizedBox(height: capRpx(context, 16)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '本期支出',
                                style: TextStyle(
                                  fontSize: capRpx(context, 17),
                                  color: AppColors.muted,
                                ),
                              ),
                              SizedBox(height: capRpx(context, 3)),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '¥',
                                    style: TextStyle(
                                      fontSize: capRpx(context, 20),
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: capRpx(context, 3)),
                                  Text(
                                    formatMoney(
                                      ledger.spentCents,
                                      compact: true,
                                    ),
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: capRpx(context, 34),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: capRpx(context, 34) * -0.04,
                                      color: AppColors.ink,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: capRpx(context, 44),
                            margin: EdgeInsets.symmetric(
                              horizontal: capRpx(context, 18),
                            ),
                            color: AppColors.line,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '预算剩余',
                                style: TextStyle(
                                  fontSize: capRpx(context, 17),
                                  color: AppColors.muted,
                                ),
                              ),
                              SizedBox(height: capRpx(context, 3)),
                              Text(
                                remainText,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: capRpx(context, 34),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: capRpx(context, 34) * -0.04,
                                  color: toneColor,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Pressable(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LedgerPage(openAdd: true),
                              ),
                            ),
                            child: Container(
                              height: capRpx(context, 54),
                              padding: EdgeInsets.symmetric(
                                horizontal: capRpx(context, 16),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CapIcon(
                                    'plus',
                                    size: capRpx(context, 23),
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: capRpx(context, 3)),
                                  Text(
                                    '记一笔',
                                    style: TextStyle(
                                      fontSize: capRpx(context, 19),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: capRpx(context, 16)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: capRpx(context, 7),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: AppColors.surfaceSoft),
                              ),
                              Positioned.fill(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: ledger.percent / 100,
                                  ),
                                  duration: const Duration(milliseconds: 280),
                                  curve: softSpringCurve,
                                  builder: (context, value, _) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: value.clamp(0.0, 1.0),
                                      heightFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: fillColors,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: capRpx(context, 8)),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: AppColors.mutedSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHead(
    BuildContext context, {
    required String title,
    required String action,
    VoidCallback? onAction,
    String? count,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 36),
        capRpx(context, 46),
        capRpx(context, 36),
        capRpx(context, 20),
      ),
      child: Row(
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
          if (count != null) ...[
            SizedBox(width: capRpx(context, 10)),
            Container(
              constraints: BoxConstraints(minWidth: capRpx(context, 30)),
              height: capRpx(context, 30),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 8)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: capRpx(context, 16),
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
          const Spacer(),
          Pressable(
            onTap: onAction ?? () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: capRpx(context, 23),
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(width: capRpx(context, 4)),
                CapIcon(
                  'chevron-right',
                  size: capRpx(context, 26),
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCountdown(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CountdownPage()),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 26),
          vertical: capRpx(context, 30),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
          border: Border.all(color: AppColors.lineStrong, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: capRpx(context, 68),
              height: capRpx(context, 68),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 22)),
              ),
              child: Center(
                child: CapIcon(
                  'hourglass',
                  size: capRpx(context, 40),
                  color: const Color(0xFF9A641F),
                ),
              ),
            ),
            SizedBox(width: capRpx(context, 18)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '给未来留一个坐标',
                    style: TextStyle(
                      fontSize: capRpx(context, 26),
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 2)),
                  Text(
                    '添加考试、生日或旅行的倒计日',
                    style: TextStyle(
                      fontSize: capRpx(context, 21),
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            CapIcon(
              'plus',
              size: capRpx(context, 30),
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayPanel(
    BuildContext context, {
    required List<CapCourse> todayCourses,
    required String emptyCourseTitle,
    required String emptyCourseText,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 26),
          capRpx(context, 26),
          capRpx(context, 26),
          capRpx(context, 22),
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
              padding: EdgeInsets.only(bottom: capRpx(context, 20)),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.line, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${_now.day}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: capRpx(context, 62),
                          fontWeight: FontWeight.w800,
                          height: 0.9,
                          letterSpacing: capRpx(context, 62) * -0.06,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(width: capRpx(context, 16)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekdayCN(_now),
                            style: TextStyle(
                              fontSize: capRpx(context, 23),
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: capRpx(context, 2)),
                          Text(
                            '${_now.month} 月',
                            style: TextStyle(
                              fontSize: capRpx(context, 18),
                              letterSpacing: capRpx(context, 18) * 0.08,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: capRpx(context, 9),
                        height: capRpx(context, 9),
                        decoration: BoxDecoration(
                          color: todayCourses.isEmpty
                              ? AppColors.mutedSoft
                              : AppColors.mint,
                          shape: BoxShape.circle,
                          boxShadow: todayCourses.isEmpty
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.mint.withValues(alpha: 0.10),
                                    spreadRadius: capRpx(context, 5),
                                  ),
                                ],
                        ),
                      ),
                      SizedBox(width: capRpx(context, 8)),
                      Text(
                        todayCourses.isEmpty
                            ? '无课'
                            : '${todayCourses.length} 节课',
                        style: TextStyle(
                          fontSize: capRpx(context, 20),
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (todayCourses.isEmpty)
              Padding(
              padding: EdgeInsets.only(top: capRpx(context, 26)),
              child: Row(
                children: [
                  Container(
                    width: capRpx(context, 84),
                    height: capRpx(context, 84),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(capRpx(context, 25)),
                      border: Border.all(color: AppColors.line, width: 1),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: 0.9,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: capRpx(context, 52),
                          height: capRpx(context, 52),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: capRpx(context, 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emptyCourseTitle,
                          style: TextStyle(
                            fontSize: capRpx(context, 26),
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: capRpx(context, 4)),
                        Text(
                          emptyCourseText,
                          style: TextStyle(
                            fontSize: capRpx(context, 20),
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: capRpx(context, 12)),
                  Pressable(
                    onTap: () => widget.onOpenTab?.call(1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '去同步',
                          style: TextStyle(
                            fontSize: capRpx(context, 21),
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        CapIcon(
                          'chevron-right',
                          size: capRpx(context, 22),
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            else
              Padding(
                padding: EdgeInsets.only(top: capRpx(context, 10)),
                child: _homeCourseList(context, todayCourses),
              ),
          ],
        ),
      ),
    );
  }

  Widget _homeCourseList(BuildContext context, List<CapCourse> courses) {
    final display = courses.take(3).toList();
    return Column(
      children: [
        for (final course in display)
          _homeCourseRow(context, course),
        if (courses.length > display.length)
          Pressable(
            onTap: () => widget.onOpenTab?.call(1),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: capRpx(context, 16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还有 ${courses.length - display.length} 节',
                    style: TextStyle(
                      fontSize: capRpx(context, 20),
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  CapIcon(
                    'chevron-right',
                    size: capRpx(context, 23),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _homeCourseRow(BuildContext context, CapCourse course) {
    final palette = coursePaletteFor(course.name);
    final parts = course.timeText.split('–');
    final start = parts.first.trim();
    final end = parts.length > 1 ? parts[1].trim() : '';
    return Pressable(
      onTap: () => widget.onOpenTab?.call(1),
      child: Padding(
        padding: EdgeInsets.only(top: capRpx(context, 16), bottom: capRpx(context, 2)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: capRpx(context, 82),
              child: Padding(
                padding: EdgeInsets.only(top: capRpx(context, 13)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      start.isEmpty ? '—' : start,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, 24) * -0.03,
                        color: AppColors.ink,
                      ),
                    ),
                    if (end.isNotEmpty)
                      Text(
                        end,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: capRpx(context, 17),
                          color: AppColors.mutedSoft,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: capRpx(context, 30),
              child: Column(
                children: [
                  SizedBox(height: capRpx(context, 22)),
                  Container(
                    width: capRpx(context, 9),
                    height: capRpx(context, 9),
                    decoration: BoxDecoration(
                      color: palette.line,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: palette.bg,
                          spreadRadius: capRpx(context, 5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: capRpx(context, 46),
                    color: AppColors.line,
                    margin: EdgeInsets.only(top: capRpx(context, 6)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: capRpx(context, 18),
                  vertical: capRpx(context, 16),
                ),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.025),
                    width: 1,
                  ),
                ),
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
                        SizedBox(width: capRpx(context, 12)),
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
                          'target',
                          size: capRpx(context, 21),
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
                        if (course.teacher.isNotEmpty)
                          Text(
                            course.teacher,
                            style: TextStyle(
                              fontSize: capRpx(context, 19),
                              color: palette.ink.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todoPanel(
    BuildContext context, {
    required CapStore store,
    required List<CapTodo> homeTodos,
    required CapTodoStats todoStats,
    required CapTodoStats todayDone,
    required String todoHint,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 26),
          capRpx(context, 24),
          capRpx(context, 26),
          capRpx(context, 16),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          width: capRpx(context, 148),
                          height: capRpx(context, 8),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: AppColors.surfaceSoft),
                              ),
                              Positioned.fill(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: todayDone.percent / 100,
                                  ),
                                  duration: const Duration(milliseconds: 280),
                                  curve: softSpringCurve,
                                  builder: (context, value, _) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: value.clamp(0.0, 1.0),
                                      heightFactor: 1,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.accent,
                                              Color(0xFF4F83E7),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: capRpx(context, 12)),
                      Text(
                        '${todayDone.done} / ${todayDone.total}',
                        style: TextStyle(
                          fontSize: capRpx(context, 18),
                          fontWeight: FontWeight.w700,
                          letterSpacing: capRpx(context, 18) * 0.04,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  todoHint,
                  style: TextStyle(
                    fontSize: capRpx(context, 18),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
            if (homeTodos.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: capRpx(context, 2),
                  vertical: capRpx(context, 26),
                ),
                child: Row(
                  children: [
                    CapIcon(
                      'circle-check',
                      size: capRpx(context, 34),
                      color: AppColors.mint,
                    ),
                    SizedBox(width: capRpx(context, 12)),
                    Text(
                      '今天还没有待办，留一点空白也很好',
                      style: TextStyle(
                        fontSize: capRpx(context, 21),
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: capRpx(context, 2)),
                child: Column(
                  children: [
                    for (var i = 0; i < homeTodos.length; i++)
                      TodoRow(
                        item: homeTodos[i],
                        compact: true,
                        showDivider: i < homeTodos.length - 1,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TodoPage()),
                        ),
                        onToggle: () {
                          final target = homeTodos[i];
                          store.toggleTodo(target.id);
                          CapReminders.syncTodo(target);
                        },
                      ),
                  ],
                ),
              ),
            _quickAddRow(context),
          ],
        ),
      ),
    );
  }

  Widget _quickAddRow(BuildContext context) {
    final borderColor = _quickFocus.hasFocus
        ? AppColors.lineStrong
        : Colors.transparent;
    return Container(
      margin: EdgeInsets.only(top: capRpx(context, 10)),
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 16),
        capRpx(context, 12),
        capRpx(context, 12),
        capRpx(context, 12),
      ),
      decoration: BoxDecoration(
        color: _quickFocus.hasFocus ? AppColors.surface : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 20)),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          CapIcon(
            'plus',
            size: capRpx(context, 25),
            color: AppColors.muted,
          ),
          SizedBox(width: capRpx(context, 12)),
          Expanded(
            child: SizedBox(
              height: capRpx(context, 56),
              child: TextField(
                controller: _quickController,
                focusNode: _quickFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _quickAdd(),
                cursorColor: AppColors.accent,
                style: TextStyle(
                  fontSize: capRpx(context, 23),
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '记一件小事…',
                  hintStyle: TextStyle(
                    fontSize: capRpx(context, 23),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ),
            ),
          ),
          Pressable(
            onTap: _quickReady ? _quickAdd : null,
            child: AnimatedContainer(
              duration: capsuleMotionFast,
              curve: capsuleSpringCurve,
              height: capRpx(context, 52),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _quickReady ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(capRpx(context, 14)),
                border: Border.all(
                  color: _quickReady ? AppColors.ink : AppColors.line,
                  width: 1,
                ),
              ),
              child: Text(
                '加入',
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  fontWeight: FontWeight.w700,
                  color: _quickReady ? Colors.white : AppColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 36)),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 38),
            height: 1,
            color: AppColors.lineStrong,
          ),
          SizedBox(height: capRpx(context, 16)),
          Text(
            '数据只存在这台设备里，不上传服务器',
            style: TextStyle(
              fontSize: capRpx(context, 18),
              letterSpacing: capRpx(context, 18) * 0.02,
              color: AppColors.mutedSoft,
            ),
          ),
          SizedBox(height: capRpx(context, 10)),
          Opacity(
            opacity: 0.7,
            child: Text(
              'CapuLife',
              style: AppText.display.copyWith(
                fontSize: capRpx(context, 22),
                color: AppColors.mutedSoft,
                letterSpacing: capRpx(context, 22) * -0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.unit,
    required this.hint,
    required this.onTap,
    this.loading = false,
  });

  final String icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String unit;
  final String hint;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 18),
          capRpx(context, 20),
          capRpx(context, 18),
          capRpx(context, 18),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          border: Border.all(color: AppColors.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: capRpx(context, 22),
              offset: Offset(0, capRpx(context, 8)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: capRpx(context, 44),
              height: capRpx(context, 44),
              margin: EdgeInsets.only(bottom: capRpx(context, 5)),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(capRpx(context, 14)),
              ),
              child: Center(
                child: CapIcon(
                  icon,
                  size: capRpx(context, 29),
                  color: iconColor,
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 19),
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            SizedBox(height: capRpx(context, 4)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: capsuleMotionFast,
                    switchInCurve: capsuleSpringCurve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.16),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      value,
                      key: ValueKey(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: capRpx(context, 38),
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: capRpx(context, 38) * -0.045,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  SizedBox(width: capRpx(context, 3)),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: capRpx(context, 4)),
            Row(
              children: [
                if (loading) ...[
                  SizedBox(
                    width: capRpx(context, 14),
                    height: capRpx(context, 14),
                    child: const CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  SizedBox(width: capRpx(context, 4)),
                ],
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      color: AppColors.mutedSoft,
                    ),
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
