import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/cap_ledger.dart';
import '../data/cap_store.dart';
import '../services/cap_capture.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/app_header.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_page.dart';
import '../widgets/cap_reveal.dart';
import '../widgets/cap_sheet.dart';
import '../widgets/cap_toast.dart';
import '../widgets/cap_toggle.dart';

Color ledgerColor(String hex) {
  final value = hex.replaceAll('#', '');
  if (value.length >= 6) {
    return Color(int.parse('FF$value', radix: 16));
  }
  return const Color(0xFF747B82);
}

Color _softColor(String hex) {
  final color = ledgerColor(hex);
  return color.withValues(alpha: 0.12);
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, this.initialTab = 'list', this.openAdd = false});

  final String initialTab;
  final bool openAdd;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late String _tab = widget.initialTab;
  final TextEditingController _search = TextEditingController();
  String _flow = 'all';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRecord('expense'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CapCapture.sync(CapScope.of(context)).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openRecord(String type) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.93,
      builder: (_) => _RecordSheet(
        store: CapScope.of(context),
        initialType: type,
      ),
    );
  }

  void _editTransaction(CapTransaction tx) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.93,
      builder: (_) => _RecordSheet(
        store: CapScope.of(context),
        existing: tx,
      ),
    );
  }

  void _openCapture(Map<String, dynamic> item) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.93,
      builder: (_) => _RecordSheet(
        store: CapScope.of(context),
        pending: item,
      ),
    );
  }

  void _openBudget() {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.86,
      builder: (_) => _BudgetSheet(store: CapScope.of(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final summary = store.ledgerSummaryAt(DateTime.now());
    final pending = store.ledger.pending;
    final pendingTransfers = pending
        .where(
          (item) =>
              '${item['payee'] ?? ''}'.isNotEmpty ||
              RegExp('转账|红包').hasMatch('${item['merchant'] ?? ''}') ||
              RegExp('转账|红包').hasMatch('${item['text'] ?? ''}'),
        )
        .toList();
    final pendingPayments = pending
        .where(
          (item) =>
              !('${item['payee'] ?? ''}'.isNotEmpty ||
                  RegExp('转账|红包').hasMatch('${item['merchant'] ?? ''}') ||
                  RegExp('转账|红包').hasMatch('${item['text'] ?? ''}')),
        )
        .toList();
    final visibleTransactions = _visibleTransactions(store);
    final groups = groupTransactionsByDay(visibleTransactions).take(20).toList();
    final filterActive = _search.text.trim().isNotEmpty || _flow != 'all';
    final visibleSpent = visibleTransactions
        .where((tx) => tx.type == 'expense')
        .fold<int>(0, (sum, tx) => sum + tx.amountCents);
    final visibleIncome = visibleTransactions
        .where((tx) => tx.type == 'income')
        .fold<int>(0, (sum, tx) => sum + tx.amountCents);
    final periodTransactions = store.transactionsInCurrentPeriod();
    final breakdown = categoryBreakdown(store.ledger, periodTransactions);
    final trend = expenseTrend(store.ledger);
    final incomeCount = periodTransactions
        .where((tx) => tx.type == 'income')
        .length;
    final netCents = summary.incomeCents - summary.spentCents;
    final incomeBarPercent = summary.incomeCents == 0
        ? 0
        : math.min(
            100,
            ((summary.incomeCents /
                        (summary.incomeCents + summary.spentCents)) *
                    100)
                .round(),
          );
    final remainText = formatMoney(summary.remainingCents.abs());
    final spentText = formatMoney(summary.spentCents);
    final budgetText = summary.hasBudget
        ? formatMoney(summary.budgetCents)
        : '未设置';
    final todayText = formatMoney(summary.todaySpentCents);
    final incomeText = formatMoney(summary.incomeCents);
    final netText = formatMoney(netCents.abs());
    final toneLabel = ledgerTones[summary.tone] ?? ledgerTones['ok']!;

    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '记账',
            subtitle: '本地账本 · 不上传任何一笔',
            back: true,
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeaderIconButton(
                  icon: 'sliders-horizontal',
                  onTap: _openBudget,
                ),
                SizedBox(width: capRpx(context, 12)),
                HeaderIconButton(
                  icon: 'plus',
                  onTap: () => _openRecord('expense'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                capRpx(context, 10),
                capRpx(context, 28),
                capRpx(context, 150) +
                    MediaQuery.paddingOf(context).bottom +
                    48,
              ),
              children: [
                SizedBox(height: capRpx(context, 6)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _heroBudget(
                        context,
                        summary,
                        remainText,
                        spentText,
                        budgetText,
                        toneLabel,
                      ),
                    ),
                    SizedBox(width: capRpx(context, 14)),
                    Expanded(
                      child: _heroIncome(
                        context,
                        summary,
                        incomeText,
                        incomeCount,
                        netCents,
                        netText,
                        incomeBarPercent,
                      ),
                    ),
                  ],
                ),
                if (pendingTransfers.isNotEmpty) ...[
                  SizedBox(height: capRpx(context, 18)),
                  _captureCard(context, store, pendingTransfers, transfer: true),
                ],
                if (pendingPayments.isNotEmpty) ...[
                  SizedBox(height: capRpx(context, 18)),
                  _captureCard(context, store, pendingPayments, transfer: false),
                ],
                SizedBox(height: capRpx(context, 18)),
                _quickRow(context, summary, todayText, incomeText),
                SizedBox(height: capRpx(context, 22)),
                _segment(context),
                if (_tab == 'list') ...[
                  SizedBox(height: capRpx(context, 12)),
                  _searchFilter(
                    context,
                    filterActive: filterActive,
                    count: visibleTransactions.length,
                    spent: visibleSpent,
                    income: visibleIncome,
                  ),
                ],
                SizedBox(height: capRpx(context, 18)),
                AnimatedSwitcher(
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
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _tab == 'list'
                      ? Column(
                          key: const ValueKey('ledger-list'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (groups.isEmpty)
                              filterActive
                                  ? _noResults(context)
                                  : _emptyLedger(context)
                            else
                              for (var i = 0; i < groups.length; i += 1) ...[
                                if (i > 0)
                                  SizedBox(height: capRpx(context, 18)),
                                CapReveal(
                                  index: i,
                                  offset: const Offset(0, 10),
                                  child: _dayGroup(context, store, groups[i]),
                                ),
                              ],
                          ],
                        )
                      : KeyedSubtree(
                          key: const ValueKey('ledger-stats'),
                          child: _stats(
                            context,
                            summary,
                            breakdown,
                            trend,
                            periodTransactions,
                          ),
                        ),
                ),
                SizedBox(height: capRpx(context, 28)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      'shield-check',
                      size: capRpx(context, 20),
                      color: AppColors.mutedSoft,
                    ),
                    SizedBox(width: capRpx(context, 7)),
                    Text(
                      '账本只保存在这台设备；卸载应用会一并删除。',
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
        ],
      ),
    );
  }

  Widget _heroBudget(
    BuildContext context,
    CapLedgerSummary summary,
    String remainText,
    String spentText,
    String budgetText,
    String toneLabel,
  ) {
    final toneColor = summary.tone == 'low'
        ? const Color(0xFFFFD0C4)
        : summary.tone == 'mid'
        ? const Color(0xFFF4D9AE)
        : const Color(0xFFCFE9DE);
    final toneBg = summary.tone == 'low'
        ? AppColors.coral.withValues(alpha: 0.22)
        : summary.tone == 'mid'
        ? AppColors.gold.withValues(alpha: 0.18)
        : const Color(0xFF5AB496).withValues(alpha: 0.16);
    final toneBorder = summary.tone == 'low'
        ? const Color(0xFFFFA082).withValues(alpha: 0.28)
        : summary.tone == 'mid'
        ? const Color(0xFFEACB91).withValues(alpha: 0.26)
        : const Color(0xFF8CD2BA).withValues(alpha: 0.24);
    final fillColors = summary.tone == 'low'
        ? [const Color(0xFFCD5B45), const Color(0xFFE88E77)]
        : summary.tone == 'mid'
        ? [const Color(0xFFE0B06A), const Color(0xFFF1CF89)]
        : [const Color(0xFF7FD1B9), const Color(0xFFA8E3D0)];
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 22),
        capRpx(context, 24),
        capRpx(context, 22),
        capRpx(context, 18),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capRpx(context, 32)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14273F), Color(0xFF0C1A2C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B182A).withValues(alpha: 0.24),
            blurRadius: capRpx(context, 54),
            offset: Offset(0, capRpx(context, 24)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -capRpx(context, 60),
            top: -capRpx(context, 80),
            width: capRpx(context, 220),
            height: capRpx(context, 220),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.42),
                    AppColors.gold.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.58],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'BUDGET · ${summary.period.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 16),
                        letterSpacing: capRpx(context, 0.64),
                        color: Colors.white.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                  Container(
                    height: capRpx(context, 40),
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 12),
                    ),
                    decoration: BoxDecoration(
                      color: toneBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: toneBorder, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      toneLabel,
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        fontWeight: FontWeight.w700,
                        color: toneColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: capRpx(context, 18)),
              Text(
                !summary.hasBudget
                    ? '还没有预算'
                    : summary.remainingCents < 0
                    ? '已超支'
                    : '本期还能花',
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              SizedBox(height: capRpx(context, 4)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '¥',
                    style: TextStyle(
                      fontSize: capRpx(context, 26),
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                  SizedBox(width: capRpx(context, 8)),
                  Flexible(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: (summary.hasBudget
                                ? summary.remainingCents.abs()
                                : 0)
                            .toDouble(),
                      ),
                      duration: const Duration(milliseconds: 620),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Text(
                        summary.hasBudget
                            ? formatMoney(value.round())
                            : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: capRpx(context, 54),
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: capRpx(context, -2),
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: capRpx(context, 20),
                              offset: Offset(0, capRpx(context, 6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: capRpx(context, 18)),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: capRpx(context, 8),
                  color: Colors.white.withValues(alpha: 0.12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: summary.percent / 100,
                      ),
                      duration: const Duration(milliseconds: 680),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: child,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: fillColors),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: capRpx(context, 16)),
              Container(
                padding: EdgeInsets.only(top: capRpx(context, 12)),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '支出 ¥$spentText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 10)),
                    if (!summary.hasBudget)
                      GestureDetector(
                        onTap: _openBudget,
                        child: Row(
                          children: [
                            Text(
                              '设置预算',
                              style: TextStyle(
                                fontSize: capRpx(context, 18),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF1D7A5),
                              ),
                            ),
                            CapIcon(
                              'chevron-right',
                              size: capRpx(context, 21),
                              color: const Color(0xFFF1D7A5),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: Text(
                          '预算 ¥$budgetText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: capRpx(context, 17),
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroIncome(
    BuildContext context,
    CapLedgerSummary summary,
    String incomeText,
    int incomeCount,
    int netCents,
    String netText,
    int incomeBarPercent,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 22),
        capRpx(context, 24),
        capRpx(context, 22),
        capRpx(context, 18),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(capRpx(context, 32)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF103029), Color(0xFF0A201C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A201C).withValues(alpha: 0.24),
            blurRadius: capRpx(context, 54),
            offset: Offset(0, capRpx(context, 24)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -capRpx(context, 60),
            top: -capRpx(context, 80),
            width: capRpx(context, 220),
            height: capRpx(context, 220),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF49937F).withValues(alpha: 0.46),
                    const Color(0xFF49937F).withValues(alpha: 0),
                  ],
                  stops: const [0, 0.58],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'INCOME · ${summary.monthLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: capRpx(context, 16),
                        letterSpacing: capRpx(context, 0.64),
                        color: Colors.white.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                  Container(
                    height: capRpx(context, 40),
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 12),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5AB496).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF8CD2BA).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '收入',
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB8EED8),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: capRpx(context, 18)),
              Text(
                '本期已收',
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.56),
                ),
              ),
              SizedBox(height: capRpx(context, 4)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '¥',
                    style: TextStyle(
                      fontSize: capRpx(context, 26),
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                  SizedBox(width: capRpx(context, 8)),
                  Flexible(
                    child: Text(
                      incomeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: capRpx(context, 54),
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: capRpx(context, -2),
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: capRpx(context, 20),
                            offset: Offset(0, capRpx(context, 6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: capRpx(context, 18)),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: capRpx(context, 8),
                  color: Colors.white.withValues(alpha: 0.12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: incomeBarPercent / 100,
                      ),
                      duration: const Duration(milliseconds: 680),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: child,
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6FC9A8), Color(0xFF9BE0C4)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: capRpx(context, 16)),
              Container(
                padding: EdgeInsets.only(top: capRpx(context, 12)),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$incomeCount 笔收入',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 10)),
                    Flexible(
                      child: Text(
                        '${netCents >= 0 ? '结余' : '入不敷出'} ¥$netText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: netCents >= 0
                              ? const Color(0xFFA9D8C7)
                              : const Color(0xFFFFB39A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _captureCard(
    BuildContext context,
    CapStore store,
    List<Map<String, dynamic>> items, {
    required bool transfer,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 20),
        capRpx(context, 18),
        capRpx(context, 20),
        capRpx(context, 14),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 26)),
        border: Border.all(
          color: transfer
              ? AppColors.mint.withValues(alpha: 0.28)
              : AppColors.gold.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: capRpx(context, 24),
            offset: Offset(0, capRpx(context, 10)),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: capRpx(context, 40),
                height: capRpx(context, 40),
                margin: EdgeInsets.only(right: capRpx(context, 9)),
                decoration: BoxDecoration(
                  color: transfer ? AppColors.mintSoft : AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 13)),
                ),
                child: Center(
                  child: CapIcon(
                    transfer ? 'send' : 'zap',
                    size: capRpx(context, 23),
                    color: transfer ? AppColors.mint : const Color(0xFF9A641F),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '待确认${transfer ? '转账' : '账单'} ${items.length} 笔',
                  style: TextStyle(
                    fontSize: capRpx(context, 22),
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '确认后才入账',
                style: TextStyle(
                  fontSize: capRpx(context, 17),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
          for (final item in items) ...[
            SizedBox(height: capRpx(context, 12)),
            Container(
              padding: EdgeInsets.only(top: capRpx(context, 12)),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.line,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openCapture(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (transfer)
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${item['payee'] ?? item['merchant'] ?? '转账对象'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: capRpx(context, 24),
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                SizedBox(width: capRpx(context, 8)),
                                Container(
                                  width: capRpx(context, 32),
                                  height: capRpx(context, 32),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: item['type'] == 'income'
                                        ? AppColors.mintSoft
                                        : AppColors.coralSoft,
                                    borderRadius: BorderRadius.circular(
                                      capRpx(context, 10),
                                    ),
                                  ),
                                  child: Text(
                                    item['type'] == 'income' ? '收' : '付',
                                    style: TextStyle(
                                      fontSize: capRpx(context, 16),
                                      fontWeight: FontWeight.w800,
                                      color: item['type'] == 'income'
                                          ? AppColors.mint
                                          : AppColors.coral,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '${item['merchant'] ?? item['title'] ?? '一笔支出'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: capRpx(context, 24),
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          SizedBox(height: capRpx(context, 2)),
                          Text(
                            transfer
                                ? '${item['app'] ?? ''} · ${_captureTime(item['at'])}'
                                : '${item['app'] ?? ''} · ${_captureTime(item['at'])} · ${item['type'] == 'income' ? '收入' : '支出'}',
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
                  ),
                  SizedBox(width: capRpx(context, 10)),
                  Text(
                    '${item['type'] == 'income' ? '+' : '-'}¥${formatMoney((item['amountCents'] as num?)?.toInt() ?? 0)}',
                    style: TextStyle(
                      fontSize: capRpx(context, 25),
                      fontWeight: FontWeight.w800,
                      color: item['type'] == 'income'
                          ? AppColors.mint
                          : AppColors.ink,
                    ),
                  ),
                  SizedBox(width: capRpx(context, 10)),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final categoryId = suggestLedgerCategory(
                            store.ledger,
                            '${item['merchant'] ?? ''}',
                            text: '${item['text'] ?? ''}',
                          );
                          final saved = store.confirmLedgerCapture(
                            '${item['id']}',
                            categoryId: categoryId,
                          );
                          if (saved == null) {
                            showCapToast(context, '确认失败，请重试');
                          } else {
                            showCapToast(
                              context,
                              '已记入「${store.ledger.categoryOf(saved.categoryId)?.name ?? '未分类'}」',
                            );
                          }
                        },
                        child: _captureButton(context, '确认', primary: true),
                      ),
                      SizedBox(width: capRpx(context, 8)),
                      GestureDetector(
                        onTap: () {
                          store.dismissLedgerCapture('${item['id']}');
                          showCapToast(context, '已忽略这笔');
                        },
                        child: _captureButton(context, '忽略'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _captureButton(
    BuildContext context,
    String text, {
    bool primary = false,
  }) {
    return Container(
      height: capRpx(context, 48),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 13)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? AppColors.ink : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 12)),
        border: Border.all(
          color: primary ? AppColors.ink : AppColors.line,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 19),
          fontWeight: FontWeight.w700,
          color: primary ? Colors.white : AppColors.muted,
        ),
      ),
    );
  }

  String _captureTime(dynamic at) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      (at as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
    final clock = '${pad2(date.hour)}:${pad2(date.minute)}';
    return formatDateKey(date) == formatDateKey()
        ? clock
        : '${date.month}/${date.day} $clock';
  }

  Widget _quickRow(
    BuildContext context,
    CapLedgerSummary summary,
    String todayText,
    String incomeText,
  ) {
    Widget item({
      required String icon,
      required String label,
      required String sub,
      required Color color,
      required Color bg,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              capRpx(context, 16),
              capRpx(context, 18),
              capRpx(context, 16),
              capRpx(context, 16),
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(capRpx(context, 24)),
              border: Border.all(color: AppColors.line, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: capRpx(context, 20),
                  offset: Offset(0, capRpx(context, 8)),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: capRpx(context, 46),
                  height: capRpx(context, 46),
                  margin: EdgeInsets.only(bottom: capRpx(context, 6)),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(capRpx(context, 14)),
                  ),
                  child: Center(
                    child: CapIcon(icon, size: capRpx(context, 28), color: color),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: capRpx(context, 23),
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  sub,
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
        ),
      );
    }

    return Row(
      children: [
        item(
          icon: 'arrow-up-right',
          label: '记支出',
          sub: '今天 ¥$todayText',
          color: AppColors.coral,
          bg: AppColors.coralSoft,
          onTap: () => _openRecord('expense'),
        ),
        SizedBox(width: capRpx(context, 12)),
        item(
          icon: 'arrow-down',
          label: '记收入',
          sub: '本期 ¥$incomeText',
          color: AppColors.mint,
          bg: AppColors.mintSoft,
          onTap: () => _openRecord('income'),
        ),
        SizedBox(width: capRpx(context, 12)),
        item(
          icon: 'sliders-horizontal',
          label: '预算',
          sub: summary.hasBudget ? '已用 ${summary.percent}%' : '还没有设置',
          color: AppColors.accent,
          bg: AppColors.accentSoft,
          onTap: _openBudget,
        ),
      ],
    );
  }

  Widget _segment(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(capRpx(context, 6)),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 20)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Row(
        children: [
          for (final entry in const [('list', '账单'), ('stats', '统计')]) ...[
            if (entry.$1 == 'stats') SizedBox(width: capRpx(context, 8)),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = entry.$1),
                child: AnimatedContainer(
                  duration: capsuleMotion,
                  curve: capsuleSpringCurve,
                  height: capRpx(context, 58),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == entry.$1
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(capRpx(context, 15)),
                    boxShadow: _tab == entry.$1
                        ? [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.07),
                              blurRadius: capRpx(context, 16),
                              offset: Offset(0, capRpx(context, 6)),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.$2,
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      fontWeight: FontWeight.w700,
                      color: _tab == entry.$1 ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<CapTransaction> _visibleTransactions(CapStore store) {
    final query = _search.text.trim().toLowerCase();
    final list = store.ledger.transactions.where((tx) {
      if (_flow != 'all' && tx.type != _flow) return false;
      if (query.isEmpty) return true;
      final category = store.ledger.categoryOf(tx.categoryId)?.name ?? '';
      final haystack = [
        tx.payee,
        tx.note,
        category,
        formatMoney(tx.amountCents),
        tx.type == 'income' ? '收入' : '支出',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Widget _searchFilter(
    BuildContext context, {
    required bool filterActive,
    required int count,
    required int spent,
    required int income,
  }) {
    return Container(
      padding: EdgeInsets.all(capRpx(context, 14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 24)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: capRpx(context, 62),
                  padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      CapIcon(
                        'search',
                        size: capRpx(context, 20),
                        color: AppColors.mutedSoft,
                      ),
                      SizedBox(width: capRpx(context, 7)),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontSize: capRpx(context, 21),
                            color: AppColors.ink,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: '搜索商户、备注、分类或金额',
                            hintStyle: TextStyle(
                              fontSize: capRpx(context, 20),
                              color: AppColors.mutedSoft,
                            ),
                          ),
                        ),
                      ),
                      if (_search.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => _search.clear(),
                          child: CapIcon(
                            'x',
                            size: capRpx(context, 19),
                            color: AppColors.mutedSoft,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (filterActive) ...[
                SizedBox(width: capRpx(context, 8)),
                GestureDetector(
                  onTap: () {
                    _search.clear();
                    setState(() => _flow = 'all');
                  },
                  child: Container(
                    height: capRpx(context, 56),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 12)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '清除',
                      style: TextStyle(
                        fontSize: capRpx(context, 19),
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: capRpx(context, 10)),
          Row(
            children: [
              for (final entry in const [
                ('all', '全部'),
                ('expense', '支出'),
                ('income', '收入'),
              ]) ...[
                if (entry.$1 != 'all') SizedBox(width: capRpx(context, 8)),
                GestureDetector(
                  onTap: () => setState(() => _flow = entry.$1),
                  child: AnimatedContainer(
                    duration: capsuleMotionFast,
                    curve: capsuleSpringCurve,
                    height: capRpx(context, 46),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _flow == entry.$1
                          ? AppColors.ink
                          : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: capRpx(context, 19),
                        fontWeight: FontWeight.w700,
                        color: _flow == entry.$1 ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (filterActive)
                Flexible(
                  child: Text(
                    '$count 笔 · 支出 ¥${formatMoney(spent, compact: true)} · 收入 ¥${formatMoney(income, compact: true)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
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
    );
  }

  Widget _noResults(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 28),
        capRpx(context, 40),
        capRpx(context, 28),
        capRpx(context, 36),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 26)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        children: [
          CapIcon('search', size: capRpx(context, 42), color: AppColors.mutedSoft),
          SizedBox(height: capRpx(context, 12)),
          Text(
            '没有符合条件的账单',
            style: TextStyle(
              fontSize: capRpx(context, 25),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 6)),
          Text(
            '换个关键词，或把收支方向切回「全部」。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 20),
              height: 1.55,
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 16)),
          GestureDetector(
            onTap: () {
              _search.clear();
              setState(() => _flow = 'all');
            },
            child: Container(
              height: capRpx(context, 58),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 22)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '清除筛选',
                style: TextStyle(
                  fontSize: capRpx(context, 20),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayGroup(BuildContext context, CapStore store, LedgerDayGroup group) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            capRpx(context, 6),
            0,
            capRpx(context, 6),
            capRpx(context, 10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                group.label,
                style: TextStyle(
                  fontSize: capRpx(context, 23),
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(width: capRpx(context, 10)),
              Text(
                group.weekday,
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
              ),
              const Spacer(),
              Text(
                group.totalCents > 0 ? '-${formatMoney(group.totalCents)}' : '',
                style: TextStyle(
                  fontSize: capRpx(context, 19),
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(capRpx(context, 24)),
            border: Border.all(color: AppColors.line, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < group.items.length; i += 1)
                GestureDetector(
                  onTap: () => _editTransaction(group.items[i]),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 18),
                      vertical: capRpx(context, 16),
                    ),
                    decoration: BoxDecoration(
                      border: i < group.items.length - 1
                          ? const Border(
                              bottom: BorderSide(
                                color: AppColors.line,
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: capRpx(context, 58),
                          height: capRpx(context, 58),
                          margin: EdgeInsets.only(right: capRpx(context, 14)),
                          decoration: BoxDecoration(
                            color: _softColor(
                              store.ledger
                                      .categoryOf(group.items[i].categoryId)
                                      ?.color ??
                                  '#747B82',
                            ),
                            borderRadius: BorderRadius.circular(capRpx(context, 18)),
                          ),
                          child: Center(
                            child: CapIcon(
                              store.ledger
                                      .categoryOf(group.items[i].categoryId)
                                      ?.icon ??
                                  'folder',
                              size: capRpx(context, 28),
                              color: ledgerColor(
                                store.ledger
                                        .categoryOf(group.items[i].categoryId)
                                        ?.color ??
                                    '#747B82',
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transactionTitle(
                                  group.items[i],
                                  store.ledger.categories,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: capRpx(context, 25),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                _txMeta(store, group.items[i]),
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
                        SizedBox(width: capRpx(context, 12)),
                        Text(
                          '${group.items[i].type == 'income' ? '+' : '-'}${formatMoney(group.items[i].amountCents)}',
                          style: TextStyle(
                            fontSize: capRpx(context, 26),
                            fontWeight: FontWeight.w800,
                            letterSpacing: capRpx(context, -0.5),
                            color: group.items[i].type == 'income'
                                ? AppColors.mint
                                : AppColors.ink,
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
    );
  }

  String _txMeta(CapStore store, CapTransaction tx) {
    final cat = store.ledger.categoryOf(tx.categoryId);
    final parts = <String>[cat?.name ?? '未分类'];
    if (tx.payee.isNotEmpty) parts.add(tx.payee);
    if (tx.note.isNotEmpty &&
        transactionTitle(tx, store.ledger.categories) != tx.note) {
      parts.add(tx.note);
    }
    if (tx.aaShares > 1) parts.add('AA ${tx.aaShares} 人');
    if (tx.budgetExcluded) parts.add('不计预算');
    return parts.join(' · ');
  }

  Widget _emptyLedger(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 30),
        capRpx(context, 56),
        capRpx(context, 30),
        capRpx(context, 46),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 30)),
        border: Border.all(color: AppColors.lineStrong, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: capRpx(context, 116),
            height: capRpx(context, 116),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 36)),
            ),
            child: Center(
              child: CapIcon(
                'wallet',
                size: capRpx(context, 50),
                color: AppColors.accent,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          Text(
            '账本还是空的',
            style: TextStyle(
              fontSize: capRpx(context, 28),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            '记下第一笔，月底就能看清钱去了哪里。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: capRpx(context, 21),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 22)),
          GestureDetector(
            onTap: () => _openRecord('expense'),
            child: Container(
              height: capRpx(context, 66),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 22)),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CapIcon('plus', size: capRpx(context, 24), color: Colors.white),
                  SizedBox(width: capRpx(context, 6)),
                  Text(
                    '记一笔',
                    style: TextStyle(
                      fontSize: capRpx(context, 21),
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
    );
  }

  Widget _stats(
    BuildContext context,
    CapLedgerSummary summary,
    LedgerBreakdown breakdown,
    LedgerTrend trend,
    List<CapTransaction> transactions,
  ) {
    final weekAverage =
        (trend.list.fold<int>(0, (sum, bar) => sum + bar.cents) / 7).round();
    return Column(
      children: [
        _statCard(
          context,
          head: Row(
            children: [
              Expanded(
                child: Text(
                  '本期分类',
                  style: TextStyle(
                    fontSize: capRpx(context, 25),
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '${summary.period.start.month}.${summary.period.start.day} – ${summary.period.end.month}.${summary.period.end.day}',
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
          body: breakdown.list.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(top: capRpx(context, 14)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '本期还没有支出，记一笔就能看到分类占比。',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: capRpx(context, 168),
                      height: capRpx(context, 168),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(
                              capRpx(context, 168),
                              capRpx(context, 168),
                            ),
                            painter: _PiePainter(breakdown.list),
                          ),
                          Container(
                            width: capRpx(context, 168 - 44),
                            height: capRpx(context, 168 - 44),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '本期支出',
                                  style: TextStyle(
                                    fontSize: capRpx(context, 16),
                                    color: AppColors.mutedSoft,
                                  ),
                                ),
                                Text(
                                  formatMoney(breakdown.total, compact: true),
                                  style: TextStyle(
                                    fontSize: capRpx(context, 28),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  '${breakdown.list.length} 类',
                                  style: TextStyle(
                                    fontSize: capRpx(context, 15),
                                    color: AppColors.mutedSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: capRpx(context, 18)),
                    Expanded(
                      child: Column(
                        children: [
                          for (var i = 0; i < breakdown.list.length; i += 1) ...[
                            if (i > 0) SizedBox(height: capRpx(context, 10)),
                            Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Container(
                                      width: capRpx(context, 10),
                                      height: capRpx(context, 10),
                                      margin: EdgeInsets.only(
                                        right: capRpx(context, 8),
                                      ),
                                      decoration: BoxDecoration(
                                        color: ledgerColor(
                                          breakdown.list[i].color,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        breakdown.list[i].name,
                                        style: TextStyle(
                                          fontSize: capRpx(context, 22),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatMoney(
                                        breakdown.list[i].cents,
                                        compact: true,
                                      ),
                                      style: TextStyle(
                                        fontSize: capRpx(context, 21),
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    SizedBox(width: capRpx(context, 8)),
                                    Text(
                                      '${breakdown.list[i].percent}%',
                                      style: TextStyle(
                                        fontSize: capRpx(context, 17),
                                        color: AppColors.mutedSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: capRpx(context, 6)),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    height: capRpx(context, 8),
                                    color: AppColors.surfaceSoft,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor:
                                            breakdown.list[i].percent / 100,
                                        heightFactor: 1,
                                        child: ColoredBox(
                                          color: ledgerColor(
                                            breakdown.list[i].color,
                                          ),
                                        ),
                                      ),
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
        SizedBox(height: capRpx(context, 16)),
        _statCard(
          context,
          head: Row(
            children: [
              Expanded(
                child: Text(
                  '近 7 天',
                  style: TextStyle(
                    fontSize: capRpx(context, 25),
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '日均 ${formatMoney(weekAverage)}',
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
          body: SizedBox(
            height: capRpx(context, 180),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < trend.list.length; i += 1) ...[
                  if (i > 0) SizedBox(width: capRpx(context, 10)),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              widthFactor: 0.6,
                              heightFactor: trend.list[i].cents == 0
                                  ? 0.0
                                  : (trend.list[i].percent / 100)
                                        .clamp(0.04, 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(capRpx(context, 8)),
                                    bottom: Radius.circular(capRpx(context, 4)),
                                  ),
                                  gradient: trend.list[i].key ==
                                          formatDateKey()
                                      ? const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFFC89445),
                                            Color(0xFFE0B06A),
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppColors.accent.withValues(
                                              alpha: 0.85,
                                            ),
                                            AppColors.accent.withValues(
                                              alpha: 0.35,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: capRpx(context, 6)),
                        Text(
                          trend.list[i].weekday,
                          style: TextStyle(
                            fontSize: capRpx(context, 16),
                            color: AppColors.mutedSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: capRpx(context, 16)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: capRpx(context, 22),
            vertical: capRpx(context, 20),
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(capRpx(context, 26)),
            border: Border.all(color: AppColors.line, width: 0.8),
          ),
          child: Row(
            children: [
              _miniStat(
                context,
                '本期笔数',
                '${summary.count}',
                null,
              ),
              _miniStat(
                context,
                '收入',
                formatMoney(summary.incomeCents),
                AppColors.mint,
              ),
              _miniStat(
                context,
                '未计入预算',
                formatMoney(summary.excludedCents),
                null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required Widget head,
    required Widget body,
    bool soft = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 22),
        capRpx(context, 22),
        capRpx(context, 22),
        capRpx(context, 20),
      ),
      decoration: BoxDecoration(
        color: soft ? AppColors.surfaceSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 26)),
        border: Border.all(color: AppColors.line, width: 0.8),
        boxShadow: soft
            ? null
            : [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: capRpx(context, 26),
                  offset: Offset(0, capRpx(context, 10)),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: capRpx(context, 14)),
            child: head,
          ),
          body,
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    String label,
    String value,
    Color? color,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: capRpx(context, 17),
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 3)),
          Text(
            value,
            style: TextStyle(
              fontSize: capRpx(context, 26),
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.items);

  final List<LedgerCategoryStat> items;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    var start = -math.pi / 2;
    for (final item in items) {
      final sweep = math.pi * 2 * item.percent / 100;
      final paint = Paint()..color = ledgerColor(item.color);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
      start += sweep;
    }
    if (start < math.pi * 3 / 2 - 0.001 && items.isNotEmpty) {
      final paint = Paint()..color = ledgerColor(items.first.color);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi * 3 / 2 - start,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.items != items;
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.store,
    this.initialType = 'expense',
    this.existing,
    this.pending,
  });

  final CapStore store;
  final String initialType;
  final CapTransaction? existing;
  final Map<String, dynamic>? pending;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  late String _type;
  late String _categoryId;
  late String _date;
  late String _time;
  final TextEditingController _note = TextEditingController();
  final TextEditingController _payee = TextEditingController();
  final TextEditingController _newCategory = TextEditingController();
  late String _amountText;
  late bool _budgetExcluded;
  late int _aaShares;
  bool _showNewCategory = false;

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    'del',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final pending = widget.pending;
    _type = existing?.type ?? (pending?['type'] == 'income' ? 'income' : widget.initialType);
    if (widget.initialType == 'income' && existing == null && pending == null) {
      _type = 'income';
    }
    if (existing != null) {
      _amountText = (existing.amountCents.abs() / 100)
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'\.00$'), '');
      _categoryId = existing.categoryId;
      _note.text = existing.note;
      _payee.text = existing.payee;
      final date = DateTime.fromMillisecondsSinceEpoch(existing.timestamp);
      _date = formatDateKey(date);
      _time = '${pad2(date.hour)}:${pad2(date.minute)}';
      _budgetExcluded = existing.budgetExcluded;
      _aaShares = existing.aaShares;
    } else if (pending != null) {
      final amount = (pending['amountCents'] as num?)?.toInt() ?? 0;
      _amountText = (amount.abs() / 100)
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'\.00$'), '');
      _categoryId = suggestLedgerCategory(
        widget.store.ledger,
        '${pending['merchant'] ?? ''}',
        text: '${pending['text'] ?? ''}',
      );
      _note.text = '${pending['merchant'] ?? pending['title'] ?? ''}';
      _payee.text = '${pending['payee'] ?? ''}';
      final date = DateTime.fromMillisecondsSinceEpoch(
        (pending['at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
      _date = formatDateKey(date);
      _time = '${pad2(date.hour)}:${pad2(date.minute)}';
      _budgetExcluded = false;
      _aaShares = 0;
    } else {
      _amountText = '';
      final last = '${widget.store.ledger.meta['lastCategoryId'] ?? ''}';
      final fallback = _type == 'income' ? 'inc_living' : 'cat_food';
      _categoryId = widget.store.ledger.categories.any(
            (cat) => cat.id == last && cat.type == _type,
          )
          ? last
          : fallback;
      final now = DateTime.now();
      _date = formatDateKey(now);
      _time = '${pad2(now.hour)}:${pad2(now.minute)}';
      _budgetExcluded = false;
      _aaShares = 0;
    }
    _newCategory.addListener(() {});
  }

  @override
  void dispose() {
    _note.dispose();
    _payee.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  List<LedgerCategory> get _categories => widget.store.ledger.categories
      .where((cat) => cat.type == _type)
      .toList();

  void _setType(String type) {
    setState(() {
      _type = type;
      if (!widget.store.ledger.categories.any(
        (cat) => cat.id == _categoryId && cat.type == type,
      )) {
        _categoryId = type == 'income' ? 'inc_living' : 'cat_food';
      }
    });
  }

  void _pressKey(String key) {
    setState(() {
      if (key == 'del') {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
        return;
      }
      if (key == '.') {
        if (_amountText.contains('.')) return;
        _amountText = '${_amountText.isEmpty ? '0' : _amountText}.';
        return;
      }
      if (RegExp(r'\.\d{2}$').hasMatch(_amountText)) return;
      if (_amountText.replaceAll('.', '').length >= 7) return;
      _amountText = _amountText == '0' ? key : '$_amountText$key';
    });
  }

  void _changeShare(int delta) {
    setState(() {
      final next = (_aaShares + delta).clamp(0, 20);
      _aaShares = next <= 1 ? 0 : next;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateKey(_date) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _date = formatDateKey(picked));
  }

  Future<void> _pickTime() async {
    final clock = parseClock(_time);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: clock?.hour ?? 0,
        minute: clock?.minute ?? 0,
      ),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _time = '${pad2(picked.hour)}:${pad2(picked.minute)}');
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

  void _addCategory() {
    final name = _newCategory.text.trim();
    if (name.isEmpty) {
      showCapToast(context, '先写一个分类名');
      return;
    }
    final created = widget.store.addLedgerCategory(name: name, type: _type);
    if (created != null) {
      setState(() {
        _categoryId = created.id;
        _showNewCategory = false;
        _newCategory.clear();
      });
    }
  }

  void _save() {
    final cents = amountToCents(_amountText);
    if (cents == 0) {
      showCapToast(context, '先输入金额');
      return;
    }
    final clock = parseClock(_time);
    final date = parseDateKey(_date) ?? DateTime.now();
    final timestamp = DateTime(
      date.year,
      date.month,
      date.day,
      clock?.hour ?? 0,
      clock?.minute ?? 0,
    ).millisecondsSinceEpoch;
    final pending = widget.pending;
    CapTransaction? saved;
    if (pending != null) {
      saved = widget.store.confirmLedgerCapture(
        '${pending['id']}',
        categoryId: _categoryId,
        note: _note.text,
        timestamp: timestamp,
      );
    } else {
      saved = widget.store.upsertLedgerTransaction(
        id: widget.existing?.id,
        type: _type,
        amountCents: cents,
        categoryId: _categoryId,
        note: _note.text,
        payee: _payee.text,
        timestamp: timestamp,
        budgetExcluded: _budgetExcluded,
        aaShares: _aaShares,
      );
    }
    if (saved == null) {
      showCapToast(context, '保存失败，请重试');
      return;
    }
    showCapToast(context, _type == 'income' ? '收入已记下' : '支出已记下');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 26)),
        ),
        title: Text(
          '删除这笔',
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
    if (confirmed == true && mounted) {
      widget.store.removeLedgerTransaction(existing.id);
      showCapToast(context, '已删除');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = widget.existing != null
        ? '编辑这笔'
        : _type == 'income'
        ? '记一笔收入'
        : '记一笔支出';
    return CapSheetPanel(
      title: titles,
      subtitle: '金额、分类、备注，一步到位',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(capRpx(context, 6)),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                for (final entry in const [('expense', '支出'), ('income', '收入')]) ...[
                  if (entry.$1 == 'income') SizedBox(width: capRpx(context, 8)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setType(entry.$1),
                      child: AnimatedContainer(
                        duration: capsuleMotionFast,
                        curve: capsuleSpringCurve,
                        height: capRpx(context, 54),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _type == entry.$1
                              ? AppColors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(capRpx(context, 13)),
                          boxShadow: _type == entry.$1
                              ? [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(alpha: 0.07),
                                    blurRadius: capRpx(context, 14),
                                    offset: Offset(0, capRpx(context, 4)),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            fontSize: capRpx(context, 22),
                            fontWeight: FontWeight.w700,
                            color: _type == entry.$1
                                ? AppColors.ink
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: capRpx(context, 30),
                  fontWeight: FontWeight.w700,
                  color: (_type == 'income' ? AppColors.mint : AppColors.ink)
                      .withValues(alpha: 0.5),
                ),
              ),
              SizedBox(width: capRpx(context, 8)),
              Text(
                _amountText.isEmpty ? '0' : _amountText,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: capRpx(context, 76),
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: capRpx(context, -3.8),
                  color: _type == 'income' ? AppColors.mint : AppColors.ink,
                ),
              ),
              _BlinkingCaret(
                color: _type == 'income' ? AppColors.mint : AppColors.ink,
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 14)),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: capRpx(context, 10),
            crossAxisSpacing: capRpx(context, 10),
            childAspectRatio: (capRpx(context, 220) / capRpx(context, 84)),
            children: [
              for (final key in _keys)
                GestureDetector(
                  onTap: () => _pressKey(key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(capRpx(context, 18)),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    child: Center(
                      child: key == 'del'
                          ? CapIcon(
                              'x',
                              size: capRpx(context, 26),
                              color: AppColors.muted,
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                fontSize: capRpx(context, 34),
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: capRpx(context, 18)),
          Wrap(
            spacing: capRpx(context, 8),
            runSpacing: capRpx(context, 12),
            children: [
              for (final cat in _categories)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width -
                          capRpx(context, 68) -
                          capRpx(context, 32)) /
                      5,
                  child: GestureDetector(
                    onTap: () => setState(() => _categoryId = cat.id),
                    child: AnimatedContainer(
                      duration: capsuleMotionFast,
                      curve: capsuleSpringCurve,
                      padding: EdgeInsets.symmetric(
                        horizontal: capRpx(context, 2),
                        vertical: capRpx(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: _categoryId == cat.id
                            ? AppColors.surfaceSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(capRpx(context, 16)),
                        border: Border.all(
                          color: _categoryId == cat.id
                              ? AppColors.lineStrong
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: capRpx(context, 56),
                            height: capRpx(context, 56),
                            decoration: BoxDecoration(
                              color: _softColor(cat.color),
                              borderRadius: BorderRadius.circular(capRpx(context, 18)),
                            ),
                            child: Center(
                              child: CapIcon(
                                cat.icon,
                                size: capRpx(context, 28),
                                color: ledgerColor(cat.color),
                              ),
                            ),
                          ),
                          SizedBox(height: capRpx(context, 5)),
                          Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: capRpx(context, 17),
                              color: _categoryId == cat.id
                                  ? AppColors.ink
                                  : AppColors.muted,
                              fontWeight: _categoryId == cat.id
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: (MediaQuery.sizeOf(context).width -
                        capRpx(context, 68) -
                        capRpx(context, 32)) /
                    5,
                child: GestureDetector(
                  onTap: () => setState(
                    () => _showNewCategory = !_showNewCategory,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: capRpx(context, 56),
                        height: capRpx(context, 56),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(capRpx(context, 18)),
                        ),
                        child: Center(
                          child: CapIcon(
                            'plus',
                            size: capRpx(context, 28),
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      SizedBox(height: capRpx(context, 5)),
                      Text(
                        '新分类',
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showNewCategory) ...[
            SizedBox(height: capRpx(context, 12)),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: capRpx(context, 70),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(capRpx(context, 16)),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    child: TextField(
                      controller: _newCategory,
                      maxLength: 8,
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: '分类名称，最多 8 个字',
                        hintStyle: TextStyle(
                          fontSize: capRpx(context, 20),
                          color: AppColors.mutedSoft,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: capRpx(context, 10)),
                GestureDetector(
                  onTap: _addCategory,
                  child: Container(
                    height: capRpx(context, 70),
                    padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(capRpx(context, 16)),
                    ),
                    child: Text(
                      '添加',
                      style: TextStyle(
                        fontSize: capRpx(context, 21),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: capRpx(context, 16)),
          _iconInput(
            context,
            icon: 'notebook-pen',
            controller: _note,
            hint: '备注（选填）',
            maxLength: 60,
          ),
          SizedBox(height: capRpx(context, 16)),
          _iconInput(
            context,
            icon: 'users',
            controller: _payee,
            hint: '转账对象 / 对方（选填）',
            maxLength: 24,
          ),
          SizedBox(height: capRpx(context, 8)),
          Container(
            padding: EdgeInsets.symmetric(vertical: capRpx(context, 16)),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '时间',
                    style: TextStyle(
                      fontSize: capRpx(context, 22),
                      color: AppColors.muted,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: _valueChip(context, _date),
                ),
                SizedBox(width: capRpx(context, 10)),
                GestureDetector(
                  onTap: _pickTime,
                  child: _valueChip(context, _time),
                ),
              ],
            ),
          ),
          if (_type == 'expense') ...[
            Container(
              padding: EdgeInsets.symmetric(vertical: capRpx(context, 16)),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '不计入预算',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  CapToggle(
                    value: _budgetExcluded,
                    width: capRpx(context, 76),
                    height: capRpx(context, 42),
                    thumbSize: capRpx(context, 34),
                    onChanged: (value) =>
                        setState(() => _budgetExcluded = value),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(vertical: capRpx(context, 16)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'AA 人数',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  _roundButton(context, '-', () => _changeShare(-1)),
                  SizedBox(width: capRpx(context, 12)),
                  SizedBox(
                    width: capRpx(context, 90),
                    child: Text(
                      _aaShares > 1 ? '$_aaShares' : '不 AA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  SizedBox(width: capRpx(context, 12)),
                  _roundButton(context, '+', () => _changeShare(1)),
                ],
              ),
            ),
          ],
          SizedBox(height: capRpx(context, 6)),
          Row(
            children: [
              if (widget.existing != null) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: _delete,
                    child: Container(
                      height: capRpx(context, 78),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(capRpx(context, 20)),
                      ),
                      child: Text(
                        '删除',
                        style: TextStyle(
                          fontSize: capRpx(context, 24),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: capRpx(context, 12)),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: capRpx(context, 78),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(capRpx(context, 20)),
                      border: Border.all(color: AppColors.line, width: 1),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    height: capRpx(context, 78),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(capRpx(context, 20)),
                    ),
                    child: Text(
                      '保存',
                      style: TextStyle(
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconInput(
    BuildContext context, {
    required String icon,
    required TextEditingController controller,
    required String hint,
    int? maxLength,
  }) {
    return Container(
      height: capRpx(context, 78),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 18)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Row(
        children: [
          CapIcon(icon, size: capRpx(context, 24), color: AppColors.muted),
          SizedBox(width: capRpx(context, 12)),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              style: TextStyle(
                fontSize: capRpx(context, 23),
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: hint,
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
        ],
      ),
    );
  }

  Widget _valueChip(BuildContext context, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: capRpx(context, 10),
        vertical: capRpx(context, 4),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 10)),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: capRpx(context, 22),
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _roundButton(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 48),
        height: capRpx(context, 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 14)),
          border: Border.all(color: AppColors.line, width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: capRpx(context, 26),
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret({required this.color});

  final Color color;

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.5), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 50),
      ]).animate(_controller),
      child: Container(
        width: 1.5,
        height: capRpx(context, 56),
        margin: EdgeInsets.only(left: capRpx(context, 4)),
        color: widget.color,
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.store});

  final CapStore store;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late String _mode;
  late final TextEditingController _amount;
  late int _startDay;

  @override
  void initState() {
    super.initState();
    final budget = widget.store.ledger.budget;
    _mode = '${budget['mode'] ?? 'month'}';
    _startDay = clampStartDay((budget['startDay'] as num?)?.toInt());
    final cents = _mode == 'daily'
        ? (budget['dailyCents'] as num?)?.toInt() ?? 0
        : (budget['monthlyCents'] as num?)?.toInt() ?? 0;
    _amount = TextEditingController(
      text: cents > 0 ? '${cents / 100}' : '',
    );
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final cents = amountToCents(_amount.text);
    final budget = widget.store.ledger.budget;
    widget.store.setLedgerBudget({
      'mode': _mode,
      'monthlyCents': _mode == 'month'
          ? cents
          : (budget['monthlyCents'] as num?)?.toInt() ?? 0,
      'dailyCents': _mode == 'daily'
          ? cents
          : (budget['dailyCents'] as num?)?.toInt() ?? 0,
      'startDay': clampStartDay(_startDay),
    });
    showCapToast(context, cents > 0 ? '预算已更新' : '预算已清空');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final preview = budgetPeriod({'startDay': _startDay});
    final cents = amountToCents(_amount.text);
    final previewDaily = cents == 0
        ? 0
        : _mode == 'month'
        ? (cents / math.max(1, preview.days)).round()
        : cents;
    return CapSheetPanel(
      title: '预算设置',
      subtitle: '按会计月计算，首日可以不是 1 号',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(capRpx(context, 6)),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                for (final entry in const [('month', '月度预算'), ('daily', '每日预算')]) ...[
                  if (entry.$1 == 'daily') SizedBox(width: capRpx(context, 8)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = entry.$1),
                      child: Container(
                        height: capRpx(context, 54),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _mode == entry.$1
                              ? AppColors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(capRpx(context, 13)),
                          boxShadow: _mode == entry.$1
                              ? [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(alpha: 0.07),
                                    blurRadius: capRpx(context, 14),
                                    offset: Offset(0, capRpx(context, 4)),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            fontSize: capRpx(context, 22),
                            fontWeight: FontWeight.w700,
                            color: _mode == entry.$1
                                ? AppColors.ink
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: capRpx(context, 18)),
          Text(
            _mode == 'month' ? '每月可用金额' : '每天可用金额',
            style: TextStyle(
              fontSize: capRpx(context, 22),
              fontWeight: FontWeight.w700,
              letterSpacing: capRpx(context, 0.9),
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 12)),
          Container(
            height: capRpx(context, 92),
            padding: EdgeInsets.symmetric(horizontal: capRpx(context, 26)),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 22)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: capRpx(context, 27), color: AppColors.ink),
              decoration: InputDecoration(
                hintText: _mode == 'month' ? '例如 1500' : '例如 50',
                hintStyle: TextStyle(
                  fontSize: capRpx(context, 23),
                  color: AppColors.mutedSoft,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(height: capRpx(context, 18)),
          Text(
            '每月起始日',
            style: TextStyle(
              fontSize: capRpx(context, 22),
              fontWeight: FontWeight.w700,
              letterSpacing: capRpx(context, 0.9),
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: capRpx(context, 12)),
          Row(
            children: [
              _roundButton(context, '-', () {
                setState(() => _startDay = clampStartDay(_startDay - 1));
              }),
              SizedBox(width: capRpx(context, 14)),
              SizedBox(
                width: capRpx(context, 100),
                child: Text(
                  '$_startDay 日',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: capRpx(context, 26),
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              SizedBox(width: capRpx(context, 14)),
              _roundButton(context, '+', () {
                setState(() => _startDay = clampStartDay(_startDay + 1));
              }),
            ],
          ),
          SizedBox(height: capRpx(context, 8)),
          Text(
            '生活费按发放日算起时，可以改成 10 号、15 号这样的日期。',
            style: TextStyle(
              fontSize: capRpx(context, 18),
              height: 1.6,
              color: AppColors.mutedSoft,
            ),
          ),
          SizedBox(height: capRpx(context, 18)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: capRpx(context, 18),
              vertical: capRpx(context, 14),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '本期天数',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${preview.days} 天 · 还剩 ${preview.daysLeft} 天',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 8)),
                Row(
                  children: [
                    Text(
                      '每天可花',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(previewDaily),
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: capRpx(context, 22)),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: capRpx(context, 78),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(capRpx(context, 20)),
                      border: Border.all(color: AppColors.line, width: 1),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: capRpx(context, 12)),
              Expanded(
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    height: capRpx(context, 78),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(capRpx(context, 20)),
                    ),
                    child: Text(
                      '保存预算',
                      style: TextStyle(
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundButton(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 48),
        height: capRpx(context, 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 14)),
          border: Border.all(color: AppColors.line, width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: capRpx(context, 26),
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
