import 'package:flutter/material.dart';

import '../data/cap_planner.dart';
import '../data/cap_store.dart';
import '../services/cap_reminders.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/app_header.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_page.dart';
import '../widgets/cap_sheet.dart';
import '../widgets/cap_toast.dart';
import '../widgets/cap_toggle.dart';
import '../widgets/progress_ring.dart';
import '../widgets/todo_row.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key, this.openAdd = false});

  final bool openAdd;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  String _filter = 'today';
  String? _draggingId;
  String? _targetId;

  @override
  void initState() {
    super.initState();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAdd());
    }
  }

  List<CapTodo> _filtered(CapStore store) {
    if (_filter == 'done') {
      return store.todos.where((item) => item.done).toList()
        ..sort((a, b) => b.doneAt.compareTo(a.doneAt));
    }
    if (_filter == 'active') return store.pendingTodos;
    return store.todayTodosAt(DateTime.now());
  }

  void _openAdd() {
    final store = CapScope.of(context);
    showCapSheet<void>(
      context: context,
      heightFactor: 0.9,
      builder: (_) => _TodoEditorSheet(store: store),
    );
  }

  void _openEdit(CapTodo item) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.9,
      builder: (_) => _TodoEditorSheet(store: CapScope.of(context), existing: item),
    );
  }

  void _openAi(CapStore store) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.9,
      builder: (_) => _AiSheet(
        store: store,
        onAdded: () => setState(() => _filter = 'active'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final stats = store.todoStats;
    final todayStats = store.todayDoneStatsAt(DateTime.now());
    final pending = store.pendingTodos;
    final filtered = _filtered(store);
    final aiEnabled =
        store.settings.ai['enabled'] == true &&
        '${store.settings.ai['baseUrl'] ?? ''}'.isNotEmpty &&
        '${store.settings.ai['model'] ?? ''}'.isNotEmpty;

    final heroTitle = stats.total == 0
        ? '从一件小事开始'
        : stats.pending == 0
        ? '清单已经清空'
        : todayStats.total > 0 && todayStats.done >= todayStats.total
        ? '今天的节奏刚刚好'
        : '慢慢做，也会抵达';
    final heroSub = stats.total == 0
        ? '写下一件 25 分钟内能开始的小事。'
        : stats.pending == 0
        ? '给自己留一点空白，明天再继续。'
        : '今天完成 ${todayStats.done} / ${todayStats.total} 件，保持自己的节奏。';
    final listTitle = _filter == 'done'
        ? '已经完成的事'
        : _filter == 'active'
        ? '全部待办'
        : '今天要做的';
    final emptyTitle = _filter == 'done'
        ? '还没有完成记录'
        : _filter == 'active'
        ? '待办清单是空的'
        : '今天没有待办';
    final emptyText = _filter == 'done'
        ? '完成一件小事后，它会出现在这里。'
        : _filter == 'active'
        ? '把想做的事写下来，就不必一直记在心里。'
        : '给自己留一点空白，或者添加一个新计划。';
    final counts = {
      'today': store.todayTodosAt(DateTime.now()).length,
      'active': pending.length,
      'done': store.todos.where((item) => item.done).length,
    };

    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '待办清单',
            subtitle: '把大目标拆成今天能做的小事',
            back: true,
            right: HeaderIconButton(icon: 'plus', onTap: _openAdd),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    capRpx(context, 28),
                    capRpx(context, 6),
                    capRpx(context, 28),
                    capRpx(context, 190) + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    _hero(context, stats, todayStats, heroTitle, heroSub),
                    SizedBox(height: capRpx(context, 18)),
                    _aiEntry(context, aiEnabled, () => _openAi(store)),
                    SizedBox(height: capRpx(context, 22)),
                    _filterBar(context, counts),
                    _listHead(context, listTitle, filtered.length),
                    if (filtered.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 22),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(capRpx(context, 26)),
                          border: Border.all(color: AppColors.line, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.04),
                              blurRadius: capRpx(context, 28),
                              offset: Offset(0, capRpx(context, 10)),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < filtered.length; i += 1)
                              DragTarget<String>(
                                onWillAcceptWithDetails: (details) {
                                  if (details.data == filtered[i].id) return false;
                                  setState(() => _targetId = filtered[i].id);
                                  return true;
                                },
                                onLeave: (_) {
                                  if (_targetId == filtered[i].id) {
                                    setState(() => _targetId = null);
                                  }
                                },
                                onAcceptWithDetails: (details) {
                                  store.moveTodoBefore(
                                    details.data,
                                    filtered[i].id,
                                  );
                                  setState(() {
                                    _targetId = null;
                                    _draggingId = null;
                                  });
                                },
                                builder: (context, candidate, rejected) {
                                  return Container(
                                    decoration: _targetId == filtered[i].id
                                        ? const BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: AppColors.accent,
                                                width: 2,
                                              ),
                                            ),
                                          )
                                        : null,
                                    child: TodoRow(
                                      item: filtered[i],
                                      compact: false,
                                      showDivider: i < filtered.length - 1,
                                      dragging: _draggingId == filtered[i].id,
                                      draggable: _filter != 'done',
                                      onDragStarted: () => setState(
                                        () => _draggingId = filtered[i].id,
                                      ),
                                      onDragEnd: () => setState(() {
                                        _draggingId = null;
                                        _targetId = null;
                                      }),
                                      onTap: () => _openEdit(filtered[i]),
                                      onToggle: () {
                                        final target = filtered[i];
                                        store.toggleTodo(target.id);
                                        CapReminders.syncTodo(target);
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      )
                    else
                      _emptyCard(context, emptyTitle, emptyText),
                    SizedBox(height: capRpx(context, 22)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CapIcon(
                          'bell',
                          size: capRpx(context, 21),
                          color: AppColors.mutedSoft,
                        ),
                        SizedBox(width: capRpx(context, 6)),
                        Text(
                          '开启提醒后，由本机在设定时间发送系统通知。',
                          style: TextStyle(
                            fontSize: capRpx(context, 17),
                            color: AppColors.mutedSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: capRpx(context, 28),
                  right: capRpx(context, 28),
                  bottom:
                      capRpx(context, 18) + MediaQuery.paddingOf(context).bottom,
                  child: _PressableButton(
                    height: capRpx(context, 90),
                    onTap: _openAdd,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: capRpx(context, 42),
                          height: capRpx(context, 42),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(capRpx(context, 13)),
                          ),
                          child: Center(
                            child: CapIcon(
                              'plus',
                              size: capRpx(context, 31),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: capRpx(context, 9)),
                        Text(
                          '写下待办',
                          style: TextStyle(
                            fontSize: capRpx(context, 25),
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
          ),
        ],
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    CapTodoStats stats,
    CapTodoStats todayStats,
    String title,
    String sub,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 26),
        capRpx(context, 26),
        capRpx(context, 26),
        capRpx(context, 24),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capRpx(context, 32)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF132B4A), Color(0xFF0C192C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1A2E).withValues(alpha: 0.20),
            blurRadius: capRpx(context, 50),
            offset: Offset(0, capRpx(context, 24)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -capRpx(context, 30),
            top: -capRpx(context, 60),
            width: capRpx(context, 220),
            height: capRpx(context, 220),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5D88CF).withValues(alpha: 0.46),
                    const Color(0xFF5D88CF).withValues(alpha: 0),
                  ],
                  stops: const [0, 0.64],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S RHYTHM',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w700,
                        letterSpacing: capRpx(context, 3.6),
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 16)),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: capRpx(context, 36),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, -1.44),
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 6)),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: capRpx(context, 19),
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 20)),
                    Row(
                      children: [
                        _stat(context, stats.done, '已完成', true),
                        _statLine(context),
                        _stat(context, stats.pending, '待处理', true),
                        _statLine(context),
                        _stat(context, todayStats.total, '今日', false),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 16)),
              Align(
                alignment: Alignment.center,
                child: ProgressRing(
                  percent: stats.percent,
                  size: capRpx(context, 136),
                  stroke: capRpx(context, 11),
                  color: const Color(0xFFF1CF89),
                  track: Colors.white.withValues(alpha: 0.13),
                  holeColor: const Color(0xFF14263F),
                  valueStyle: TextStyle(
                    fontSize: capRpx(context, 32),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                  unitStyle: TextStyle(
                    fontSize: capRpx(context, 15),
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, int value, String label, bool flex) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: capRpx(context, 27),
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.2,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: capRpx(context, 15),
            color: Colors.white.withValues(alpha: 0.4),
            height: 1.3,
          ),
        ),
      ],
    );
    return flex ? Expanded(child: child) : child;
  }

  Widget _statLine(BuildContext context) {
    return Container(
      width: 2,
      height: capRpx(context, 28),
      margin: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  Widget _aiEntry(BuildContext context, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 22),
          vertical: capRpx(context, 20),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF243A5B), Color(0xFF17283F)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -capRpx(context, 20),
              top: -capRpx(context, 40),
              width: capRpx(context, 150),
              height: capRpx(context, 150),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEEC678).withValues(alpha: 0.28),
                      const Color(0xFFEEC678).withValues(alpha: 0),
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: capRpx(context, 62),
                  height: capRpx(context, 62),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1CF89).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(capRpx(context, 18)),
                  ),
                  child: Center(
                    child: CapIcon(
                      'sparkles',
                      size: capRpx(context, 34),
                      color: const Color(0xFFF1CF89),
                    ),
                  ),
                ),
                SizedBox(width: capRpx(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '智能拆解大目标',
                            style: TextStyle(
                              fontSize: capRpx(context, 24),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF7ECD8),
                            ),
                          ),
                          SizedBox(width: capRpx(context, 8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: capRpx(context, 7),
                              vertical: capRpx(context, 2),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8CD99).withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(capRpx(context, 6)),
                            ),
                            child: Text(
                              enabled ? '在线模型' : '本地智能',
                              style: TextStyle(
                                fontSize: capRpx(context, 14),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE8CD99),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: capRpx(context, 3)),
                      Text(
                        '写下一个目标，拆成清晰、有顺序的子任务',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 18),
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                CapIcon(
                  'arrow-up-right',
                  size: capRpx(context, 27),
                  color: Colors.white.withValues(alpha: 0.34),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar(BuildContext context, Map<String, int> counts) {
    const tabs = [
      ['today', '今天'],
      ['active', '待办'],
      ['done', '完成'],
    ];
    return Container(
      padding: EdgeInsets.all(capRpx(context, 5)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 18)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i += 1) ...[
            if (i > 0) SizedBox(width: capRpx(context, 6)),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = tabs[i][0]),
                child: AnimatedContainer(
                  duration: capsuleMotionFast,
                  curve: capsuleSpringCurve,
                  height: capRpx(context, 56),
                  decoration: BoxDecoration(
                    color: _filter == tabs[i][0]
                        ? AppColors.ink
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(capRpx(context, 13)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tabs[i][1],
                        style: TextStyle(
                          fontSize: capRpx(context, 21),
                          fontWeight: FontWeight.w600,
                          color: _filter == tabs[i][0]
                              ? Colors.white
                              : AppColors.muted,
                        ),
                      ),
                      SizedBox(width: capRpx(context, 5)),
                      Container(
                        height: capRpx(context, 24),
                        constraints: BoxConstraints(
                          minWidth: capRpx(context, 24),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 4),
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _filter == tabs[i][0]
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${counts[tabs[i][0]] ?? 0}',
                          style: TextStyle(
                            fontSize: capRpx(context, 14),
                            height: 1,
                            color: _filter == tabs[i][0]
                                ? Colors.white.withValues(alpha: 0.74)
                                : AppColors.muted,
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
    );
  }

  Widget _listHead(BuildContext context, String title, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 4),
        capRpx(context, 26),
        capRpx(context, 4),
        capRpx(context, 12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: capRpx(context, 26),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (_filter != 'done' && count > 0) ...[
            SizedBox(width: capRpx(context, 10)),
            Expanded(
              child: Text(
                '拖动右侧手柄调整优先级',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 17),
                  color: AppColors.mutedSoft,
                ),
              ),
            ),
          ] else
            const Spacer(),
          Text(
            '$count',
            style: TextStyle(
              fontSize: capRpx(context, 19),
              fontWeight: FontWeight.w700,
              color: AppColors.mutedSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String title, String text) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 30),
        capRpx(context, 54),
        capRpx(context, 30),
        capRpx(context, 44),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 28)),
        border: Border.all(color: AppColors.lineStrong, width: 1),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: capRpx(context, 118),
                height: capRpx(context, 118),
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CapIcon(
                    _filter == 'done' ? 'circle-check' : 'list-checks',
                    size: capRpx(context, 50),
                    color: AppColors.accent,
                  ),
                ),
              ),
              Positioned(
                left: -capRpx(context, 12),
                right: -capRpx(context, 12),
                top: -capRpx(context, 12),
                bottom: -capRpx(context, 12),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.lineStrong,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 20)),
          Text(
            title,
            style: TextStyle(
              fontSize: capRpx(context, 28),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 7)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: capRpx(context, 440)),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: capRpx(context, 20),
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ),
          if (_filter != 'done') ...[
            SizedBox(height: capRpx(context, 20)),
            GestureDetector(
              onTap: _openAdd,
              child: Container(
                height: capRpx(context, 62),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(capRpx(context, 15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CapIcon(
                      'plus',
                      size: capRpx(context, 25),
                      color: Colors.white,
                    ),
                    SizedBox(width: capRpx(context, 5)),
                    Text(
                      '写下一件小事',
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
          ],
        ],
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.child,
    required this.onTap,
    required this.height,
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: Duration(milliseconds: _down ? 90 : 140),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(capRpx(context, 25)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D1A2E).withValues(alpha: 0.28),
                blurRadius: capRpx(context, 42),
                offset: Offset(0, capRpx(context, 20)),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _TodoEditorSheet extends StatefulWidget {
  const _TodoEditorSheet({required this.store, this.existing});

  final CapStore store;
  final CapTodo? existing;

  @override
  State<_TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<_TodoEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late final TextEditingController _tags = TextEditingController(
    text: (widget.existing?.tags ?? const []).join(' '),
  );
  late String _dueDate;
  late String _dueTime;
  late bool _reminder;

  CapTodo? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _dueDate = _existing?.dueDate ?? formatDateKey();
    _dueTime = _existing?.dueTime ?? '';
    _reminder = _existing?.reminder ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  String get _todayKey => formatDateKey();
  String get _tomorrowKey =>
      formatDateKey(DateTime.now().add(const Duration(days: 1)));
  String get _weekEndKey {
    final now = DateTime.now();
    final daysUntilSunday = (7 - now.weekday % 7) % 7;
    return formatDateKey(now.add(Duration(days: daysUntilSunday)));
  }

  String _formatDue(String date) {
    if (date.isEmpty) return '';
    if (date == _todayKey) return '今天';
    if (date == _tomorrowKey) return '明天';
    return formatDateCNFromKey(date);
  }

  int _reminderTimestamp() {
    if (_dueDate.isEmpty) return 0;
    final date = parseDateKey(_dueDate);
    if (date == null) return 0;
    final clock = parseClock(_dueTime.isEmpty ? '20:00' : _dueTime);
    return DateTime(
      date.year,
      date.month,
      date.day,
      clock?.hour ?? 20,
      clock?.minute ?? 0,
    ).millisecondsSinceEpoch;
  }

  bool get _reminderPast =>
      _reminder && _reminderTimestamp() != 0 && _reminderTimestamp() <= DateTime.now().millisecondsSinceEpoch;

  Future<void> _pickDate() async {
    final initial = parseDateKey(_dueDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _dueDate = formatDateKey(picked));
    }
  }

  Future<void> _pickTime() async {
    final clock = parseClock(_dueTime.isEmpty ? '20:00' : _dueTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: clock?.hour ?? 20,
        minute: clock?.minute ?? 0,
      ),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _dueTime = '${pad2(picked.hour)}:${pad2(picked.minute)}');
    }
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.ink,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  void _toggleReminder() {
    setState(() {
      _reminder = !_reminder;
      if (_reminder && _dueDate.isEmpty) _dueDate = _todayKey;
      if (_reminder && _dueTime.isEmpty) _dueTime = '20:00';
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showCapToast(context, '先写下要做什么');
      return;
    }
    if (_reminderPast) {
      showCapToast(context, '提醒时间已经过去');
      return;
    }
    final tags = _tags.text
        .split(RegExp(r'[\s,，、]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(4)
        .toList();
    final existing = _existing;
    final reminderAt = _reminder ? _reminderTimestamp() : 0;
    CapTodo? saved;
    if (existing == null) {
      saved = widget.store.addTodo(
        title: title,
        note: _note.text,
        dueDate: _dueDate,
        dueTime: _dueTime,
        tags: tags,
        reminder: _reminder,
        reminderAt: reminderAt,
        priority: widget.store.todos.length,
      );
    } else {
      existing
        ..title = title
        ..note = _note.text.trim()
        ..dueDate = _dueDate
        ..dueTime = _dueTime
        ..tags = tags
        ..reminder = _reminder
        ..reminderAt = reminderAt
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      saved = widget.store.upsertTodo(existing);
    }
    if (saved != null) CapReminders.syncTodo(saved);
    showCapToast(context, existing == null ? '已加入清单' : '已保存修改');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 26)),
        ),
        title: Text(
          '删除这条待办',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '删除后无法恢复。',
          style: TextStyle(fontSize: capRpx(context, 22), color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.store.removeTodo(existing.id);
      CapReminders.cancel(CapReminders.todoKey(existing.id));
      if (mounted) showCapToast(context, '已删除');
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    final labels = ['今天', '明天', '本周内'];
    final keys = [_todayKey, _tomorrowKey, _weekEndKey];
    return CapSheetPanel(
      title: existing == null ? '新的待办' : '编辑待办',
      subtitle: existing == null ? '先写下一件具体的小事' : '调整时间或提醒',
      footer: Row(
        children: [
          if (existing != null) ...[
            GestureDetector(
              onTap: _delete,
              child: Container(
                width: capRpx(context, 86),
                height: capRpx(context, 86),
                decoration: BoxDecoration(
                  color: AppColors.coralSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                ),
                child: Center(
                  child: CapIcon(
                    'trash-2',
                    size: capRpx(context, 27),
                    color: AppColors.coral,
                  ),
                ),
              ),
            ),
            SizedBox(width: capRpx(context, 10)),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _save,
              child: Container(
                height: capRpx(context, 86),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      'check',
                      size: capRpx(context, 27),
                      color: Colors.white,
                    ),
                    SizedBox(width: capRpx(context, 7)),
                    Text(
                      existing == null ? '加入清单' : '保存修改',
                      style: TextStyle(
                        fontSize: capRpx(context, 25),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, '要做什么'),
          Container(
            height: capRpx(context, 92),
            padding: EdgeInsets.symmetric(horizontal: capRpx(context, 26)),
            decoration: _fieldDecoration(context),
            child: TextField(
              controller: _title,
              autofocus: true,
              maxLength: 80,
              style: TextStyle(
                fontSize: capRpx(context, 27),
                color: AppColors.ink,
              ),
              decoration: _inputDecoration(
                context,
                '例如：整理机械设计作业的草图',
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          _label(context, '补充说明'),
          Container(
            constraints: BoxConstraints(minHeight: capRpx(context, 150)),
            padding: EdgeInsets.symmetric(
              horizontal: capRpx(context, 22),
              vertical: capRpx(context, 18),
            ),
            decoration: _fieldDecoration(context),
            child: TextField(
              controller: _note,
              maxLines: null,
              maxLength: 300,
              style: TextStyle(
                fontSize: capRpx(context, 24),
                height: 1.6,
                color: AppColors.ink,
              ),
              decoration: _inputDecoration(
                context,
                '补充上下文、步骤或完成标准（选填）',
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          _label(context, '截止日期'),
          Wrap(
            spacing: capRpx(context, 8),
            runSpacing: capRpx(context, 8),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < labels.length; i += 1)
                _dateChip(
                  context,
                  labels[i],
                  active: _dueDate == keys[i],
                  onTap: () => setState(() => _dueDate = keys[i]),
                ),
              _dateChip(
                context,
                _dueDate.isEmpty ? '选日期' : _formatDue(_dueDate),
                icon: 'calendar-plus',
                active: false,
                onTap: _pickDate,
              ),
              if (_dueDate.isNotEmpty)
                _dateChip(
                  context,
                  '清除',
                  active: false,
                  danger: true,
                  onTap: () => setState(() => _dueDate = ''),
                ),
            ],
          ),
          SizedBox(height: capRpx(context, 20)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, '时间'),
                    GestureDetector(
                      onTap: _pickTime,
                      child: _pickerBox(
                        context,
                        icon: 'clock-3',
                        text: _dueTime.isEmpty ? '未设置' : _dueTime,
                        trailing: 'chevron-down',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, '标签'),
                    Container(
                      height: capRpx(context, 88),
                      padding: EdgeInsets.symmetric(
                        horizontal: capRpx(context, 16),
                      ),
                      decoration: _fieldDecoration(context),
                      child: TextField(
                        controller: _tags,
                        style: TextStyle(
                          fontSize: capRpx(context, 22),
                          color: AppColors.ink,
                        ),
                        decoration: _inputDecoration(context, '学习 生活'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 20)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: capRpx(context, 20),
              vertical: capRpx(context, 18),
            ),
            decoration: BoxDecoration(
              gradient: _reminder
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF2F6FD), Color(0xFFFBF7EE)],
                    )
                  : null,
              color: _reminder ? null : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 22)),
              border: Border.all(
                color: _reminder
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : AppColors.line,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CapIcon(
                                'bell',
                                size: capRpx(context, 26),
                                color: AppColors.ink,
                              ),
                              SizedBox(width: capRpx(context, 7)),
                              Text(
                                '到点提醒',
                                style: TextStyle(
                                  fontSize: capRpx(context, 23),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: capRpx(context, 3)),
                          Text(
                            !_reminder
                                ? '关闭时不会发送通知'
                                : '在 ${_formatDue(_dueDate.isEmpty ? _todayKey : _dueDate)} ${_dueTime.isEmpty ? '20:00' : _dueTime} 提醒',
                            style: TextStyle(
                              fontSize: capRpx(context, 18),
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CapToggle(value: _reminder, onChanged: (_) => _toggleReminder()),
                  ],
                ),
                if (_reminder && _reminderPast) ...[
                  SizedBox(height: capRpx(context, 12)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CapIcon(
                        'triangle-alert',
                        size: capRpx(context, 20),
                        color: AppColors.coral,
                      ),
                      SizedBox(width: capRpx(context, 6)),
                      Expanded(
                        child: Text(
                          '提醒时间已经过去，换一个未来时间吧。',
                          style: TextStyle(
                            fontSize: capRpx(context, 18),
                            height: 1.5,
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 4),
        0,
        capRpx(context, 4),
        capRpx(context, 12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 22),
          fontWeight: FontWeight.w700,
          letterSpacing: capRpx(context, 0.9),
          color: AppColors.muted,
        ),
      ),
    );
  }

  BoxDecoration _fieldDecoration(BuildContext context) => BoxDecoration(
    color: AppColors.surfaceSoft,
    borderRadius: BorderRadius.circular(capRpx(context, 22)),
    border: Border.all(color: AppColors.line, width: 0.8),
  );

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: capRpx(context, 22),
        color: AppColors.mutedSoft,
      ),
      counterText: '',
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _dateChip(
    BuildContext context,
    String text, {
    required bool active,
    required VoidCallback onTap,
    String? icon,
    bool danger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 50),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 15)),
        decoration: BoxDecoration(
          color: danger
              ? AppColors.coralSoft
              : active
              ? AppColors.accentSoft
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 13)),
          border: Border.all(
            color: danger
                ? Colors.transparent
                : active
                ? AppColors.accent.withValues(alpha: 0.14)
                : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              CapIcon(
                icon,
                size: capRpx(context, 19),
                color: active ? AppColors.accent : AppColors.muted,
              ),
              SizedBox(width: capRpx(context, 4)),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: capRpx(context, 19),
                fontWeight: FontWeight.w600,
                color: danger
                    ? AppColors.coral
                    : active
                    ? AppColors.accent
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerBox(
    BuildContext context, {
    required String icon,
    required String text,
    required String trailing,
  }) {
    return Container(
      height: capRpx(context, 88),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
      decoration: _fieldDecoration(context),
      child: Row(
        children: [
          CapIcon(icon, size: capRpx(context, 24), color: AppColors.ink),
          SizedBox(width: capRpx(context, 8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: capRpx(context, 22),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          CapIcon(
            trailing,
            size: capRpx(context, 20),
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _AiSheet extends StatefulWidget {
  const _AiSheet({required this.store, required this.onAdded});

  final CapStore store;
  final VoidCallback onAdded;

  @override
  State<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends State<_AiSheet> {
  final TextEditingController _goal = TextEditingController();
  late String _deadline;
  bool _loading = false;
  List<PlannerTask> _tasks = [];
  String _source = 'local';
  String _notice = '';
  String _error = '';

  static const _examples = ['四周内通过英语四级', '两周内完成课程设计', '准备一次三天的旅行'];

  @override
  void initState() {
    super.initState();
    _deadline = formatDateKey(DateTime.now().add(const Duration(days: 14)));
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  bool get _aiEnabled =>
      widget.store.settings.ai['enabled'] == true &&
      '${widget.store.settings.ai['baseUrl'] ?? ''}'.isNotEmpty &&
      '${widget.store.settings.ai['model'] ?? ''}'.isNotEmpty;

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateKey(_deadline) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = formatDateKey(picked));
  }

  Future<void> _run() async {
    if (_loading) return;
    if (_goal.text.trim().isEmpty) {
      showCapToast(context, '先写下大目标');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _notice = '';
    });
    final result = await decomposeGoal(
      goal: _goal.text,
      deadline: _deadline,
      settings: {'ai': widget.store.settings.ai},
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!result.ok) {
        _error = result.error.isEmpty ? '拆解失败，请稍后再试' : result.error;
      } else {
        _tasks = result.tasks.map((task) => task..selected = true).toList();
        _source = result.source;
        _notice = result.notice;
      }
    });
  }

  void _confirm() {
    final selected = _tasks.where((task) => task.selected).toList();
    if (selected.isEmpty) {
      showCapToast(context, '至少选择一条任务');
      return;
    }
    for (final task in selected) {
      widget.store.addTodo(
        title: task.title,
        note: task.note,
        dueDate: task.dueDate,
        tags: task.tags,
        priority: widget.store.todos.length,
      );
    }
    widget.onAdded();
    showCapToast(context, '已加入 ${selected.length} 条待办');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _tasks.where((task) => task.selected).length;
    final allSelected = _tasks.isNotEmpty && selectedCount == _tasks.length;
    return CapSheetPanel(
      title: '智能拆解',
      subtitle: '把一个模糊的大目标，变成今天就能开始的动作',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: capRpx(context, 74),
                height: capRpx(context, 74),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 22)),
                ),
                child: Center(
                  child: CapIcon(
                    'sparkles',
                    size: capRpx(context, 38),
                    color: AppColors.accent,
                  ),
                ),
              ),
              SizedBox(width: capRpx(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你正在靠近什么？',
                      style: TextStyle(
                        fontSize: capRpx(context, 25),
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 2)),
                    Text(
                      _aiEnabled ? '将使用你配置的在线大模型' : '使用完全离线的本地规划模板',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 18)),
          Text(
            '大目标',
            style: TextStyle(
              fontSize: capRpx(context, 22),
              fontWeight: FontWeight.w700,
              letterSpacing: capRpx(context, 0.9),
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 12)),
          Container(
            constraints: BoxConstraints(minHeight: capRpx(context, 146)),
            padding: EdgeInsets.symmetric(
              horizontal: capRpx(context, 22),
              vertical: capRpx(context, 18),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 20)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: TextField(
              controller: _goal,
              maxLines: null,
              maxLength: 300,
              style: TextStyle(
                fontSize: capRpx(context, 23),
                height: 1.6,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: '例如：四周内通过英语四级，每天能投入 1 小时',
                hintStyle: TextStyle(
                  fontSize: capRpx(context, 21),
                  color: AppColors.mutedSoft,
                ),
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 10)),
          Wrap(
            spacing: capRpx(context, 6),
            runSpacing: capRpx(context, 6),
            children: [
              for (final example in _examples)
                GestureDetector(
                  onTap: () => setState(() => _goal.text = example),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 10),
                      vertical: capRpx(context, 6),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(capRpx(context, 8)),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    child: Text(
                      example,
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: capRpx(context, 20)),
          Text(
            '截止日期',
            style: TextStyle(
              fontSize: capRpx(context, 22),
              fontWeight: FontWeight.w700,
              letterSpacing: capRpx(context, 0.9),
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 12)),
          GestureDetector(
            onTap: _pickDeadline,
            child: Container(
              height: capRpx(context, 92),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 18)),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: Row(
                children: [
                  CapIcon(
                    'calendar-days',
                    size: capRpx(context, 25),
                    color: AppColors.ink,
                  ),
                  SizedBox(width: capRpx(context, 8)),
                  Expanded(
                    child: Text(
                      _deadline.isEmpty ? '不设截止日期' : _deadline,
                      style: TextStyle(
                        fontSize: capRpx(context, 23),
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  CapIcon(
                    'chevron-down',
                    size: capRpx(context, 20),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 18)),
          GestureDetector(
            onTap: _run,
            child: Opacity(
              opacity: _loading ? 0.7 : 1,
              child: Container(
                height: capRpx(context, 82),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1C3E70), Color(0xFF0F2038)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10233C).withValues(alpha: 0.18),
                      blurRadius: capRpx(context, 30),
                      offset: Offset(0, capRpx(context, 14)),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      _loading ? 'loader-circle' : 'sparkles',
                      size: capRpx(context, 30),
                      color: Colors.white,
                    ),
                    SizedBox(width: capRpx(context, 8)),
                    Text(
                      _loading ? '正在拆解…' : '开始拆解',
                      style: TextStyle(
                        fontSize: capRpx(context, 23),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_notice.isNotEmpty || _error.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 12)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 14),
                vertical: capRpx(context, 12),
              ),
              decoration: BoxDecoration(
                color: _error.isNotEmpty ? AppColors.coralSoft : AppColors.goldSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CapIcon(
                    _error.isNotEmpty ? 'triangle-alert' : 'info',
                    size: capRpx(context, 21),
                    color: _error.isNotEmpty ? AppColors.coral : const Color(0xFF7E561E),
                  ),
                  SizedBox(width: capRpx(context, 6)),
                  Expanded(
                    child: Text(
                      _error.isNotEmpty ? _error : _notice,
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        height: 1.5,
                        color: _error.isNotEmpty
                            ? const Color(0xFF9B3D2C)
                            : const Color(0xFF7E561E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tasks.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 20)),
            Container(
              padding: EdgeInsets.only(top: capRpx(context, 18)),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '拆解结果',
                          style: TextStyle(
                            fontSize: capRpx(context, 22),
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 9),
                          vertical: capRpx(context, 3),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(capRpx(context, 7)),
                        ),
                        child: Text(
                          _source == 'ai' ? '在线模型' : '本地智能',
                          style: TextStyle(
                            fontSize: capRpx(context, 16),
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: capRpx(context, 10)),
                  for (var i = 0; i < _tasks.length; i += 1) ...[
                    if (i > 0) SizedBox(height: capRpx(context, 8)),
                    GestureDetector(
                      onTap: () => setState(
                        () => _tasks[i].selected = !_tasks[i].selected,
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _tasks[i].selected ? 1 : 0.6,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: capRpx(context, 12),
                            vertical: capRpx(context, 13),
                          ),
                          decoration: BoxDecoration(
                            color: _tasks[i].selected
                                ? AppColors.surface
                                : AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(capRpx(context, 14)),
                            border: Border.all(
                              color: _tasks[i].selected
                                  ? AppColors.line
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: capRpx(context, 34),
                                height: capRpx(context, 34),
                                margin: EdgeInsets.only(top: capRpx(context, 2)),
                                decoration: BoxDecoration(
                                  color: _tasks[i].selected
                                      ? AppColors.ink
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(capRpx(context, 10)),
                                  border: Border.all(
                                    color: _tasks[i].selected
                                        ? AppColors.ink
                                        : AppColors.lineStrong,
                                    width: 1.5,
                                  ),
                                ),
                                child: _tasks[i].selected
                                    ? Center(
                                        child: CapIcon(
                                          'check',
                                          size: capRpx(context, 19),
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: capRpx(context, 10)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tasks[i].title,
                                      style: TextStyle(
                                        fontSize: capRpx(context, 21),
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    if (_tasks[i].note.isNotEmpty) ...[
                                      SizedBox(height: capRpx(context, 3)),
                                      Text(
                                        _tasks[i].note,
                                        style: TextStyle(
                                          fontSize: capRpx(context, 18),
                                          height: 1.5,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                    if (_tasks[i].dueDate.isNotEmpty ||
                                        _tasks[i].tags.isNotEmpty) ...[
                                      SizedBox(height: capRpx(context, 3)),
                                      Wrap(
                                        spacing: capRpx(context, 6),
                                        children: [
                                          if (_tasks[i].dueDate.isNotEmpty)
                                            Text(
                                              _formatTaskDate(_tasks[i].dueDate),
                                              style: TextStyle(
                                                fontSize: capRpx(context, 16),
                                                color: AppColors.mutedSoft,
                                              ),
                                            ),
                                          for (final tag in _tasks[i].tags)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: capRpx(context, 7),
                                                vertical: capRpx(context, 1),
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceSoft,
                                                borderRadius: BorderRadius.circular(
                                                  capRpx(context, 5),
                                                ),
                                              ),
                                              child: Text(
                                                tag,
                                                style: TextStyle(
                                                  fontSize: capRpx(context, 16),
                                                  color: AppColors.mutedSoft,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: capRpx(context, 16)),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          final next = !allSelected;
                          for (final task in _tasks) {
                            task.selected = next;
                          }
                        }),
                        child: Text(
                          allSelected ? '取消全选' : '全选',
                          style: TextStyle(
                            fontSize: capRpx(context, 19),
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _confirm,
                        child: Container(
                          height: capRpx(context, 66),
                          padding: EdgeInsets.symmetric(
                            horizontal: capRpx(context, 18),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(capRpx(context, 16)),
                          ),
                          child: Row(
                            children: [
                              CapIcon(
                                'plus',
                                size: capRpx(context, 25),
                                color: Colors.white,
                              ),
                              SizedBox(width: capRpx(context, 6)),
                              Text(
                                '加入清单（$selectedCount）',
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
                    ],
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: capRpx(context, 22)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CapIcon(
                'lock-keyhole',
                size: capRpx(context, 20),
                color: AppColors.mutedSoft,
              ),
              SizedBox(width: capRpx(context, 6)),
              Expanded(
                child: Text(
                  '使用本地智能时不联网；在线模型只发送目标文字与截止日期。',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    height: 1.5,
                    color: AppColors.mutedSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTaskDate(String date) {
    if (date == formatDateKey()) return '今天';
    if (date == formatDateKey(DateTime.now().add(const Duration(days: 1)))) {
      return '明天';
    }
    return formatDateCNFromKey(date);
  }
}
