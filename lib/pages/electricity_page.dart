import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/cap_store.dart';
import '../services/electricity_service.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/app_header.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_page.dart';
import '../widgets/cap_sheet.dart';
import '../widgets/cap_toast.dart';

class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key});

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> {
  bool _loading = false;
  String _balanceError = '';
  int _trendRange = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = CapScope.of(context);
      final binding = _binding(store);
      final balance = _balance(store);
      if (binding != null && balance != null) {
        store.recordElectricitySample(binding, balance);
      }
      if (binding != null && balance == null) {
        _refreshBalance(store, fromSelect: true);
      }
    });
  }

  Map<String, dynamic>? _binding(CapStore store) =>
      store.electricity['binding'] is Map
      ? Map<String, dynamic>.from(store.electricity['binding'] as Map)
      : null;

  Map<String, dynamic>? _balance(CapStore store) =>
      store.electricity['balance'] is Map
      ? Map<String, dynamic>.from(store.electricity['balance'] as Map)
      : null;

  Future<void> _refreshBalance(CapStore store, {bool fromSelect = false}) async {
    final binding = _binding(store);
    if (binding == null || _loading) return;
    setState(() {
      _loading = true;
      _balanceError = '';
    });
    final result = await ElectricityService.instance.queryBalance(
      binding,
      includeTrend: true,
    );
    if (!mounted) return;
    if (result.ok) {
      final next = <String, dynamic>{
        'val': result.val,
        'unit': result.unit,
        'dayUse': result.dayUse,
        'updatedAt': result.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        'system': result.system,
        'trend': result.trend,
        'trendError': result.trendError,
      };
      store.recordElectricitySample(binding, next);
      store.setElectricityBalance(next);
    } else {
      final message =
          '${result.error?['message'] ?? '读取失败，请稍后重试'}';
      setState(() => _balanceError = message);
      if (!fromSelect) showCapToast(context, message);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openPicker(CapStore store) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.94,
      builder: (_) => _RoomPickerSheet(
        store: store,
        onSelected: () => _refreshBalance(store, fromSelect: true),
      ),
    );
  }

  Future<void> _unbind(CapStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 26)),
        ),
        title: Text(
          '解除寝室绑定',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '解除后仍可随时重新选择寝室。',
          style: TextStyle(fontSize: capRpx(context, 22), color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('解除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      store.setElectricityBinding(null);
      store.setElectricityBalance(null);
      setState(() {});
      if (mounted) showCapToast(context, '已解除绑定');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final binding = _binding(store);
    final balance = _balance(store);
    final showBalance = store.settings.showBalance;

    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '用电',
            subtitle: '寝室电费，一目了然',
            back: true,
            right: HeaderIconButton(
              icon: showBalance ? 'eye' : 'eye-off',
              onTap: () => store.updateSettings(showBalance: !showBalance),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                capRpx(context, 6),
                capRpx(context, 28),
                capRpx(context, 60) + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (binding != null)
                  ..._boundContent(context, store, binding, balance)
                else
                  ..._unboundContent(context, store),
                SizedBox(height: capRpx(context, 20)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      'lock-keyhole',
                      size: capRpx(context, 20),
                      color: AppColors.mutedSoft,
                    ),
                    SizedBox(width: capRpx(context, 6)),
                    Text(
                      '绑定信息只保存在本机，可随时解除。',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
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

  List<Widget> _boundContent(
    BuildContext context,
    CapStore store,
    Map<String, dynamic> binding,
    Map<String, dynamic>? balance,
  ) {
    final unit = '${balance?['unit'] ?? ''}';
    final isYuan = unit == '元';
    final balanceLabel = isYuan ? '账户余额' : '剩余电量';
    final val = balance?['val'];
    final display = val == null || '$val'.isEmpty
        ? (store.settings.showBalance ? '—' : '••')
        : !store.settings.showBalance
        ? '••'
        : '$val';
    final value = double.tryParse('$val');
    final low = value != null && (isYuan ? value < 20 : value < 30);
    final statusText = _loading
        ? '读取中'
        : _balanceError.isNotEmpty
        ? '读取失败'
        : val != null
        ? (low ? '余额偏低' : '状态正常')
        : '待读取';
    final gaugePercent = value == null || value <= 0
        ? 3
        : math.max(4, math.min(100, ((value / (isYuan ? 100 : 200)) * 100).round()));
    final updateText = balance?['updatedAt'] == null
        ? '点击刷新'
        : formatRelativeTime((balance!['updatedAt'] as num).toInt());
    final dayUse = balance?['dayUse'];
    final dayUseText = dayUse == null ? '—' : '$dayUse';
    final dormName =
        '${binding['dormName'] ?? binding['roomName'] ?? '已绑定寝室'}';
    final lastUpdated = balance?['updatedAt'] == null
        ? '尚未读取'
        : _longTime((balance!['updatedAt'] as num).toInt());

    final apiTrend = balance?['trend'] is Map
        ? Map<String, dynamic>.from(balance!['trend'] as Map)
        : null;
    final localTrend = store.localElectricityUsage(binding);
    final source = apiTrend != null && apiTrend['days'] is List && (apiTrend['days'] as List).isNotEmpty
        ? 'api'
        : localTrend.isNotEmpty
        ? 'local'
        : '';
    final allDays = <Map<String, dynamic>>[];
    if (source == 'api') {
      for (final item in apiTrend!['days'] as List) {
        if (item is Map) {
          allDays.add({
            'date': '${item['date'] ?? ''}',
            'value': double.tryParse('${item['value'] ?? 0}') ?? 0,
          });
        }
      }
    } else {
      allDays.addAll(localTrend);
    }
    final todayKey = formatDateKey();
    final sliced = allDays.length > _trendRange
        ? allDays.sublist(allDays.length - _trendRange)
        : allDays;
    final maxValue = sliced.isEmpty
        ? 0.01
        : math.max(0.01, sliced.map((e) => (e['value'] as num).toDouble()).reduce(math.max));
    final trendDays = <Map<String, dynamic>>[];
    for (var i = 0; i < sliced.length; i += 1) {
      final item = sliced[i];
      final date = parseDateKey('${item['date']}') ?? DateTime.now();
      final isToday = item['date'] == todayKey;
      trendDays.add({
        'date': item['date'],
        'value': (item['value'] as num).toDouble(),
        'isToday': isToday,
        'height': math.max(3, (((item['value'] as num) / maxValue) * 100).round()),
        'label': _trendRange == 30
            ? '${pad2(date.month)}.${pad2(date.day)}'
            : '${pad2(date.month)}/${pad2(date.day)}',
        'showLabel': _trendRange == 7 || i == 0 || i == sliced.length - 1 || i % 5 == 0,
      });
    }
    final rangeLabel = _trendRange == 30 ? '本月' : '近 7 天';
    final monthTotal = apiTrend != null && apiTrend['monthTotal'] != null
        ? double.tryParse('${apiTrend['monthTotal']}')
        : null;
    final trendTotal =
        _trendRange == 30 && monthTotal != null
        ? monthTotal
        : trendDays.fold<double>(
            0,
            (sum, item) => sum + (item['value'] as double),
          );
    final trendTotalText = trendDays.isEmpty ? '—' : trendTotal.toStringAsFixed(2);
    final trendAvgText = trendDays.isEmpty
        ? '—'
        : (trendTotal / trendDays.length).toStringAsFixed(2);
    final trendMaxText = trendDays.isEmpty
        ? '—'
        : trendDays
              .map((e) => e['value'] as double)
              .reduce(math.max)
              .toStringAsFixed(2);
    final todayBar = trendDays.where((e) => e['isToday'] == true).toList();
    final trendTodayText = trendDays.isEmpty
        ? '—'
        : todayBar.isNotEmpty
        ? (todayBar.first['value'] as double).toStringAsFixed(2)
        : dayUse != null
        ? double.tryParse('$dayUse')?.toStringAsFixed(2) ?? '—'
        : (trendDays.last['value'] as double).toStringAsFixed(2);
    final sourceText = source == 'api'
        ? '学校电表 · 逐日数据'
        : source == 'local'
        ? '本机采样 · 自动累计'
        : isYuan
        ? '等待学校日数据'
        : '本机累计';
    final trendFooter = source == 'api'
        ? (monthTotal != null
              ? '本月学校统计 ${monthTotal.toStringAsFixed(2)} 度 · 每天自动更新'
              : '数据来自学校电表，每天自动更新')
        : source == 'local'
        ? '本机采样按天聚合，跨天查询后逐步完整'
        : '新都寝室首次查询即可显示学校逐日数据；龙泉寝室会从每次查询中积累';
    final trendEmptyText = balance?['trendError'] is Map
        ? '${(balance!['trendError'] as Map)['message'] ?? '学校暂未返回用电趋势数据'}'
        : binding['system'] == 'xindu'
        ? '学校逐日数据还在路上，刷新余额后再看看'
        : '龙泉校区暂未提供日数据，CapuLife 会用每次余额读数慢慢积累';

    return [
      Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 28),
          capRpx(context, 26),
          capRpx(context, 28),
          capRpx(context, 22),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(capRpx(context, 34)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF173A36), Color(0xFF0D2422), Color(0xFF0B1F1D)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2321).withValues(alpha: 0.22),
              blurRadius: capRpx(context, 52),
              offset: Offset(0, capRpx(context, 24)),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -capRpx(context, 60),
              top: -capRpx(context, 80),
              width: capRpx(context, 240),
              height: capRpx(context, 240),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6BAB95).withValues(alpha: 0.32),
                      const Color(0xFF6BAB95).withValues(alpha: 0),
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
                    Container(
                      width: capRpx(context, 42),
                      height: capRpx(context, 42),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1D08E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(capRpx(context, 13)),
                      ),
                      child: Center(
                        child: CapIcon(
                          'zap',
                          size: capRpx(context, 27),
                          color: const Color(0xFFF1D08E),
                        ),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 8)),
                    Text(
                      balanceLabel,
                      style: TextStyle(
                        fontSize: capRpx(context, 21),
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.58),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: capRpx(context, 36),
                      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 11)),
                      decoration: BoxDecoration(
                        color: low
                            ? const Color(0xFFF0B494).withValues(alpha: 0.12)
                            : const Color(0xFFA8D9C5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: capRpx(context, 7),
                            height: capRpx(context, 7),
                            decoration: BoxDecoration(
                              color: low
                                  ? const Color(0xFFF0B494)
                                  : const Color(0xFFA8D9C5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: capRpx(context, 5)),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: capRpx(context, 16),
                              fontWeight: FontWeight.w600,
                              color: low
                                  ? const Color(0xFFF0B494)
                                  : const Color(0xFFA8D9C5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 20)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      display,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: capRpx(
                          context,
                          display.length > 5 ? 82 : 116,
                        ),
                        fontWeight: FontWeight.w800,
                        height: 0.9,
                        letterSpacing: capRpx(
                          context,
                          display.length > 5 ? -5.7 : -9.3,
                        ),
                        color: const Color(0xFFFBF7ED),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 8)),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: capRpx(context, 24),
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.44),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 24)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: capRpx(context, 7),
                    color: Colors.white.withValues(alpha: 0.10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: gaugePercent / 100,
                      heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6CB59C), Color(0xFFD9B56F)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: capRpx(context, 13)),
                Row(
                  children: [
                    CapIcon(
                      'map-pin',
                      size: capRpx(context, 22),
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                    SizedBox(width: capRpx(context, 5)),
                    Expanded(
                      child: Text(
                        dormName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capRpx(context, 19),
                          color: Colors.white.withValues(alpha: 0.66),
                        ),
                      ),
                    ),
                    Text(
                      updateText,
                      style: TextStyle(
                        fontSize: capRpx(context, 16),
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 20)),
                Row(
                  children: [
                    _balanceButton(
                      context,
                      icon: 'refresh-cw',
                      label: _loading ? '正在读取' : '刷新余额',
                      light: true,
                      onTap: () => _refreshBalance(store),
                    ),
                    SizedBox(width: capRpx(context, 10)),
                    _balanceButton(
                      context,
                      icon: 'layout-grid',
                      label: '更换寝室',
                      light: false,
                      onTap: () => _openPicker(store),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: capRpx(context, 14)),
      Row(
        children: [
          Expanded(
            child: _metricCard(
              context,
              label: '今日用电',
              value: dayUseText,
              unit: dayUse == null ? '' : '度',
            ),
          ),
          SizedBox(width: capRpx(context, 10)),
          Expanded(
            child: _metricCard(
              context,
              label: '数据来源',
              value: '${binding['campusLabel'] ?? '学校电费系统'}',
            ),
          ),
          SizedBox(width: capRpx(context, 10)),
          Expanded(
            child: _metricCard(
              context,
              label: '寝室',
              value: '${binding['building'] ?? '—'}',
            ),
          ),
        ],
      ),
      if (low) ...[
        SizedBox(height: capRpx(context, 16)),
        Container(
          padding: EdgeInsets.all(capRpx(context, 16)),
          decoration: BoxDecoration(
            color: AppColors.coralSoft,
            borderRadius: BorderRadius.circular(capRpx(context, 18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: capRpx(context, 46),
                height: capRpx(context, 46),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(capRpx(context, 14)),
                ),
                child: Center(
                  child: CapIcon(
                    'triangle-alert',
                    size: capRpx(context, 28),
                    color: AppColors.coral,
                  ),
                ),
              ),
              SizedBox(width: capRpx(context, 11)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '余额偏低',
                      style: TextStyle(
                        fontSize: capRpx(context, 21),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8F3928),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 2)),
                    Text(
                      '建议及时充值，避免寝室突然断电。充值请在原电费系统完成。',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        height: 1.5,
                        color: const Color(0xFF9F584A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      SizedBox(height: capRpx(context, 30)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 4)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用电趋势',
                    style: TextStyle(
                      fontSize: capRpx(context, 30),
                      fontWeight: FontWeight.w800,
                      letterSpacing: capRpx(context, -0.6),
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 2)),
                  Text(
                    sourceText,
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(capRpx(context, 4)),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: Row(
                children: [
                  for (final entry in const [(7, '7天'), (30, '本月')]) ...[
                    if (entry.$1 == 30) SizedBox(width: capRpx(context, 2)),
                    GestureDetector(
                      onTap: () => setState(() => _trendRange = entry.$1),
                      child: AnimatedContainer(
                        duration: capsuleMotionFast,
                        curve: capsuleSpringCurve,
                        height: capRpx(context, 42),
                        constraints: BoxConstraints(minWidth: capRpx(context, 68)),
                        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 13)),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _trendRange == entry.$1
                              ? AppColors.ink
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            fontSize: capRpx(context, 18),
                            fontWeight: FontWeight.w700,
                            color: _trendRange == entry.$1
                                ? Colors.white
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: capRpx(context, 12)),
      Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 20),
          capRpx(context, 20),
          capRpx(context, 20),
          capRpx(context, 16),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 26)),
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: capRpx(context, 24),
              offset: Offset(0, capRpx(context, 10)),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$rangeLabel用电',
                        style: TextStyle(
                          fontSize: capRpx(context, 18),
                          color: AppColors.muted,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            trendTotalText,
                            style: TextStyle(
                              fontSize: capRpx(context, 45),
                              fontWeight: FontWeight.w800,
                              letterSpacing: capRpx(context, -2.2),
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(width: capRpx(context, 4)),
                          Text(
                            '度',
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
                Row(
                  children: [
                    _trendFact(context, '日均', trendAvgText),
                    SizedBox(width: capRpx(context, 20)),
                    _trendFact(context, '单日最高', trendMaxText),
                    SizedBox(width: capRpx(context, 20)),
                    _trendFact(context, '今日', trendTodayText),
                  ],
                ),
              ],
            ),
            if (trendDays.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 18)),
              Container(
                height: capRpx(context, 210),
                padding: EdgeInsets.only(top: capRpx(context, 6)),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line, width: 1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < trendDays.length; i += 1) ...[
                      if (i > 0) SizedBox(width: capRpx(context, _trendRange == 30 ? 2 : 6)),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  widthFactor: _trendRange == 30 ? 0.82 : 0.72,
                                  heightFactor:
                                      ((trendDays[i]['height'] as int) / 100)
                                          .clamp(0.03, 1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(
                                          capRpx(context, _trendRange == 30 ? 4 : 7),
                                        ),
                                      ),
                                      gradient: trendDays[i]['isToday'] == true
                                          ? const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0xFFE0B66D),
                                                Color(0xFFBD8538),
                                              ],
                                            )
                                          : LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                const Color(0xFF7AB5A5),
                                                const Color(0xFF2B7365),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (trendDays[i]['showLabel'] == true)
                              Padding(
                                padding: EdgeInsets.only(top: capRpx(context, 7)),
                                child: Text(
                                  '${trendDays[i]['label']}',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: capRpx(
                                      context,
                                      _trendRange == 30 ? 12 : 13,
                                    ),
                                    color: AppColors.mutedSoft,
                                  ),
                                ),
                              )
                            else
                              SizedBox(height: capRpx(context, 22)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              SizedBox(height: capRpx(context, 16)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  capRpx(context, 14),
                  capRpx(context, 26),
                  capRpx(context, 14),
                  capRpx(context, 18),
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line, width: 1)),
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
                          'chart-no-axes-column',
                          size: capRpx(context, 34),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    Text(
                      '趋势还在积累',
                      style: TextStyle(
                        fontSize: capRpx(context, 21),
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 4)),
                    Text(
                      trendEmptyText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        height: 1.55,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: capRpx(context, 10)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: capRpx(context, 10)),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line, width: 1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CapIcon(
                    'info',
                    size: capRpx(context, 19),
                    color: AppColors.mutedSoft,
                  ),
                  SizedBox(width: capRpx(context, 4)),
                  Expanded(
                    child: Text(
                      trendFooter,
                      style: TextStyle(
                        fontSize: capRpx(context, 15),
                        height: 1.5,
                        color: AppColors.mutedSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: capRpx(context, 30)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 4)),
        child: Text(
          '用电信息',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            letterSpacing: capRpx(context, -0.6),
            color: AppColors.ink,
          ),
        ),
      ),
      SizedBox(height: capRpx(context, 12)),
      Container(
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Column(
          children: [
            _infoRow(context, 'map-pin', '寝室', dormName),
            _infoRow(
              context,
              'chart-no-axes-column',
              '计量方式',
              unit == '元' ? '预付费账户余额' : '剩余电量读数',
            ),
            _infoRow(context, 'clock-3', '最近更新', lastUpdated),
            _infoRow(
              context,
              'shield-check',
              '查询方式',
              '学校电费系统直连 · 不经服务器',
            ),
          ],
        ),
      ),
      SizedBox(height: capRpx(context, 16)),
      GestureDetector(
        onTap: () => _unbind(store),
        child: Container(
          height: capRpx(context, 66),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CapIcon(
                'trash-2',
                size: capRpx(context, 23),
                color: AppColors.muted,
              ),
              SizedBox(width: capRpx(context, 6)),
              Text(
                '解除寝室绑定',
                style: TextStyle(
                  fontSize: capRpx(context, 19),
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _unboundContent(BuildContext context, CapStore store) {
    return [
      Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 32),
          capRpx(context, 46),
          capRpx(context, 32),
          capRpx(context, 34),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 34)),
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: capRpx(context, 30),
              offset: Offset(0, capRpx(context, 12)),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: capRpx(context, 106),
              height: capRpx(context, 106),
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 32)),
              ),
              child: Center(
                child: CapIcon(
                  'zap',
                  size: capRpx(context, 46),
                  color: const Color(0xFF2C7363),
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 20)),
            Text(
              '先把寝室接进来',
              style: TextStyle(
                fontSize: capRpx(context, 34),
                fontWeight: FontWeight.w800,
                letterSpacing: capRpx(context, -1),
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: capRpx(context, 9)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: capRpx(context, 550)),
              child: Text(
                '龙泉与新都的全部寝室已经合并为一个搜索列表。选择一次，之后每次打开都能直接看到余额。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: capRpx(context, 21),
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 24)),
            GestureDetector(
              onTap: () => _openPicker(store),
              child: Container(
                height: capRpx(context, 78),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 24)),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(capRpx(context, 18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CapIcon(
                      'search',
                      size: capRpx(context, 27),
                      color: Colors.white,
                    ),
                    SizedBox(width: capRpx(context, 7)),
                    Text(
                      '选择寝室',
                      style: TextStyle(
                        fontSize: capRpx(context, 22),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CapIcon(
                  'shield-check',
                  size: capRpx(context, 21),
                  color: AppColors.mutedSoft,
                ),
                SizedBox(width: capRpx(context, 5)),
                Text(
                  '公开电费查询接口 · 无需账号密码',
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
      SizedBox(height: capRpx(context, 18)),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _featureCard(
                context,
                icon: 'layout-grid',
                title: '一个列表',
                text: '不再先选校区，直接搜索楼栋或寝室号',
              ),
            ),
            SizedBox(width: capRpx(context, 12)),
            Expanded(
              child: _featureCard(
                context,
                icon: 'refresh-cw',
                title: '一键刷新',
                text: '随时读取最新余额与当日用电',
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: capRpx(context, 30)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 4)),
        child: Text(
          '常见问题',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            letterSpacing: capRpx(context, -0.6),
            color: AppColors.ink,
          ),
        ),
      ),
      SizedBox(height: capRpx(context, 12)),
      Container(
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 24)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Column(
          children: [
            _faqRow(
              context,
              '为什么没有充值入口？',
              'CapuLife 只负责查询。充值仍需在原电费系统中完成，避免代付风险。',
            ),
            _faqRow(
              context,
              '需要登录学校账号吗？',
              '不需要。寝室电费查询使用公开接口，只需选择一次寝室。',
            ),
            _faqRow(
              context,
              '换寝室后要重新绑定吗？',
              '是的，在余额卡片中选择「更换寝室」即可。',
              last: true,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _balanceButton(
    BuildContext context, {
    required String icon,
    required String label,
    required bool light,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 58),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
        decoration: BoxDecoration(
          color: light ? const Color(0xFFF4EDDF) : Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: light
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            CapIcon(
              icon,
              size: capRpx(context, 25),
              color: light ? const Color(0xFF142B27) : Colors.white.withValues(alpha: 0.68),
            ),
            SizedBox(width: capRpx(context, 6)),
            Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 19),
                fontWeight: FontWeight.w700,
                color: light
                    ? const Color(0xFF142B27)
                    : Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String label,
    required String value,
    String unit = '',
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: capRpx(context, 14),
        vertical: capRpx(context, 16),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 20)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: capRpx(context, 16),
              color: AppColors.mutedSoft,
            ),
          ),
          SizedBox(height: capRpx(context, 4)),
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
                    fontSize: capRpx(context, 26),
                    fontWeight: FontWeight.w800,
                    letterSpacing: capRpx(context, -1),
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                SizedBox(width: capRpx(context, 3)),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: capRpx(context, 14),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendFact(BuildContext context, String key, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          key,
          style: TextStyle(
            fontSize: capRpx(context, 15),
            color: AppColors.mutedSoft,
          ),
        ),
        SizedBox(height: capRpx(context, 2)),
        Text(
          value,
          style: TextStyle(
            fontSize: capRpx(context, 21),
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context,
    String icon,
    String key,
    String value,
  ) {
    return Container(
      constraints: BoxConstraints(minHeight: capRpx(context, 72)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: capRpx(context, 38),
            child: CapIcon(
              icon,
              size: capRpx(context, 24),
              color: AppColors.muted,
            ),
          ),
          SizedBox(width: capRpx(context, 10)),
          SizedBox(
            width: capRpx(context, 110),
            child: Text(
              key,
              style: TextStyle(
                fontSize: capRpx(context, 19),
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: capRpx(context, 20),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: capRpx(context, 18),
        vertical: capRpx(context, 18),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 22)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: capRpx(context, 50),
            height: capRpx(context, 50),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 15)),
            ),
            child: Center(
              child: CapIcon(icon, size: capRpx(context, 30), color: AppColors.accent),
            ),
          ),
          SizedBox(height: capRpx(context, 12)),
          Text(
            title,
            style: TextStyle(
              fontSize: capRpx(context, 23),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 5)),
          Text(
            text,
            style: TextStyle(
              fontSize: capRpx(context, 17),
              height: 1.55,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqRow(
    BuildContext context,
    String question,
    String answer, {
    bool last = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: capRpx(context, 16)),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: capRpx(context, 21),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 4)),
          Text(
            answer,
            style: TextStyle(
              fontSize: capRpx(context, 18),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  String _longTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${pad2(date.month)}-${pad2(date.day)} ${pad2(date.hour)}:${pad2(date.minute)}';
  }
}

class _RoomPickerSheet extends StatefulWidget {
  const _RoomPickerSheet({required this.store, required this.onSelected});

  final CapStore store;
  final VoidCallback onSelected;

  @override
  State<_RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<_RoomPickerSheet> {
  final TextEditingController _query = TextEditingController();
  List<ElectricityRoom> _rooms = [];
  bool _loading = true;
  String _error = '';
  String _progressText = '正在读取寝室列表…';
  double _progressPercent = 8;
  String _buildingKey = '';
  String _floorFilter = '';

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _loadRooms();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadRooms({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
      _progressPercent = 8;
      _progressText = '正在读取寝室列表…';
    });
    try {
      final rooms = await ElectricityService.instance.listRooms(
        force: force,
        onProgress: (event) {
          if (!mounted) return;
          final label = event.system == 'xindu'
              ? '新都'
              : event.system == 'longquan'
              ? '龙泉'
              : '';
          setState(() {
            if (event.type == 'system-start') {
              _progressText = '正在读取$label寝室…';
            } else if (event.type == 'system-done') {
              _progressText = '$label寝室已读取';
            } else if (event.type == 'progress') {
              if (event.total > 0) {
                _progressPercent = math.max(
                  _progressPercent,
                  math.min(94, ((event.loaded / event.total) * 86).round() + 8),
                ).toDouble();
                _progressText = '正在读取寝室 ${event.loaded}/${event.total}';
              }
            } else if (event.type == 'cache') {
              _progressText = '已读取本机缓存';
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
        if (rooms.isNotEmpty) _progressPercent = 100;
      });
      if (rooms.isEmpty) {
        setState(() => _error = '两个电费系统都没有返回寝室数据');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (error is ElectricityException) {
          final details = error.errors?.values.join('；') ?? '';
          _error = details.isNotEmpty ? details : error.message;
        } else {
          _error = '无法连接学校电费系统，请检查网络后重试';
        }
      });
    }
  }

  List<Map<String, dynamic>> get _buildingGroups {
    final map = <String, Map<String, dynamic>>{};
    for (final room in _rooms) {
      final key = '${room.system}:${room.building}';
      final group = map.putIfAbsent(
        key,
        () => {
          'key': key,
          'system': room.system,
          'building': room.building,
          'campusLabel': room.campusLabel,
          'count': 0,
          'floors': <String>{},
        },
      );
      group['count'] = (group['count'] as int) + 1;
      if (room.floor.isNotEmpty) (group['floors'] as Set<String>).add(room.floor);
    }
    final list = map.values.toList();
    list.sort((a, b) {
      final numberA = _buildingNumber('${a['building']}');
      final numberB = _buildingNumber('${b['building']}');
      if (numberA != numberB) return numberA.compareTo(numberB);
      return '${a['building']}'.compareTo('${b['building']}');
    });
    return list;
  }

  int _buildingNumber(String name) {
    final match = RegExp(r'^(\d+)').firstMatch(name);
    return match == null ? 1 << 30 : int.parse(match.group(1)!);
  }

  Map<String, dynamic>? get _currentGroup {
    for (final group in _buildingGroups) {
      if (group['key'] == _buildingKey) return group;
    }
    return null;
  }

  List<String> get _floors {
    final group = _currentGroup;
    if (group == null) return [];
    return (group['floors'] as Set<String>).toList()
      ..sort((a, b) {
        final rankA = _floorRank(a);
        final rankB = _floorRank(b);
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.compareTo(b);
      });
  }

  int _floorRank(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? 0 : int.parse(match.group(0)!);
  }

  List<ElectricityRoom> get _roomResults {
    final query = _query.text.trim();
    var list = <ElectricityRoom>[];
    if (query.isNotEmpty) {
      final binding = widget.store.electricity['binding'];
      list = ElectricityService.instance.searchRooms(
        query,
        binding is Map ? [Map<String, dynamic>.from(binding)] : const [],
      );
      final group = _currentGroup;
      if (group != null) {
        list = list
            .where(
              (room) =>
                  room.system == group['system'] &&
                  room.building == group['building'],
            )
            .toList();
      }
    } else if (_currentGroup != null) {
      final group = _currentGroup!;
      list = _rooms
          .where(
            (room) =>
                room.system == group['system'] &&
                room.building == group['building'],
          )
          .toList();
    }
    if (_floorFilter.isNotEmpty) {
      list = list.where((room) => room.floor == _floorFilter).toList();
    }
    return list.take(240).toList();
  }

  Future<void> _selectRoom(ElectricityRoom room) async {
    final binding = ElectricityService.instance.createBinding(room);
    if (binding == null) {
      showCapToast(context, '寝室信息不完整');
      return;
    }
    widget.store.setElectricityBinding(binding);
    showCapToast(context, '已绑定寝室');
    Navigator.of(context).pop();
    widget.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return CapSheetPanel(
      title: '选择寝室',
      subtitle: '龙泉与新都统一搜索，不再区分校区',
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CapIcon('info', size: capRpx(context, 20), color: AppColors.mutedSoft),
          SizedBox(width: capRpx(context, 6)),
          Expanded(
            child: Text(
              '寝室选择不区分校区，列表来自两套学校电费系统。',
              style: TextStyle(
                fontSize: capRpx(context, 17),
                color: AppColors.mutedSoft,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: capRpx(context, 82),
            padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: Row(
              children: [
                CapIcon(
                  'search',
                  size: capRpx(context, 27),
                  color: AppColors.muted,
                ),
                SizedBox(width: capRpx(context, 10)),
                Expanded(
                  child: TextField(
                    controller: _query,
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索楼栋或寝室号，如 云威楼 A102',
                      hintStyle: TextStyle(
                        fontSize: capRpx(context, 21),
                        color: AppColors.mutedSoft,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_query.text.isNotEmpty)
                  GestureDetector(
                    onTap: _query.clear,
                    child: Container(
                      width: capRpx(context, 42),
                      height: capRpx(context, 42),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CapIcon(
                          'x',
                          size: capRpx(context, 24),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_loading) ...[
            SizedBox(height: capRpx(context, 22)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(capRpx(context, 18)),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CapIcon(
                        'loader-circle',
                        size: capRpx(context, 25),
                        color: AppColors.accent,
                      ),
                      SizedBox(width: capRpx(context, 8)),
                      Expanded(
                        child: Text(
                          _progressText,
                          style: TextStyle(
                            fontSize: capRpx(context, 20),
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: capRpx(context, 12)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: capRpx(context, 8),
                      color: AppColors.surface,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (_progressPercent / 100).clamp(0, 1),
                      heightFactor: 1,
                          child: const ColoredBox(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: capRpx(context, 8)),
                  Text(
                    '正在从两个电费系统读取寝室列表，首次加载可能需要几秒。',
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_error.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 22)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 20),
                vertical: capRpx(context, 24),
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 20)),
              ),
              child: Column(
                children: [
                  CapIcon(
                    'wifi-off',
                    size: capRpx(context, 38),
                    color: AppColors.muted,
                  ),
                  SizedBox(height: capRpx(context, 10)),
                  Text(
                    '寝室列表没有加载成功',
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 4)),
                  Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: capRpx(context, 18),
                      color: AppColors.muted,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 14)),
                  GestureDetector(
                    onTap: () => _loadRooms(force: true),
                    child: Container(
                      height: capRpx(context, 58),
                      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 18)),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(capRpx(context, 14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CapIcon(
                            'refresh-cw',
                            size: capRpx(context, 24),
                            color: Colors.white,
                          ),
                          SizedBox(width: capRpx(context, 6)),
                          Text(
                            '重试',
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
            ),
          ] else if (_query.text.trim().isEmpty && _buildingKey.isEmpty) ...[
            SizedBox(height: capRpx(context, 18)),
            Row(
              children: [
                Text(
                  '选择楼栋',
                  style: TextStyle(
                    fontSize: capRpx(context, 23),
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${_buildingGroups.length} 栋 · 混合排序',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 12)),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _buildingGroups.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: capRpx(context, 10),
                mainAxisSpacing: capRpx(context, 10),
                childAspectRatio: 2.5,
              ),
              itemBuilder: (context, index) {
                final group = _buildingGroups[index];
                return GestureDetector(
                  onTap: () => setState(() {
                    _buildingKey = '${group['key']}';
                    _floorFilter = '';
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: capRpx(context, 15),
                      vertical: capRpx(context, 12),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(capRpx(context, 18)),
                      border: Border.all(color: AppColors.line, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${group['building']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: capRpx(context, 22),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: capRpx(context, 7),
                                vertical: capRpx(context, 2),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(capRpx(context, 7)),
                              ),
                              child: Text(
                                '${group['campusLabel']}'.replaceAll('校区', ''),
                                style: TextStyle(
                                  fontSize: capRpx(context, 14),
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: capRpx(context, 3)),
                        Text(
                          '${group['count']} 间寝室',
                          style: TextStyle(
                            fontSize: capRpx(context, 17),
                            color: AppColors.mutedSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            SizedBox(height: capRpx(context, 18)),
            Row(
              children: [
                if (_buildingKey.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => setState(() {
                      _buildingKey = '';
                      _floorFilter = '';
                    }),
                    child: Row(
                      children: [
                        CapIcon(
                          'chevron-left',
                          size: capRpx(context, 24),
                          color: AppColors.accent,
                        ),
                        Text(
                          '楼栋',
                          style: TextStyle(
                            fontSize: capRpx(context, 19),
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: capRpx(context, 8)),
                ],
                Expanded(
                  child: Text(
                    _currentGroup == null
                        ? '搜索结果'
                        : '${_currentGroup!['building']} · ${'${_currentGroup!['campusLabel']}'.replaceAll('校区', '')}',
                    style: TextStyle(
                      fontSize: capRpx(context, 23),
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  '${_roomResults.length} 间',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
            if (_floors.length > 1) ...[
              SizedBox(height: capRpx(context, 10)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _floorChip(context, '全部', ''),
                    for (final floor in _floors) ...[
                      SizedBox(width: capRpx(context, 6)),
                      _floorChip(context, floor, floor),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: capRpx(context, 12)),
            if (_roomResults.isNotEmpty)
              Column(
                children: [
                  for (var i = 0; i < _roomResults.length; i += 1) ...[
                    if (i > 0) SizedBox(height: capRpx(context, 8)),
                    GestureDetector(
                      onTap: () => _selectRoom(_roomResults[i]),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: capRpx(context, 15),
                          vertical: capRpx(context, 13),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(capRpx(context, 18)),
                          border: Border.all(color: AppColors.line, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: capRpx(context, 48),
                              height: capRpx(context, 48),
                              decoration: BoxDecoration(
                                color: AppColors.mintSoft,
                                borderRadius: BorderRadius.circular(capRpx(context, 14)),
                              ),
                              child: Center(
                                child: CapIcon(
                                  'zap',
                                  size: capRpx(context, 26),
                                  color: AppColors.mint,
                                ),
                              ),
                            ),
                            SizedBox(width: capRpx(context, 12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _roomResults[i].roomName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: capRpx(context, 23),
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: capRpx(context, 8)),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: capRpx(context, 7),
                                          vertical: capRpx(context, 1),
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSoft,
                                          borderRadius: BorderRadius.circular(
                                            capRpx(context, 6),
                                          ),
                                        ),
                                        child: Text(
                                          _roomResults[i].campusLabel.replaceAll('校区', ''),
                                          style: TextStyle(
                                            fontSize: capRpx(context, 14),
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_roomResults[i].building} · ${_roomResults[i].floor}',
                                    style: TextStyle(
                                      fontSize: capRpx(context, 17),
                                      color: AppColors.mutedSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CapIcon(
                              'chevron-right',
                              size: capRpx(context, 24),
                              color: AppColors.mutedSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: capRpx(context, 34)),
                child: Column(
                  children: [
                    CapIcon(
                      'search',
                      size: capRpx(context, 36),
                      color: AppColors.mutedSoft,
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    Text(
                      '没有找到匹配的寝室',
                      style: TextStyle(
                        fontSize: capRpx(context, 21),
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 4)),
                    Text(
                      '试试只输入楼栋名或房间号的一部分',
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _floorChip(BuildContext context, String label, String value) {
    final active = _floorFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _floorFilter = value),
      child: Container(
        height: capRpx(context, 44),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.ink : AppColors.line,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: capRpx(context, 18),
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
