import 'dart:io';

import 'package:flutter/material.dart';

import '../data/cap_store.dart';
import '../services/cap_image_picker.dart';
import '../services/cap_reminders.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import '../widgets/app_header.dart';
import '../widgets/cap_icon.dart';
import '../widgets/cap_page.dart';
import '../widgets/cap_sheet.dart';
import '../widgets/cap_toast.dart';
import '../widgets/cap_toggle.dart';
import '../widgets/countdown_card.dart';

const _suggestedTags = ['四六级', '考试', '生日', '纪念日', '旅行', '期末'];
const _skins = <(String, String)>[
  ('paper', '素笺'),
  ('mint', '青岚'),
  ('blossom', '海棠'),
  ('night', '墨夜'),
  ('sky', '雾蓝'),
];

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key, this.openAdd = false});

  final bool openAdd;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  String _activeTag = '全部';

  @override
  void initState() {
    super.initState();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCreate());
    }
  }

  void _openCreate() {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.92,
      builder: (_) => _CountdownEditorSheet(store: CapScope.of(context)),
    );
  }

  void _openEdit(CapCountdown item) {
    showCapSheet<void>(
      context: context,
      heightFactor: 0.92,
      builder: (_) => _CountdownEditorSheet(
        store: CapScope.of(context),
        existing: item,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final sorted = store.countdownsSorted;
    final visible = _activeTag == '全部'
        ? sorted
        : sorted.where((item) => item.tag == _activeTag).toList();
    final tagSet = <String>{
      '全部',
      ..._suggestedTags,
      ...store.allCountdownTags,
    };
    final tags = tagSet.take(12).toList();
    final upcoming = store.countdowns
        .where((item) => diffDays(item.targetDate) >= 0)
        .length;
    final reminderCount = store.countdowns
        .where((item) => item.reminder)
        .length;

    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: '倒计日',
            subtitle: '把期待写进日历',
            back: true,
            right: HeaderIconButton(icon: 'plus', onTap: _openCreate),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 28),
                capRpx(context, 8),
                capRpx(context, 28),
                capRpx(context, 60) + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _hero(context, store.countdowns.length, upcoming, reminderCount),
                SizedBox(height: capRpx(context, 24)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tag in tags) ...[
                        _tagChip(context, tag),
                        SizedBox(width: capRpx(context, 10)),
                      ],
                      _tagChip(context, '新建', add: true, onTap: _openCreate),
                    ],
                  ),
                ),
                SizedBox(height: capRpx(context, 18)),
                if (visible.isNotEmpty)
                  for (var i = 0; i < visible.length; i += 1) ...[
                    if (i > 0) SizedBox(height: capRpx(context, 20)),
                    CountdownCard(
                      item: visible[i],
                      variant: CountdownVariant.list,
                      onTap: () => _openEdit(visible[i]),
                    ),
                    SizedBox(height: capRpx(context, 8)),
                    _itemMeta(context, visible[i]),
                  ]
                else
                  _empty(context, store),
                SizedBox(height: capRpx(context, 30)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CapIcon(
                      'bell',
                      size: capRpx(context, 22),
                      color: AppColors.mutedSoft,
                    ),
                    SizedBox(width: capRpx(context, 6)),
                    Text(
                      '提醒由本机推送完成，不经过服务器。',
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

  Widget _hero(
    BuildContext context,
    int count,
    int upcoming,
    int reminders,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(capRpx(context, 32)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 28),
          capRpx(context, 26),
          capRpx(context, 28),
          capRpx(context, 28),
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF142D4E), Color(0xFF0C192C)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -capRpx(context, 90),
              top: -capRpx(context, 80),
              width: capRpx(context, 300),
              height: capRpx(context, 300),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF638BD3).withValues(alpha: 0.55),
                      const Color(0xFF638BD3).withValues(alpha: 0),
                    ],
                    stops: const [0, 0.64],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'COUNTDOWN BOARD',
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        fontWeight: FontWeight.w700,
                        letterSpacing: capRpx(context, 3.6),
                        color: Colors.white.withValues(alpha: 0.46),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: capRpx(context, 30),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF1CF89),
                      ),
                    ),
                    SizedBox(width: capRpx(context, 5)),
                    Text(
                      '个日子',
                      style: TextStyle(
                        fontSize: capRpx(context, 17),
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: capRpx(context, 28)),
                Text(
                  '把日子折成纸飞机，\n慢慢飞向它。',
                  style: TextStyle(
                    fontSize: capRpx(context, 40),
                    fontWeight: FontWeight.w800,
                    height: 1.38,
                    letterSpacing: capRpx(context, -1.4),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: capRpx(context, 18)),
                Row(
                  children: [
                    _heroMeta(context, 'hourglass', '$upcoming 个未到'),
                    SizedBox(width: capRpx(context, 22)),
                    _heroMeta(context, 'bell', '$reminders 个提醒'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMeta(BuildContext context, String icon, String text) {
    return Row(
      children: [
        CapIcon(
          icon,
          size: capRpx(context, 23),
          color: Colors.white.withValues(alpha: 0.54),
        ),
        SizedBox(width: capRpx(context, 6)),
        Text(
          text,
          style: TextStyle(
            fontSize: capRpx(context, 19),
            color: Colors.white.withValues(alpha: 0.54),
          ),
        ),
      ],
    );
  }

  Widget _tagChip(
    BuildContext context,
    String tag, {
    bool add = false,
    VoidCallback? onTap,
  }) {
    final active = !add && _activeTag == tag;
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _activeTag = tag),
      child: AnimatedContainer(
        duration: capsuleMotionFast,
        curve: capsuleSpringCurve,
        height: capRpx(context, 54),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 20)),
        decoration: BoxDecoration(
          color: add
              ? AppColors.accentSoft
              : active
              ? AppColors.ink
              : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: add
                ? Colors.transparent
                : active
                ? AppColors.ink
                : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (add) ...[
              CapIcon(
                'plus',
                size: capRpx(context, 21),
                color: AppColors.accent,
              ),
              SizedBox(width: capRpx(context, 4)),
            ],
            Text(
              tag,
              style: TextStyle(
                fontSize: capRpx(context, 21),
                fontWeight: FontWeight.w600,
                color: add
                    ? AppColors.accent
                    : active
                    ? Colors.white
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemMeta(BuildContext context, CapCountdown item) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 8)),
      child: Row(
        children: [
          if (item.tag.isNotEmpty) ...[
            Container(
              height: capRpx(context, 34),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 10)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: capRpx(context, 6),
                    height: capRpx(context, 6),
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: capRpx(context, 5)),
                  Text(
                    item.tag,
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: capRpx(context, 10)),
          ],
          if (item.pinned) ...[
            Text(
              '置顶',
              style: TextStyle(
                fontSize: capRpx(context, 16),
                color: AppColors.accent,
              ),
            ),
            SizedBox(width: capRpx(context, 10)),
          ],
          if (item.reminder)
            Row(
              children: [
                CapIcon(
                  'bell',
                  size: capRpx(context, 20),
                  color: AppColors.mutedSoft,
                ),
                SizedBox(width: capRpx(context, 4)),
                Text(
                  '提前 ${item.leadDays} 天',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    color: AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
          const Spacer(),
          GestureDetector(
            onTap: () => _openEdit(item),
            child: Row(
              children: [
                CapIcon(
                  'pencil',
                  size: capRpx(context, 20),
                  color: AppColors.muted,
                ),
                SizedBox(width: capRpx(context, 4)),
                Text(
                  '编辑',
                  style: TextStyle(
                    fontSize: capRpx(context, 17),
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, CapStore store) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 30),
        capRpx(context, 64),
        capRpx(context, 30),
        capRpx(context, 40),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: capRpx(context, 128),
                height: capRpx(context, 128),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 38)),
                ),
                child: Center(
                  child: CapIcon(
                    'hourglass',
                    size: capRpx(context, 52),
                    color: const Color(0xFFA36D25),
                  ),
                ),
              ),
              Positioned(
                left: -capRpx(context, 14),
                right: -capRpx(context, 14),
                top: -capRpx(context, 14),
                bottom: -capRpx(context, 14),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.lineStrong, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 24)),
          Text(
            _activeTag == '全部' ? '还没有倒计日' : '还没有「$_activeTag」的日子',
            style: TextStyle(
              fontSize: capRpx(context, 30),
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: capRpx(context, 8)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: capRpx(context, 460)),
            child: Text(
              '给未来放一个坐标，考试、生日和旅行都会更清晰。',
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
            onTap: _openCreate,
            child: Container(
              height: capRpx(context, 72),
              padding: EdgeInsets.symmetric(horizontal: capRpx(context, 24)),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(capRpx(context, 18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CapIcon('plus', size: capRpx(context, 27), color: Colors.white),
                  SizedBox(width: capRpx(context, 7)),
                  Text(
                    '添加第一个日子',
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
        ],
      ),
    );
  }
}

class _CountdownEditorSheet extends StatefulWidget {
  const _CountdownEditorSheet({required this.store, this.existing});

  final CapStore store;
  final CapCountdown? existing;

  @override
  State<_CountdownEditorSheet> createState() => _CountdownEditorSheetState();
}

class _CountdownEditorSheetState extends State<_CountdownEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _subtitle = TextEditingController(
    text: widget.existing?.subtitle ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late final TextEditingController _customTag = TextEditingController(
    text: widget.existing?.tag ?? '',
  );
  late String _date;
  late String _time;
  late String _tag;
  late String _skin;
  late String _customImage;
  late bool _reminder;
  late String _reminderTime;
  late int _leadDays;
  late bool _pinned;
  bool _customTagMode = false;

  CapCountdown? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final defaultDate = DateTime.now().add(const Duration(days: 30));
    _date = _existing?.targetDate ?? formatDateKey(defaultDate);
    _time = _existing?.targetTime ?? '09:00';
    _tag = _existing?.tag ?? '四六级';
    _skin = _existing?.skin ?? 'paper';
    _customImage = _existing?.customImage ?? '';
    if (_skin == 'custom' && _customImage.isEmpty) _skin = 'paper';
    _reminder = _existing?.reminder ?? true;
    _reminderTime = _existing?.reminderTime ?? '20:00';
    _leadDays = _existing?.leadDays ?? 1;
    _pinned = _existing?.pinned ?? false;
    _customTagMode = _tag.isNotEmpty && !_suggestedTags.contains(_tag);
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _note.dispose();
    _customTag.dispose();
    super.dispose();
  }

  CapCountdown get _preview => CapCountdown(
    id: _existing?.id ?? 'preview',
    title: _title.text.trim().isEmpty ? '倒计日' : _title.text.trim(),
    subtitle: _subtitle.text.trim(),
    targetDate: _date,
    targetTime: _time,
    tag: _customTagMode ? _customTag.text.trim() : _tag,
    skin: _skin,
    customImage: _customImage,
    reminder: _reminder,
    reminderTime: _reminderTime,
    leadDays: _leadDays,
    pinned: _pinned,
    note: _note.text.trim(),
    createdAt: _existing?.createdAt ?? 0,
  );

  DateTime? get _target => parseDateKey(_date);

  bool get _reminderPast {
    if (!_reminder) return false;
    final date = _target;
    if (date == null) return true;
    final clock = parseClock(_reminderTime);
    final at = DateTime(
      date.year,
      date.month,
      date.day - _leadDays.clamp(0, 30),
      clock?.hour ?? 20,
      clock?.minute ?? 0,
    );
    return !at.isAfter(DateTime.now());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _target ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _date = formatDateKey(picked));
  }

  Future<void> _pickTime({bool reminder = false}) async {
    final clock = parseClock(reminder ? _reminderTime : _time);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: clock?.hour ?? (reminder ? 20 : 9),
        minute: clock?.minute ?? 0,
      ),
      builder: _pickerTheme,
    );
    if (picked == null) return;
    setState(() {
      final text = '${pad2(picked.hour)}:${pad2(picked.minute)}';
      if (reminder) {
        _reminderTime = text;
      } else {
        _time = text;
      }
    });
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

  Future<void> _chooseImage() async {
    final path = await CapImagePicker.pickImage();
    if (path == null) return;
    if (!mounted) return;
    setState(() {
      _customImage = path;
      _skin = 'custom';
    });
  }

  void _selectSkin(String id) {
    setState(() {
      _skin = id;
      _customImage = '';
    });
  }

  void _selectTag(String tag) {
    setState(() {
      _customTagMode = false;
      _tag = _tag == tag ? '' : tag;
    });
  }

  void _toggleCustomTag() {
    setState(() {
      _customTagMode = !_customTagMode;
      if (_customTagMode) {
        _tag = '';
        _customTag.text = '';
      } else {
        _tag = '四六级';
      }
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showCapToast(context, '给这个日子起个名字');
      return;
    }
    if (_date.isEmpty) {
      showCapToast(context, '选择目标日期');
      return;
    }
    if (_reminder && _reminderPast) {
      showCapToast(context, '提醒时间已经过去');
      return;
    }
    if (_skin == 'custom' && _customImage.isEmpty) {
      showCapToast(context, '请选择一张自定义图片');
      return;
    }
    final tag = _customTagMode ? _customTag.text.trim() : _tag;
    final item = CapCountdown(
      id: _existing?.id ?? '',
      title: title,
      subtitle: _subtitle.text.trim(),
      targetDate: _date,
      targetTime: _time,
      tag: tag,
      skin: _skin,
      customImage: _skin == 'custom' ? _customImage : '',
      reminder: _reminder,
      reminderTime: _reminderTime,
      leadDays: _leadDays,
      pinned: _pinned,
      note: _note.text.trim(),
      createdAt: _existing?.createdAt ?? 0,
    );
    final saved = widget.store.upsertCountdown(item);
    if (saved != null) CapReminders.syncCountdown(saved);
    showCapToast(context, _existing == null ? '已加入倒计日' : '已保存修改');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 26)),
        ),
        title: Text(
          '删除这个倒计日',
          style: TextStyle(
            fontSize: capRpx(context, 30),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          '删除后不会影响其它日子。',
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
      widget.store.removeCountdown(_existing!.id);
      CapReminders.cancel(CapReminders.countdownKey(_existing!.id));
      showCapToast(context, '已删除');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final weekday = target == null ? '' : weekdayCN(target);
    final tagOptions = <String>{
      ..._suggestedTags,
      ...widget.store.allCountdownTags,
    }.toList();
    return CapSheetPanel(
      title: _existing == null ? '新的倒计日' : '编辑倒计日',
      subtitle: _existing == null ? '给未来留一个坐标' : '调整日期、皮肤或提醒',
      footer: Row(
        children: [
          if (_existing != null) ...[
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
                    size: capRpx(context, 28),
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
                      size: capRpx(context, 28),
                      color: Colors.white,
                    ),
                    SizedBox(width: capRpx(context, 7)),
                    Text(
                      _existing == null ? '保存这个日子' : '保存修改',
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
          CountdownCard(item: _preview, variant: CountdownVariant.compact),
          SizedBox(height: capRpx(context, 24)),
          _field(context, '标题', _title, '例如：大学英语四级', maxLength: 30),
          SizedBox(height: capRpx(context, 20)),
          _field(context, '补充说明', _subtitle, '选填，例如 CET-4', maxLength: 20),
          SizedBox(height: capRpx(context, 20)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, '目标日期'),
                    GestureDetector(
                      onTap: _pickDate,
                      child: _picker(
                        context,
                        icon: 'calendar-days',
                        text: _date,
                        trailingText: weekday,
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
                    _label(context, '时间'),
                    GestureDetector(
                      onTap: () => _pickTime(),
                      child: _picker(
                        context,
                        icon: 'clock-3',
                        text: _time,
                        trailingIcon: 'chevron-down',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 20)),
          _label(context, '标签'),
          Wrap(
            spacing: capRpx(context, 8),
            runSpacing: capRpx(context, 8),
            children: [
              for (final tag in tagOptions)
                _tagOption(
                  context,
                  tag,
                  active: !_customTagMode && _tag == tag,
                  onTap: () => _selectTag(tag),
                ),
              _tagOption(
                context,
                '自定义',
                active: _customTagMode,
                custom: true,
                onTap: _toggleCustomTag,
              ),
            ],
          ),
          if (_customTagMode) ...[
            SizedBox(height: capRpx(context, 10)),
            _simpleInput(context, _customTag, '输入标签，如 演出', maxLength: 10),
          ],
          SizedBox(height: capRpx(context, 20)),
          Row(
            children: [
              _label(context, '皮肤', noPadding: true),
              const Spacer(),
              Text(
                _skin == 'custom'
                    ? (_customImage.isEmpty ? '自定义图（未选择）' : '自定义图')
                    : _skins.firstWhere((s) => s.$1 == _skin, orElse: () => _skins.first).$2,
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 12)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final skin in _skins) ...[
                  _skinOption(
                    context,
                    id: skin.$1,
                    name: skin.$2,
                  ),
                  SizedBox(width: capRpx(context, 12)),
                ],
                _customSkinOption(context),
              ],
            ),
          ),
          if (_customImage.isNotEmpty) ...[
            SizedBox(height: capRpx(context, 10)),
            Row(
              children: [
                GestureDetector(
                  onTap: _chooseImage,
                  child: Row(
                    children: [
                      CapIcon(
                        'camera',
                        size: capRpx(context, 21),
                        color: AppColors.muted,
                      ),
                      SizedBox(width: capRpx(context, 4)),
                      Text(
                        '重新选择',
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: capRpx(context, 18)),
                GestureDetector(
                  onTap: () => setState(() {
                    _customImage = '';
                    _skin = 'paper';
                  }),
                  child: Row(
                    children: [
                      CapIcon(
                        'trash-2',
                        size: capRpx(context, 21),
                        color: AppColors.coral,
                      ),
                      SizedBox(width: capRpx(context, 4)),
                      Text(
                        '移除图片',
                        style: TextStyle(
                          fontSize: capRpx(context, 17),
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: capRpx(context, 20)),
          Container(
            padding: EdgeInsets.all(capRpx(context, 20)),
            decoration: BoxDecoration(
              gradient: _reminder
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF2F6FD), Color(0xFFFBF7EE)],
                    )
                  : null,
              color: _reminder ? null : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 24)),
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
                                size: capRpx(context, 27),
                                color: AppColors.ink,
                              ),
                              SizedBox(width: capRpx(context, 7)),
                              Text(
                                '本地提醒',
                                style: TextStyle(
                                  fontSize: capRpx(context, 24),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: capRpx(context, 3)),
                          Text(
                            !_reminder
                                ? '到时间后会发送系统通知'
                                : '${_leadDays == 0 ? '当天' : '提前 $_leadDays 天'} $_reminderTime · 由本机推送',
                            style: TextStyle(
                              fontSize: capRpx(context, 18),
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CapToggle(
                      value: _reminder,
                      onChanged: (value) => setState(() => _reminder = value),
                    ),
                  ],
                ),
                if (_reminder) ...[
                  SizedBox(height: capRpx(context, 18)),
                  Container(
                    padding: EdgeInsets.only(top: capRpx(context, 16)),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.line, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '提前',
                              style: TextStyle(
                                fontSize: capRpx(context, 20),
                                color: AppColors.muted,
                              ),
                            ),
                            const Spacer(),
                            for (final day in [0, 1, 3, 7]) ...[
                              GestureDetector(
                                onTap: () => setState(() => _leadDays = day),
                                child: Container(
                                  height: capRpx(context, 44),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: capRpx(context, 13),
                                  ),
                                  margin: EdgeInsets.only(left: capRpx(context, 6)),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _leadDays == day
                                        ? AppColors.ink
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: _leadDays == day
                                          ? AppColors.ink
                                          : AppColors.line,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    day == 0 ? '当天' : '$day 天',
                                    style: TextStyle(
                                      fontSize: capRpx(context, 18),
                                      color: _leadDays == day
                                          ? Colors.white
                                          : AppColors.muted,
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
                            Text(
                              '时间',
                              style: TextStyle(
                                fontSize: capRpx(context, 20),
                                color: AppColors.muted,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _pickTime(reminder: true),
                              child: Row(
                                children: [
                                  Text(
                                    _reminderTime,
                                    style: TextStyle(
                                      fontSize: capRpx(context, 21),
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  CapIcon(
                                    'chevron-right',
                                    size: capRpx(context, 20),
                                    color: AppColors.muted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_reminderPast) ...[
                          SizedBox(height: capRpx(context, 10)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CapIcon(
                                'triangle-alert',
                                size: capRpx(context, 21),
                                color: AppColors.coral,
                              ),
                              SizedBox(width: capRpx(context, 6)),
                              Expanded(
                                child: Text(
                                  '这个提醒时间已经过去，请调整日期或时间。',
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
              ],
            ),
          ),
          SizedBox(height: capRpx(context, 20)),
          Row(
            children: [
              _label(context, '备注', noPadding: true),
              const Spacer(),
              Text(
                '选填',
                style: TextStyle(
                  fontSize: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
              ),
            ],
          ),
          SizedBox(height: capRpx(context, 12)),
          _simpleInput(context, _note, '写一句给自己的话', maxLength: 80),
          SizedBox(height: capRpx(context, 6)),
          GestureDetector(
            onTap: () => setState(() => _pinned = !_pinned),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 2),
                vertical: capRpx(context, 12),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: capsuleMotionFast,
                    curve: capsuleSpringCurve,
                    width: capRpx(context, 32),
                    height: capRpx(context, 32),
                    decoration: BoxDecoration(
                      color: _pinned ? AppColors.ink : AppColors.surface,
                      borderRadius: BorderRadius.circular(capRpx(context, 9)),
                      border: Border.all(
                        color: _pinned ? AppColors.ink : AppColors.lineStrong,
                        width: 1.5,
                      ),
                    ),
                    child: _pinned
                        ? Center(
                            child: CapIcon(
                              'check',
                              size: capRpx(context, 21),
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: capRpx(context, 10)),
                  Text(
                    '在列表顶部固定',
                    style: TextStyle(
                      fontSize: capRpx(context, 21),
                      color: AppColors.muted,
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

  Widget _label(BuildContext context, String text, {bool noPadding = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        noPadding ? 0 : capRpx(context, 4),
        0,
        noPadding ? 0 : capRpx(context, 4),
        noPadding ? 0 : capRpx(context, 12),
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

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint, {
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, label),
        _simpleInput(context, controller, hint, maxLength: maxLength),
      ],
    );
  }

  Widget _simpleInput(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    int? maxLength,
  }) {
    return Container(
      height: capRpx(context, 92),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 26)),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 22)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: capRpx(context, 27), color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: capRpx(context, 23),
            color: AppColors.mutedSoft,
          ),
          counterText: '',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _picker(
    BuildContext context, {
    required String icon,
    required String text,
    String trailingText = '',
    String trailingIcon = '',
  }) {
    return Container(
      height: capRpx(context, 92),
      padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(capRpx(context, 20)),
        border: Border.all(color: AppColors.line, width: 0.8),
      ),
      child: Row(
        children: [
          CapIcon(icon, size: capRpx(context, 25), color: AppColors.ink),
          SizedBox(width: capRpx(context, 8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: capRpx(context, 23),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          if (trailingText.isNotEmpty)
            Text(
              trailingText,
              style: TextStyle(
                fontSize: capRpx(context, 17),
                color: AppColors.mutedSoft,
              ),
            ),
          if (trailingIcon.isNotEmpty)
            CapIcon(
              trailingIcon,
              size: capRpx(context, 21),
              color: AppColors.muted,
            ),
        ],
      ),
    );
  }

  Widget _tagOption(
    BuildContext context,
    String tag, {
    required bool active,
    required VoidCallback onTap,
    bool custom = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: capRpx(context, 50),
        padding: EdgeInsets.symmetric(horizontal: capRpx(context, 16)),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accentSoft
              : custom
              ? Colors.transparent
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.16)
                : custom
                ? AppColors.lineStrong
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (custom) ...[
              CapIcon(
                'plus',
                size: capRpx(context, 19),
                color: AppColors.mutedSoft,
              ),
              SizedBox(width: capRpx(context, 4)),
            ],
            Text(
              tag,
              style: TextStyle(
                fontSize: capRpx(context, 20),
                fontWeight: FontWeight.w600,
                color: active
                    ? AppColors.accent
                    : custom
                    ? AppColors.mutedSoft
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skinOption(BuildContext context, {required String id, required String name}) {
    final skin = skinFor(id);
    final active = _skin == id;
    return GestureDetector(
      onTap: () => _selectSkin(id),
      child: Column(
        children: [
          AnimatedContainer(
            duration: capsuleMotion,
            curve: capsuleSpringCurve,
            width: capRpx(context, 96),
            height: capRpx(context, 96),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: skin.background,
              ),
              border: Border.all(
                color: active ? AppColors.ink : Colors.transparent,
                width: 2,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.surface,
                        spreadRadius: capRpx(context, 2),
                      ),
                      BoxShadow(
                        color: AppColors.ink,
                        spreadRadius: capRpx(context, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.10),
                        blurRadius: capRpx(context, 16),
                        offset: Offset(0, capRpx(context, 6)),
                      ),
                    ],
            ),
            child: active
                ? Center(
                    child: CapIcon(
                      'check',
                      size: capRpx(context, 25),
                      color: skin.ink,
                    ),
                  )
                : null,
          ),
          SizedBox(height: capRpx(context, 6)),
          Text(
            name,
            style: TextStyle(
              fontSize: capRpx(context, 17),
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.ink : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customSkinOption(BuildContext context) {
    final active = _skin == 'custom';
    return GestureDetector(
      onTap: _chooseImage,
      child: Column(
        children: [
          Container(
            width: capRpx(context, 96),
            height: capRpx(context, 96),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(capRpx(context, 18)),
              color: AppColors.surfaceSoft,
              border: Border.all(
                color: active ? AppColors.ink : AppColors.lineStrong,
                width: active ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _customImage.isEmpty
                ? Center(
                    child: CapIcon(
                      'image-plus',
                      size: capRpx(context, 27),
                      color: const Color(0xFF8F978F),
                    ),
                  )
                : Image.file(
                    File(_customImage),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Center(
                      child: CapIcon(
                        'image-plus',
                        size: capRpx(context, 27),
                        color: const Color(0xFF8F978F),
                      ),
                    ),
                  ),
          ),
          SizedBox(height: capRpx(context, 6)),
          Text(
            '自定义图',
            style: TextStyle(
              fontSize: capRpx(context, 17),
              color: active ? AppColors.ink : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
