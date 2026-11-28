import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/cap_store.dart';
import '../services/cap_system.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_toast.dart';
import '../widgets/countdown_card.dart';
import '../widgets/progress_ring.dart';
import 'academic_sync_page.dart';
import 'countdown_page.dart';
import 'electricity_page.dart';
import 'ledger_page.dart';
import 'settings_page.dart';
import 'todo_page.dart';

class AffairsTab extends StatelessWidget {
  const AffairsTab({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final now = DateTime.now();
    final pending = store.pendingTodos;
    final todoStats = store.todoStats;
    final todayStats = store.todayDoneStatsAt(now);
    final nearest = store.nearestCountdown;
    final ledger = store.ledgerSummaryAt(now);
    final ledgerSpent = formatMoney(ledger.spentCents, compact: true);
    final ledgerRemain = ledger.hasBudget
        ? formatMoney(ledger.remainingCents, compact: true)
        : '未设置';
    final pendingCaptures = store.ledger.pending.length;
    final ledgerHint = pendingCaptures > 0
        ? '自动识别到 $pendingCaptures 笔，等你确认'
        : !ledger.hasBudget
        ? '设置预算，看清这个月还能花多少'
        : ledger.remainingCents < 0
        ? '已超出预算 ${formatMoney(ledger.remainingCents.abs(), compact: true)} 元'
        : ledger.hint;
    final overviewTitle = todoStats.total == 0
        ? '今天，从一件小事开始'
        : todayStats.total > 0 && todayStats.done >= todayStats.total
        ? '今天的清单已经清空'
        : '还有 ${pending.length} 件事在路上';
    final overviewSub = nearest != null
        ? '${nearest.title} ${_countdownDayText(nearest)}'
        : '把日子安排好，心就会慢慢安静下来';
    final todoHint = todoStats.total == 0
        ? '从一件小事开始'
        : '已完成 ${todoStats.done} / ${todoStats.total}';
    final scheduleHint = store.courses.isEmpty
        ? 'WebVPN 登录后提取'
        : '第 ${store.settings.totalWeeks} 周学期 · 本地已保存';
    final electricityValue = store.electricityValue;
    final electricityUnit = store.electricityUnit;
    final electricityHint = store.electricity['binding'] is Map
        ? (store.electricityHint.isEmpty ? '点击刷新余额' : store.electricityHint)
        : '绑定寝室后查看';
    final apps = [
      ('schedule', '课表', 'calendar-days', AppColors.accentSoft, AppColors.accent),
      ('countdown', '倒计日', 'hourglass', AppColors.goldSoft, const Color(0xFF9A6A22)),
      ('todo', '待办', 'list-checks', const Color(0xFFE9EEFB), const Color(0xFF2D5BD1)),
      ('electricity', '用电', 'zap', AppColors.mintSoft, AppColors.mint),
      ('tieba', '贴吧', 'message-circle', const Color(0xFFF3E7D2), const Color(0xFF9A6B2F)),
      ('settings', '设置', 'settings', AppColors.surfaceSoft, AppColors.muted),
    ];

    return ListView(
      padding: EdgeInsets.only(
        bottom: capRpx(context, 246) + safeBottom,
      ),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            capRpx(context, 36),
            safeTop + capRpx(context, 10),
            capRpx(context, 36),
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AFFAIRS · 一站式事务',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w700,
                        letterSpacing: capRpx(context, 3.6),
                        color: AppColors.muted,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    Text(
                      '事务',
                      style: TextStyle(
                        fontSize: capRpx(context, 60),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, -2.4),
                        height: 1.05,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    Text(
                      '把复杂的事，排成一条清楚的线。',
                      style: TextStyle(
                        fontSize: capRpx(context, 24),
                        color: AppColors.muted,
                        letterSpacing: capRpx(context, 0.24),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: capRpx(context, 18)),
              Padding(
                padding: EdgeInsets.only(top: capRpx(context, 4)),
                child: _iconButton(
                  context,
                  'settings',
                  () => _push(context, const SettingsPage()),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: capRpx(context, 30)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
          child: _overview(
            context,
            store,
            now,
            todayStats,
            overviewTitle,
            overviewSub,
          ),
        ),
        _sectionHead(
          context,
          title: '倒计日',
          badge: '${store.countdowns.length}',
          action: '全部日子',
          onAction: () => _push(context, const CountdownPage()),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
          child: nearest != null
              ? CountdownCard(
                  item: nearest,
                  variant: CountdownVariant.compact,
                  onTap: () => _push(context, const CountdownPage()),
                )
              : GestureDetector(
                  onTap: () => _push(context, const CountdownPage()),
                  child: Container(
                    padding: EdgeInsets.all(capRpx(context, 28)),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(capRpx(context, 30)),
                      border: Border.all(
                        color: AppColors.lineStrong,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: capRpx(context, 76),
                          height: capRpx(context, 76),
                          decoration: BoxDecoration(
                            color: AppColors.goldSoft,
                            borderRadius: BorderRadius.circular(capRpx(context, 23)),
                          ),
                          child: Center(
                            child: CapIcon(
                              'calendar-plus',
                              size: capRpx(context, 38),
                              color: const Color(0xFF96621D),
                            ),
                          ),
                        ),
                        SizedBox(width: capRpx(context, 16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '建立第一个倒计日',
                                style: TextStyle(
                                  fontSize: capRpx(context, 26),
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: capRpx(context, 3)),
                              Text(
                                '考试、生日、旅行，都值得被期待',
                                style: TextStyle(
                                  fontSize: capRpx(context, 20),
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CapIcon(
                          'plus',
                          size: capRpx(context, 30),
                          color: AppColors.ink,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        _sectionHead(context, title: '事务工具', caption: 'LOCAL FIRST'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
          child: Column(
            children: [
              _ledgerTool(
                context,
                ledger,
                ledgerSpent,
                ledgerRemain,
                ledgerHint,
              ),
              SizedBox(height: capRpx(context, 14)),
              _todoTool(context, pending.length, todoStats, todoHint),
              SizedBox(height: capRpx(context, 14)),
              Row(
                children: [
                  Expanded(
                    child: _syncTool(
                      context,
                      store.courses.length,
                      scheduleHint,
                    ),
                  ),
                  SizedBox(width: capRpx(context, 14)),
                  Expanded(
                    child: _electricTool(
                      context,
                      electricityValue,
                      electricityUnit,
                      electricityHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _sectionHead(context, title: '小应用', caption: 'QUICK ACCESS'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: capRpx(context, 10),
              vertical: capRpx(context, 16),
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(capRpx(context, 24)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                for (final app in apps)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        switch (app.$1) {
                          case 'schedule':
                            onOpenTab?.call(1);
                            break;
                          case 'countdown':
                            _push(context, const CountdownPage());
                            break;
                          case 'todo':
                            _push(context, const TodoPage());
                            break;
                          case 'electricity':
                            _push(context, const ElectricityPage());
                            break;
                          case 'tieba':
                            onOpenTab?.call(3);
                            break;
                          case 'settings':
                            _push(context, const SettingsPage());
                            break;
                        }
                      },
                      child: Column(
                        children: [
                          Container(
                            width: capRpx(context, 68),
                            height: capRpx(context, 68),
                            decoration: BoxDecoration(
                              color: app.$4,
                              borderRadius: BorderRadius.circular(capRpx(context, 21)),
                            ),
                            child: Center(
                              child: CapIcon(
                                app.$3,
                                size: capRpx(context, 30),
                                color: app.$5,
                              ),
                            ),
                          ),
                          SizedBox(height: capRpx(context, 6)),
                          Text(
                            app.$2,
                            style: TextStyle(
                              fontSize: capRpx(context, 16),
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _sectionHead(context, title: '本机数据'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 28)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: capRpx(context, 6),
              vertical: capRpx(context, 4),
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(capRpx(context, 24)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _dataItem(
                    context,
                    icon: 'shield-check',
                    title: '隐私与缓存',
                    sub: '账号只留在本机',
                    onTap: () => _push(context, const SettingsPage()),
                  ),
                ),
                Container(
                  width: 1,
                  margin: EdgeInsets.symmetric(vertical: capRpx(context, 12)),
                  color: AppColors.line,
                ),
                Expanded(
                  child: _dataItem(
                    context,
                    icon: 'bell',
                    title: '测试提醒',
                    sub: '检查通知权限',
                    onTap: () async {
                      final granted =
                          await CapSystem.requestNotificationPermission();
                      if (!granted) {
                        showCapToast(context, '还没有通知权限');
                        return;
                      }
                      await CapSystem.notifyNow(
                        title: 'CapuLife 提醒测试',
                        content: '通知已经准备好了。',
                      );
                      if (context.mounted) {
                        showCapToast(context, '已发送测试提醒');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: capRpx(context, 48)),
        Column(
          children: [
            Container(
              width: capRpx(context, 36),
              height: 1,
              color: AppColors.lineStrong,
              margin: EdgeInsets.only(bottom: capRpx(context, 10)),
            ),
            Text(
              'CapuLife · $appSchool',
              style: TextStyle(
                fontSize: capRpx(context, 18),
                color: AppColors.mutedSoft,
              ),
            ),
            SizedBox(height: capRpx(context, 4)),
            Text(
              '事务中心 · $appVersion',
              style: TextStyle(
                fontSize: capRpx(context, 16),
                color: AppColors.mutedSoft.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _countdownDayText(CapCountdown item) {
    final diff = diffDays(item.targetDate);
    if (diff == 0) return '今天';
    if (diff > 0) return '还有 $diff 天';
    return '已过去 ${diff.abs()} 天';
  }

  Widget _iconButton(BuildContext context, String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 68),
        height: capRpx(context, 68),
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
          child: CapIcon(icon, size: capRpx(context, 30), color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _overview(
    BuildContext context,
    CapStore store,
    DateTime now,
    CapTodoStats todayStats,
    String title,
    String sub,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(capRpx(context, 36)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 28),
          capRpx(context, 28),
          capRpx(context, 28),
          capRpx(context, 26),
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF112845), Color(0xFF0D1C31)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -capRpx(context, 60),
              top: -capRpx(context, 90),
              width: capRpx(context, 260),
              height: capRpx(context, 260),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF608CD5).withValues(alpha: 0.5),
                      const Color(0xFF608CD5).withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${now.day}',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: capRpx(context, 72),
                            fontWeight: FontWeight.w800,
                            height: 0.9,
                            letterSpacing: capRpx(context, -4.3),
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: capRpx(context, 14)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weekdayCN(now),
                              style: TextStyle(
                                fontSize: capRpx(context, 22),
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            SizedBox(height: capRpx(context, 3)),
                            Text(
                              '${now.year} / ${now.month} 月',
                              style: TextStyle(
                                fontSize: capRpx(context, 16),
                                letterSpacing: capRpx(context, 2.2),
                                color: Colors.white.withValues(alpha: 0.48),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: 0.95,
                      child: ProgressRing(
                        percent: todayStats.percent,
                        size: capRpx(context, 94),
                        stroke: capRpx(context, 8),
                        color: const Color(0xFFF0C476),
                        track: Colors.white.withValues(alpha: 0.14),
                        holeColor: const Color(0xFF13233C),
                        valueStyle: TextStyle(
                          fontSize: capRpx(context, 25),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                        unitStyle: TextStyle(
                          fontSize: capRpx(context, 14),
                          color: Colors.white.withValues(alpha: 0.55),
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 26)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: capRpx(context, 540)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: capRpx(context, 34),
                          fontWeight: FontWeight.w800,
                          letterSpacing: capRpx(context, -1),
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: capRpx(context, 6)),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: capRpx(context, 21),
                          height: 1.6,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: capRpx(context, 24)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _push(context, const TodoPage(openAdd: true)),
                      child: Container(
                        height: capRpx(context, 64),
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 20),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F0E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            CapIcon(
                              'plus',
                              size: capRpx(context, 26),
                              color: const Color(0xFF172439),
                            ),
                            SizedBox(width: capRpx(context, 7)),
                            Text(
                              '记一件小事',
                              style: TextStyle(
                                fontSize: capRpx(context, 21),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF172439),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 12)),
                    GestureDetector(
                      onTap: () => _push(context, const TodoPage()),
                      child: Container(
                        height: capRpx(context, 64),
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 20),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '查看今日',
                              style: TextStyle(
                                fontSize: capRpx(context, 21),
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            CapIcon(
                              'chevron-right',
                              size: capRpx(context, 24),
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHead(
    BuildContext context, {
    required String title,
    String caption = '',
    String badge = '',
    String action = '',
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 38),
        capRpx(context, 46),
        capRpx(context, 38),
        capRpx(context, 20),
      ),
      child: Row(
        children: [
          if (badge.isEmpty && caption.isEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: capRpx(context, 30),
                fontWeight: FontWeight.w800,
                letterSpacing: capRpx(context, -0.6),
                color: AppColors.ink,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: capRpx(context, 30),
                    fontWeight: FontWeight.w800,
                    letterSpacing: capRpx(context, -0.6),
                    color: AppColors.ink,
                  ),
                ),
                if (badge.isNotEmpty) ...[
                  SizedBox(width: capRpx(context, 10)),
                  Container(
                    constraints: BoxConstraints(
                      minWidth: capRpx(context, 32),
                      minHeight: capRpx(context, 30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 8)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: capRpx(context, 16),
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          const Spacer(),
          if (caption.isNotEmpty)
            Text(
              caption,
              style: TextStyle(
                fontSize: capRpx(context, 15),
                fontWeight: FontWeight.w700,
                letterSpacing: capRpx(context, 2.4),
                color: AppColors.mutedSoft,
              ),
            ),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  CapIcon(
                    'chevron-right',
                    size: capRpx(context, 25),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ledgerTool(
    BuildContext context,
    CapLedgerSummary ledger,
    String spent,
    String remain,
    String hint,
  ) {
    final remainColor = ledger.tone == 'low'
        ? AppColors.coral
        : ledger.tone == 'mid'
        ? const Color(0xFF9A641F)
        : AppColors.mint;
    final fillColors = ledger.tone == 'low'
        ? const [Color(0xFFCD5B45), Color(0xFFE88E77)]
        : ledger.tone == 'mid'
        ? const [Color(0xFFC89445), Color(0xFFE0B06A)]
        : const [AppColors.accent, Color(0xFF4F83E7)];
    return GestureDetector(
      onTap: () => _push(context, const LedgerPage()),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 24),
          capRpx(context, 22),
          capRpx(context, 24),
          capRpx(context, 18),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: capRpx(context, 28),
              offset: Offset(0, capRpx(context, 10)),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _toolIcon(context, 'wallet', AppColors.goldSoft, const Color(0xFF9A641F)),
                SizedBox(width: capRpx(context, 16)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '记账',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: capRpx(context, 20),
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        SizedBox(width: capRpx(context, 3)),
                        Text(
                          spent,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: capRpx(context, 48),
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: capRpx(context, -2.9),
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '预算剩余',
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                    Text(
                      remain,
                      style: TextStyle(
                        fontSize: capRpx(context, 30),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, -0.9),
                        color: remainColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: capRpx(context, 8)),
                CapIcon(
                  'arrow-up-right',
                  size: capRpx(context, 25),
                  color: AppColors.mutedSoft,
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 14)),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: capRpx(context, 8),
                color: AppColors.surfaceSoft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: ledger.percent / 100),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0, 1),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: fillColors),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 8)),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 17),
                  color: AppColors.mutedSoft,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todoTool(
    BuildContext context,
    int pendingCount,
    CapTodoStats stats,
    String hint,
  ) {
    return GestureDetector(
      onTap: () => _push(context, const TodoPage()),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 24),
          capRpx(context, 22),
          capRpx(context, 24),
          capRpx(context, 18),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: capRpx(context, 28),
              offset: Offset(0, capRpx(context, 10)),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _toolIcon(context, 'list-checks', AppColors.accentSoft, AppColors.accent),
                SizedBox(width: capRpx(context, 16)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '待办清单',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$pendingCount',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: capRpx(context, 48),
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: capRpx(context, -2.9),
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(width: capRpx(context, 5)),
                        Text(
                          '件待办',
                          style: TextStyle(
                            fontSize: capRpx(context, 18),
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '已完成',
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                    Text(
                      '${stats.done}/${stats.total}',
                      style: TextStyle(
                        fontSize: capRpx(context, 30),
                        fontWeight: FontWeight.w800,
                        letterSpacing: capRpx(context, -0.9),
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: capRpx(context, 8)),
                CapIcon(
                  'arrow-up-right',
                  size: capRpx(context, 25),
                  color: AppColors.mutedSoft,
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 14)),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: capRpx(context, 8),
                color: AppColors.surfaceSoft,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: stats.percent / 100,
                      heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F83E7), AppColors.accent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 8)),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: capRpx(context, 17),
                  color: AppColors.mutedSoft,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncTool(BuildContext context, int count, String hint) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: capWebViewRouteName),
          builder: (_) => const AcademicSyncPage(),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: capRpx(context, 268)),
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 22),
          capRpx(context, 22),
          capRpx(context, 22),
          capRpx(context, 20),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
          border: Border.all(color: AppColors.line, width: 0.8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9EE), Color(0xFFF5E8D2)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _toolIcon(context, 'calendar-days', AppColors.goldSoft, const Color(0xFF9A641F)),
                const Spacer(),
                CapIcon(
                  'arrow-up-right',
                  size: capRpx(context, 25),
                  color: const Color(0xFF7B5824).withValues(alpha: 0.6),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 18)),
            Text(
              '课表同步',
              style: TextStyle(
                fontSize: capRpx(context, 22),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7B5824),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: capRpx(context, 48),
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: capRpx(context, -2.9),
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(width: capRpx(context, 5)),
                Text(
                  '门课',
                  style: TextStyle(
                    fontSize: capRpx(context, 18),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7B5824),
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 4)),
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: capRpx(context, 17),
                color: const Color(0xFF7B5824).withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _electricTool(
    BuildContext context,
    String value,
    String unit,
    String hint,
  ) {
    return GestureDetector(
      onTap: () => _push(context, const ElectricityPage()),
      child: Container(
        constraints: BoxConstraints(minHeight: capRpx(context, 268)),
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 22),
          capRpx(context, 22),
          capRpx(context, 22),
          capRpx(context, 20),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: capRpx(context, 28),
              offset: Offset(0, capRpx(context, 10)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _toolIcon(context, 'zap', AppColors.mintSoft, AppColors.mint),
                const Spacer(),
                CapIcon(
                  'arrow-up-right',
                  size: capRpx(context, 25),
                  color: AppColors.mutedSoft,
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 18)),
            Text(
              '用电管理',
              style: TextStyle(
                fontSize: capRpx(context, 22),
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: capRpx(context, 48),
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                      letterSpacing: capRpx(context, -2.9),
                      color: AppColors.ink,
                    ),
                  ),
                ),
                SizedBox(width: capRpx(context, 5)),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: capRpx(context, 18),
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 4)),
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: capRpx(context, 17),
                color: AppColors.mutedSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolIcon(
    BuildContext context,
    String icon,
    Color background,
    Color color,
  ) {
    return Container(
      width: capRpx(context, 58),
      height: capRpx(context, 58),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(capRpx(context, 18)),
      ),
      child: Center(
        child: CapIcon(icon, size: capRpx(context, 33), color: color),
      ),
    );
  }

  Widget _dataItem(
    BuildContext context, {
    required String icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: capRpx(context, 12),
          vertical: capRpx(context, 16),
        ),
        child: Row(
          children: [
            CapIcon(icon, size: capRpx(context, 27), color: AppColors.muted),
            SizedBox(width: capRpx(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: capRpx(context, 20),
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: capRpx(context, 16),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ],
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
    );
  }
}
