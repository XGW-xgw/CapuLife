import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../data/cap_store.dart';
import '../services/cap_capture.dart';
import '../services/cap_reminders.dart';
import '../services/cap_system.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/app_header.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_page.dart';
import '../widgets/cap_sheet.dart';
import '../widgets/cap_toast.dart';
import '../widgets/cap_toggle.dart';
import '../widgets/update_flow.dart';
import 'ledger_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _updateRepo = TextEditingController();
  final TextEditingController _aiBase = TextEditingController();
  final TextEditingController _aiModel = TextEditingController();
  final TextEditingController _aiKey = TextEditingController();
  bool _showKey = false;
  bool _updateBusy = false;
  String _permissionLabel = '未开启';
  bool _captureEnabled = false;
  bool _accessEnabled = false;
  bool _licensesOpen = false;

  static const _captureApps = [
    ('com.tencent.mm', '微信'),
    ('com.eg.android.AlipayGphone', '支付宝'),
    ('com.unionpay', '云闪付'),
    ('com.icbc', '工商银行'),
    ('com.chinamworld.main', '建设银行'),
    ('cmb.pb', '招商银行'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = CapScope.of(context);
      setState(() {
        _updateRepo.text =
            '${store.settings.update['repo'] ?? defaultUpdateRepo}';
        _aiBase.text = '${store.settings.ai['baseUrl'] ?? ''}';
        _aiModel.text = '${store.settings.ai['model'] ?? ''}';
        _aiKey.text = '${store.settings.ai['apiKey'] ?? ''}';
      });
      _refreshCapture();
      _syncPermissionLabel();
    });
  }

  Future<void> _syncPermissionLabel() async {
    final granted = await CapSystem.hasNotificationPermission();
    if (!mounted) return;
    setState(() => _permissionLabel = granted ? '已开启' : '未开启');
  }

  @override
  void dispose() {
    _updateRepo.dispose();
    _aiBase.dispose();
    _aiModel.dispose();
    _aiKey.dispose();
    super.dispose();
  }

  Future<void> _refreshCapture() async {
    final listener = await CapSystem.isNotificationListenerEnabled();
    final access = await CapSystem.isAccessibilityEnabled();
    if (!mounted) return;
    setState(() {
      _captureEnabled = listener;
      _accessEnabled = access;
    });
  }

  Future<void> _requestPermission() async {
    final granted = await CapSystem.requestNotificationPermission();
    if (!mounted) return;
    setState(() => _permissionLabel = granted ? '已开启' : '未开启');
    if (granted) {
      showCapToast(context, '通知权限已开启');
    } else {
      await CapSystem.openNotificationSettings();
      if (!mounted) return;
      showCapToast(context, '可以在系统设置里允许 CapuLife 通知');
    }
  }

  Future<void> _testNotification() async {
    final granted = await CapSystem.requestNotificationPermission();
    if (!mounted) return;
    setState(() => _permissionLabel = granted ? '已开启' : '未开启');
    if (!granted) {
      showCapToast(context, '还没有通知权限');
      return;
    }
    await CapSystem.notifyNow(
      title: 'CapuLife 提醒测试',
      content: '如果你看到这条通知，提醒通道是畅通的。',
    );
    if (mounted) showCapToast(context, '已尝试发送测试提醒');
  }

  Future<void> _pickSemesterStart(CapStore store) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateKey(store.settings.semesterStart) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.ink,
            surface: AppColors.surface,
            onSurface: AppColors.ink,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      store.updateSettings(semesterStart: formatDateKey(picked));
    }
  }

  void _saveAi(CapStore store) {
    final enabled = store.settings.ai['enabled'] == true;
    if (enabled) {
      if (_aiBase.text.trim().isEmpty || _aiModel.text.trim().isEmpty) {
        showCapToast(context, '请填写接口地址与模型');
        return;
      }
      if (!RegExp(r'^https?://\S+$', caseSensitive: false)
          .hasMatch(_aiBase.text.trim())) {
        showCapToast(context, '接口地址需要是 http 或 https 链接');
        return;
      }
    }
    store.updateSettings(
      ai: {
        'enabled': enabled,
        'baseUrl': _aiBase.text.trim().replaceFirst(RegExp(r'/+$'), ''),
        'model': _aiModel.text.trim(),
        'apiKey': _aiKey.text.trim(),
      },
    );
    setState(() {
      _aiBase.text = '${store.settings.ai['baseUrl'] ?? ''}';
      _aiModel.text = '${store.settings.ai['model'] ?? ''}';
    });
    showCapToast(context, 'AI 设置已保存');
  }

  void _saveUpdateRepo(CapStore store) {
    final repo = _updateRepo.text
        .trim()
        .replaceFirst(RegExp(r'^https?://github\.com/'), '')
        .replaceFirst(RegExp(r'\.git$'), '')
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
    store.updateSettings(update: {...store.settings.update, 'repo': repo});
    _updateRepo.text = repo;
  }

  Future<void> _checkUpdate(CapStore store) async {
    if (_updateBusy) return;
    final repo = _updateRepo.text.trim();
    if (repo.isEmpty) {
      showCapToast(context, '先填写更新仓库');
      return;
    }
    _saveUpdateRepo(store);
    setState(() => _updateBusy = true);
    final result = await UpdateService.check(repo);
    if (!mounted) return;
    setState(() => _updateBusy = false);
    store.updateSettings(
      update: {
        ...store.settings.update,
        'lastCheckAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (!result.ok) {
      showCapToast(context, '检查失败：${result.error}');
      return;
    }
    final release = result.release!;
    if (compareVersion(release.version, appVersion) <= 0) {
      showCapToast(context, '已是最新版本 $appVersion');
      return;
    }
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '发现新版本 ${release.version}',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: capRpx(context, 700)),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本 $appVersion',
                  style: TextStyle(
                    fontSize: capRpx(context, 20),
                    color: AppColors.muted,
                  ),
                ),
                if (release.notes.isNotEmpty) ...[
                  SizedBox(height: capRpx(context, 12)),
                  Text(
                    release.notes,
                    style: TextStyle(
                      fontSize: capRpx(context, 20),
                      height: 1.65,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('稍后', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('本地更新', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (open == true) {
      await startLocalUpdate(context, release);
    }
  }

  void _toggleCaptureApp(CapStore store, String pkg) {
    final list = [...store.settings.captureApps];
    if (list.contains(pkg)) {
      list.remove(pkg);
    } else {
      list.add(pkg);
    }
    if (list.isEmpty) list.add(pkg);
    store.updateSettings(captureApps: list);
    CapCapture.setWatchedApps(list);
    setState(() {});
  }

  Future<void> _toggleAutoLedger(CapStore store) async {
    final next = store.settings.autoLedger != true;
    store.setAutoLedger(next);
    CapCapture.setPageCaptureEnabled(next);
    setState(() {});
    if (!next) return;
    await _refreshCapture();
    if (!mounted) return;
    if (!_captureEnabled) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(capRpx(context, 28)),
          ),
          title: Text(
            '还差一步',
            style: TextStyle(
              fontSize: capRpx(context, 30),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          content: Text(
            '需要在系统的「通知使用权」里勾选 CapuLife，才能读取微信、支付宝的付款通知。',
            style: TextStyle(
              fontSize: capRpx(context, 22),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('稍后', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('去开启', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      if (open == true) {
        await CapSystem.openListenerSettings();
      }
    } else {
      showCapToast(context, '自动记账已开启');
    }
  }

  Future<void> _goNotificationAccess() async {
    await CapSystem.openListenerSettings();
    await Future<void>.delayed(const Duration(seconds: 1));
    await _refreshCapture();
  }

  Future<void> _goAccessibility() async {
    await CapSystem.openAccessibilitySettings();
    await Future<void>.delayed(const Duration(seconds: 1));
    await _refreshCapture();
  }

  Future<void> _syncCaptures(CapStore store) async {
    final added = await CapCapture.sync(store);
    await _refreshCapture();
    if (!mounted) return;
    showCapToast(context, added > 0 ? '已处理 $added 笔' : '暂时没有新账单');
  }

  Future<void> _viewRawEvents() async {
    final events = await CapCapture.peekRaw();
    if (!mounted) return;
    if (events.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(capRpx(context, 28)),
          ),
          title: Text(
            '最近缓存',
            style: TextStyle(
              fontSize: capRpx(context, 30),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          content: Text(
            '还没有收到任何通知或页面文本。请先开启通知使用权 / 无障碍，再发一笔转账试试。',
            style: TextStyle(
              fontSize: capRpx(context, 22),
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('好的', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }
    final lines = <String>[];
    final newline = String.fromCharCode(10);
    for (var i = events.length - 1; i >= 0; i--) {
      final event = events[i];
      final at = (event['at'] as num?)?.toInt() ?? 0;
      final time = at == 0
          ? ''
          : '${pad2(DateTime.fromMillisecondsSinceEpoch(at).hour)}:${pad2(DateTime.fromMillisecondsSinceEpoch(at).minute)}';
      lines.add(
        '#${lines.length + 1} [${event['app'] ?? '通知'}] $time$newline'
        '标题：${event['title'] ?? ''}$newline'
        '文本：${event['text'] ?? ''}',
      );
    }
    final content = lines.take(6).join('$newline$newline');
    if (!mounted) return;
    final copy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '最近缓存（可截图反馈）',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: capRpx(context, 900)),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: TextStyle(
                fontSize: capRpx(context, 20),
                height: 1.6,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('复制', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (copy == true) {
      Clipboard.setData(ClipboardData(text: content));
      if (mounted) showCapToast(context, '已复制缓存文本');
    }
  }

  Future<void> _resetAll(CapStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '清除全部本地数据',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '待办、倒计日、课表、电费绑定都会被清除，无法恢复。',
          style: TextStyle(
            fontSize: capRpx(context, 22),
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('全部清除', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final item in store.countdowns) {
        CapReminders.cancel(CapReminders.countdownKey(item.id));
      }
      for (final item in store.todos) {
        CapReminders.cancel(CapReminders.todoKey(item.id));
      }
      store.resetAllData();
      if (!mounted) return;
      showCapToast(context, '已清除全部本地数据');
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _copyInfo(CapStore store) {
    final lines = [
      'CapuLife $appVersion',
      appSchool,
      '课表课程：${store.courses.length}',
      '倒计日：${store.countdowns.length}',
      '待办：${store.todos.length}',
      '记账笔数：${store.ledger.transactions.length}',
      '数据仅保存在本机',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    showCapToast(context, '版本信息已复制');
  }

  void _openLicenses() {
    setState(() => _licensesOpen = true);
    showCapSheet<void>(
      context: context,
      heightFactor: 0.8,
      builder: (_) => const _LicensesSheet(),
    ).whenComplete(() {
      if (mounted) setState(() => _licensesOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final weekInfo = store.weekInfoAt(DateTime.now());
    final aiEnabled = store.settings.ai['enabled'] == true;
    final updateEnabled = store.settings.update['enabled'] != false;
    final autoLedger = store.settings.autoLedger;
    final pendingCount = store.ledger.pending.length;
    final captureApps = store.settings.captureApps;

    return CapPage(
      child: Column(
        children: [
          const CapAppHeader(
            title: '设置',
            subtitle: '让 CapuLife 更贴近你的节奏',
            back: true,
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
                _card(
                  context,
                  head: _head(
                    context,
                    icon: 'calendar-days',
                    color: const Color(0xFF96611C),
                    bg: AppColors.goldSoft,
                    title: '学期设置',
                    sub: '用于计算教学周与课表日期',
                  ),
                  children: [
                    _row(
                      context,
                      label: '开学日期',
                      trailing: GestureDetector(
                        onTap: () => _pickSemesterStart(store),
                        child: Row(
                          children: [
                            Text(
                              store.settings.semesterStart,
                              style: TextStyle(
                                fontSize: capRpx(context, 21),
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
                      ),
                    ),
                    _row(
                      context,
                      label: '学期总周数',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _stepperButton(
                            context,
                            'minus',
                            () => store.updateSettings(
                              totalWeeks: (store.settings.totalWeeks - 1).clamp(1, 30),
                            ),
                          ),
                          SizedBox(width: capRpx(context, 8)),
                          SizedBox(
                            width: capRpx(context, 38),
                            child: Text(
                              '${store.settings.totalWeeks}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: capRpx(context, 22),
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          SizedBox(width: capRpx(context, 8)),
                          _stepperButton(
                            context,
                            'plus',
                            () => store.updateSettings(
                              totalWeeks: (store.settings.totalWeeks + 1).clamp(1, 30),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: capRpx(context, 12)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: capRpx(context, 11),
                        vertical: capRpx(context, 9),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(capRpx(context, 10)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: capRpx(context, 6),
                            height: capRpx(context, 6),
                            decoration: const BoxDecoration(
                              color: AppColors.mint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: capRpx(context, 6)),
                          Text(
                            '当前第 ${weekInfo.week == 0 ? 1 : weekInfo.week} 周 · ${weekInfo.phase == 'active' ? '学期进行中' : weekInfo.phase == 'before' ? '尚未开学' : '学期已结束'}',
                            style: TextStyle(
                              fontSize: capRpx(context, 17),
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _card(
                  context,
                  head: _head(
                    context,
                    icon: 'bell',
                    color: AppColors.mint,
                    bg: AppColors.mintSoft,
                    title: '提醒与体验',
                    sub: '本地推送，不使用云端',
                  ),
                  children: [
                    _row(
                      context,
                      label: '通知权限',
                      hint: _permissionLabel,
                      trailing: _action(context, '请求权限', _requestPermission),
                    ),
                    _row(
                      context,
                      label: '测试一条提醒',
                      hint: '检查系统通知是否正常显示',
                      trailing: _action(context, '发送测试', _testNotification),
                    ),
                    _row(
                      context,
                      label: '减少动效',
                      hint: '关闭大部分页面过渡与卡片动画',
                      trailing: CapToggle(
                        value: store.settings.reduceMotion,
                        onChanged: (value) =>
                            store.updateSettings(reduceMotion: value),
                      ),
                    ),
                    _row(
                      context,
                      label: '显示余额数字',
                      hint: '关闭后用电页会隐藏具体数值',
                      trailing: CapToggle(
                        value: store.settings.showBalance,
                        onChanged: (value) =>
                            store.updateSettings(showBalance: value),
                      ),
                      last: true,
                    ),
                  ],
                ),
                _card(
                  context,
                  head: Row(
                    children: [
                      Expanded(
                        child: _head(
                          context,
                          icon: 'sparkles',
                          color: const Color(0xFF96611C),
                          bg: AppColors.goldSoft,
                          title: 'AI 拆解',
                          sub: '可选的大模型接口，不经过服务器',
                        ),
                      ),
                      CapToggle(
                        value: aiEnabled,
                        onChanged: (value) {
                          store.updateSettings(ai: {'enabled': value});
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  children: [
                    if (aiEnabled) ...[
                      SizedBox(
                        height: capRpx(context, 16),
                        child: const Divider(color: AppColors.line, height: 1),
                      ),
                      _aiField(context, '接口地址', _aiBase, 'https://api.openai.com/v1'),
                      _aiField(context, '模型名称', _aiModel, '例如 gpt-4o-mini'),
                      Padding(
                        padding: EdgeInsets.only(bottom: capRpx(context, 14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: capRpx(context, 4),
                                bottom: capRpx(context, 8),
                              ),
                              child: Text(
                                'API Key',
                                style: TextStyle(
                                  fontSize: capRpx(context, 20),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            Container(
                              height: capRpx(context, 82),
                              padding: EdgeInsets.symmetric(
                                horizontal: capRpx(context, 16),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(capRpx(context, 18)),
                                border: Border.all(color: AppColors.line, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _aiKey,
                                      obscureText: !_showKey,
                                      style: TextStyle(
                                        fontSize: capRpx(context, 21),
                                        color: AppColors.ink,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '仅保存在本机',
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
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _showKey = !_showKey),
                                    child: CapIcon(
                                      _showKey ? 'eye-off' : 'eye',
                                      size: capRpx(context, 24),
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _saveAi(store),
                        child: Container(
                          height: capRpx(context, 70),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(capRpx(context, 15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CapIcon(
                                'check',
                                size: capRpx(context, 24),
                                color: Colors.white,
                              ),
                              SizedBox(width: capRpx(context, 6)),
                              Text(
                                '保存 AI 设置',
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
                      SizedBox(height: capRpx(context, 12)),
                      _note(
                        context,
                        '只发送目标文字和截止日期；不会发送课表、待办或倒计日。若接口不支持跨域，H5 预览会失败，App 内不受影响。',
                      ),
                    ] else ...[
                      SizedBox(height: capRpx(context, 14)),
                      Container(
                        padding: EdgeInsets.only(top: capRpx(context, 14)),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
                        ),
                        child: Text(
                          '关闭时使用完全离线的本地智能模板，不会发起任何第三方请求。',
                          style: TextStyle(
                            fontSize: capRpx(context, 18),
                            height: 1.6,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                _card(
                  context,
                  head: Row(
                    children: [
                      Expanded(
                        child: _head(
                          context,
                          icon: 'zap',
                          color: const Color(0xFF96611C),
                          bg: AppColors.goldSoft,
                          title: '自动记账',
                          sub: '通知直接入账，无障碍进待确认',
                        ),
                      ),
                      CapToggle(
                        value: autoLedger,
                        onChanged: (_) => _toggleAutoLedger(store),
                      ),
                    ],
                  ),
                  children: [
                    _row(
                      context,
                      label: '通知使用权',
                      hint: _captureEnabled ? '已开启，能收到付款通知' : '未开启，读不到任何通知',
                      trailing: _action(
                        context,
                        _captureEnabled ? '去查看' : '去开启',
                        _goNotificationAccess,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: capRpx(context, 12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '监听的应用',
                            style: TextStyle(
                              fontSize: capRpx(context, 21),
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: capRpx(context, 8)),
                          Wrap(
                            spacing: capRpx(context, 8),
                            runSpacing: capRpx(context, 8),
                            children: [
                              for (final app in _captureApps)
                                GestureDetector(
                                  onTap: () => _toggleCaptureApp(store, app.$1),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: capRpx(context, 12),
                                      vertical: capRpx(context, 4),
                                    ),
                                    decoration: BoxDecoration(
                                      color: captureApps.contains(app.$1)
                                          ? AppColors.ink
                                          : AppColors.surfaceSoft,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: captureApps.contains(app.$1)
                                            ? AppColors.ink
                                            : AppColors.line,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      app.$2,
                                      style: TextStyle(
                                        fontSize: capRpx(context, 17),
                                        fontWeight: FontWeight.w600,
                                        color: captureApps.contains(app.$1)
                                            ? Colors.white
                                            : AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _row(
                      context,
                      label: '待确认账单',
                      hint: pendingCount > 0 ? '$pendingCount 笔等你确认' : '暂时没有',
                      trailing: _action(context, '去处理', () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LedgerPage()),
                        );
                      }),
                    ),
                    _row(
                      context,
                      label: '后台保活',
                      hint: '把 CapuLife 加入电池优化白名单',
                      trailing: _action(context, '去设置', CapSystem.openBatterySettings),
                    ),
                    _row(
                      context,
                      label: '无障碍读取支付页',
                      hint: _accessEnabled ? '已开启，能识别聊天里的转账' : '未开启，转账和红包会漏',
                      trailing: _action(
                        context,
                        _accessEnabled ? '去查看' : '去开启',
                        _goAccessibility,
                      ),
                    ),
                    _row(
                      context,
                      label: '立即检查新账单',
                      hint: '打开 App 时也会自动检查',
                      trailing: _action(context, '检查', () => _syncCaptures(store)),
                    ),
                    _row(
                      context,
                      label: '查看最近缓存',
                      hint: '排查金额/对方为什么没识别到',
                      trailing: _action(context, '查看', _viewRawEvents),
                      last: true,
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    _note(
                      context,
                      '通知通道识别付款通知后直接入账（自动猜分类，可在账单里改）；无障碍通道识别转账/红包等短文本后进「待确认」，确认后才入账。不保存聊天内容。',
                    ),
                  ],
                ),
                _card(
                  context,
                  head: Row(
                    children: [
                      Expanded(
                        child: _head(
                          context,
                          icon: 'refresh-cw',
                          color: const Color(0xFF5F6370),
                          bg: const Color(0xFFF0EEE8),
                          title: '版本更新',
                          sub: '从 GitHub Release 检查新版本',
                        ),
                      ),
                      CapToggle(
                        value: updateEnabled,
                        onChanged: (value) {
                          store.updateSettings(
                            update: {...store.settings.update, 'enabled': value},
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  children: [
                    _row(
                      context,
                      label: '更新仓库',
                      hint: '默认 XGW-xgw/CapuLife，可改成自己的仓库',
                      trailing: SizedBox(
                        width: capRpx(context, 220),
                        child: Container(
                          height: capRpx(context, 58),
                          padding: EdgeInsets.symmetric(
                            horizontal: capRpx(context, 12),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(capRpx(context, 12)),
                            border: Border.all(color: AppColors.line, width: 0.8),
                          ),
                          child: TextField(
                            controller: _updateRepo,
                            textAlign: TextAlign.right,
                            onSubmitted: (_) => _saveUpdateRepo(store),
                            onTapOutside: (_) => _saveUpdateRepo(store),
                            style: TextStyle(
                              fontSize: capRpx(context, 19),
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: 'owner/repo',
                              hintStyle: TextStyle(
                                fontSize: capRpx(context, 19),
                                color: AppColors.mutedSoft,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      label: '当前版本',
                      hint: 'v$appVersion · 启动时静默检查',
                      trailing: _action(
                        context,
                        _updateBusy ? '检查中…' : '检查更新',
                        () => _checkUpdate(store),
                      ),
                    ),
                    _row(
                      context,
                      label: '本地安装 APK',
                      hint: '已下载好的安装包，直接从本机更新',
                      trailing: _action(
                        context,
                        '选择文件',
                        () => pickAndInstallLocalApk(context),
                      ),
                      last: true,
                    ),
                  ],
                ),
                _card(
                  context,
                  head: _head(
                    context,
                    icon: 'shield-check',
                    color: const Color(0xFF5F6370),
                    bg: const Color(0xFFF0EEE8),
                    title: '数据与隐私',
                    sub: '本地优先，不建立云端账号',
                  ),
                  children: [
                    SizedBox(height: capRpx(context, 16)),
                    Container(
                      padding: EdgeInsets.only(top: capRpx(context, 14)),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.line, width: 1)),
                      ),
                      child: Column(
                        children: [
                          _privacy(context, '账号密码保存在应用私有缓存，不随日志或崩溃信息上传。'),
                          _privacy(context, '课表、待办与倒计日只写入本机存储。'),
                          _privacy(context, '电费查询不需要账号，只使用公开查询接口。'),
                        ],
                      ),
                    ),
                    SizedBox(height: capRpx(context, 16)),
                    GestureDetector(
                      onTap: () => _resetAll(store),
                      child: Container(
                        height: capRpx(context, 64),
                        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 14)),
                        decoration: BoxDecoration(
                          color: AppColors.coralSoft,
                          borderRadius: BorderRadius.circular(capRpx(context, 13)),
                        ),
                        child: Row(
                          children: [
                            CapIcon(
                              'refresh-cw',
                              size: capRpx(context, 23),
                              color: AppColors.coral,
                            ),
                            SizedBox(width: capRpx(context, 6)),
                            Text(
                              '清除全部本地数据',
                              style: TextStyle(
                                fontSize: capRpx(context, 19),
                                color: AppColors.coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 34)),
                Column(
                  children: [
                    Text(
                      'CapuLife',
                      style: AppText.display.copyWith(
                        fontSize: capRpx(context, 36),
                        color: AppColors.muted,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 3)),
                    Text(
                      '版本 $appVersion · 事务中心',
                      style: TextStyle(
                        fontSize: capRpx(context, 18),
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      appSchool,
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: AppColors.mutedSoft,
                      ),
                    ),
                    SizedBox(height: capRpx(context, 10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _licensesOpen ? null : _openLicenses,
                          child: Text(
                            '开放源代码许可',
                            style: TextStyle(
                              fontSize: capRpx(context, 16),
                              color: AppColors.mutedSoft,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.mutedSoft,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: capRpx(context, 8)),
                          child: Text(
                            '·',
                            style: TextStyle(
                              fontSize: capRpx(context, 16),
                              color: AppColors.mutedSoft.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _copyInfo(store),
                          child: Text(
                            '复制版本信息',
                            style: TextStyle(
                              fontSize: capRpx(context, 16),
                              color: AppColors.mutedSoft,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.mutedSoft,
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
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required Widget head,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: capRpx(context, 14)),
      padding: EdgeInsets.all(capRpx(context, 22)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(capRpx(context, 28)),
        border: Border.all(color: AppColors.line, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.035),
            blurRadius: capRpx(context, 22),
            offset: Offset(0, capRpx(context, 8)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          SizedBox(height: capRpx(context, 2)),
          ...children,
        ],
      ),
    );
  }

  Widget _head(
    BuildContext context, {
    required String icon,
    required Color color,
    required Color bg,
    required String title,
    required String sub,
  }) {
    return Row(
      children: [
        Container(
          width: capRpx(context, 58),
          height: capRpx(context, 58),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(capRpx(context, 17)),
          ),
          child: Center(
            child: CapIcon(icon, size: capRpx(context, 30), color: color),
          ),
        ),
        SizedBox(width: capRpx(context, 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: capRpx(context, 25),
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
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    String hint = '',
    required Widget trailing,
    bool last = false,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: capRpx(context, 78)),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: capRpx(context, 21),
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (hint.isNotEmpty)
                  Text(
                    hint,
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
          SizedBox(width: capRpx(context, 14)),
          trailing,
        ],
      ),
    );
  }

  Widget _action(BuildContext context, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 48),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 13)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 11)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: capRpx(context, 17),
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _stepperButton(BuildContext context, String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 44),
        height: capRpx(context, 44),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 11)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 24), color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _aiField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: capRpx(context, 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: capRpx(context, 4),
              bottom: capRpx(context, 8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: capRpx(context, 20),
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          Container(
            height: capRpx(context, 82),
            padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              border: Border.all(color: AppColors.line, width: 0.8),
            ),
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: capRpx(context, 21), color: AppColors.ink),
              decoration: InputDecoration(
                hintText: hint,
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
        ],
      ),
    );
  }

  Widget _note(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapIcon(
          'info',
          size: capRpx(context, 19),
          color: AppColors.mutedSoft,
        ),
        SizedBox(width: capRpx(context, 5)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: capRpx(context, 16),
              height: 1.5,
              color: AppColors.mutedSoft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _privacy(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: capRpx(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: capRpx(context, 1)),
            child: CapIcon(
              'check',
              size: capRpx(context, 21),
              color: AppColors.mint,
            ),
          ),
          SizedBox(width: capRpx(context, 6)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: capRpx(context, 18),
                height: 1.55,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicensesSheet extends StatelessWidget {
  const _LicensesSheet();

  @override
  Widget build(BuildContext context) {
    const licenses = [
      ('Lucide Icons', 'ISC License', '界面线性图标，24×24 统一规格。'),
      ('Manrope', 'SIL Open Font License 1.1', '数字与拉丁文字体。'),
      ('Fraunces', 'SIL Open Font License 1.1', '品牌字标使用的衬线字体。'),
      ('CapuLife 插画与 Logo', '来自原应用', '校园纸雕插画与纸飞机 Logo，版权归原作者所有。'),
    ];
    return CapSheetPanel(
      title: '开放源代码许可',
      subtitle: 'CapuLife 使用了这些开放资源',
      child: Column(
        children: [
          for (var i = 0; i < licenses.length; i += 1) ...[
            if (i > 0) SizedBox(height: capRpx(context, 10)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 16),
                vertical: capRpx(context, 14),
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(capRpx(context, 15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    licenses[i].$1,
                    style: TextStyle(
                      fontSize: capRpx(context, 21),
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 2)),
                  Text(
                    licenses[i].$2,
                    style: TextStyle(
                      fontSize: capRpx(context, 16),
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(height: capRpx(context, 4)),
                  Text(
                    licenses[i].$3,
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      height: 1.5,
                      color: AppColors.muted,
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
}
