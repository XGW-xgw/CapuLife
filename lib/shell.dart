import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'data/cap_store.dart';
import 'app_info.dart';
import 'services/cap_capture.dart';
import 'services/cap_reminders.dart';
import 'services/update_service.dart';
import 'widgets/update_flow.dart';
import 'pages/affairs_tab.dart';
import 'pages/home_tab.dart';
import 'pages/schedule_tab.dart';
import 'pages/tieba_tab.dart';
import 'theme.dart';
import 'widgets/glass_dock.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;
  int _slideDirection = 1;
  double _itemWidth = 0;
  final ValueNotifier<int> _homeVisit = ValueNotifier(0);

  late final AnimationController _capsule = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  late final AnimationController _jelly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  late final AnimationController _content = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );

  late final CurvedAnimation _contentCurve = CurvedAnimation(
    parent: _content,
    curve: softSpringCurve,
  );

  static bool _startupUpdateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _silentUpdateCheck();
    });
  }

  Future<void> _silentUpdateCheck() async {
    if (_startupUpdateChecked) return;
    _startupUpdateChecked = true;
    final store = CapScope.of(context);
    if (store.settings.update['enabled'] == false) return;
    final repo = '${store.settings.update['repo'] ?? defaultUpdateRepo}';
    final result = await UpdateService.check(repo);
    if (!mounted || !result.ok) return;
    final release = result.release;
    if (release == null) return;
    if (compareVersion(release.version, appVersion) <= 0) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(capRpx(context, 28)),
        ),
        title: Text(
          '发现新版本 v${release.version}',
          style: TextStyle(
            fontSize: capRpx(context, 29),
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: capRpx(context, 620)),
          child: SingleChildScrollView(
            child: Text(
              release.notes.isEmpty ? '有新版本可用，建议更新。' : release.notes,
              style: TextStyle(
                fontSize: capRpx(context, 21),
                height: 1.65,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'update'),
            child: const Text('立即本地更新', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (action == 'update') {
      await startLocalUpdate(context, release);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final store = CapScope.of(context);
    CapCapture.sync(store);
    CapReminders.warmStart(store);
    if (_index == 0) _homeVisit.value += 1;
  }

  @override
  void dispose() {
    _homeVisit.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _capsule.dispose();
    _jelly.dispose();
    _content.dispose();
    _contentCurve.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) {
      if (index == 0) _homeVisit.value += 1;
      return;
    }
    final reduceMotion = CapScope.of(context).settings.reduceMotion;
    final direction = index > _index ? 1 : -1;
    setState(() {
      _slideDirection = direction;
      _index = index;
    });
    if (index == 0) _homeVisit.value += 1;
    if (reduceMotion) {
      _content.value = 1;
      _jelly.value = 1;
      _capsule.value = index * _itemWidth;
      return;
    }
    _content.forward(from: 0);
    _jelly.forward(from: 0);
    final spring = SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 380),
      bounce: 0.24,
    );
    _capsule.animateWith(
      SpringSimulation(spring, _capsule.value, index * _itemWidth, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = CapScope.of(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final margin = capRpx(context, 28);
    final pad = capRpx(context, 8);
    final dockBottom = safeBottom + capRpx(context, 18);
    final items = [
      const DockItemData(label: '首页', icon: 'home'),
      const DockItemData(label: '课表', icon: 'calendar-days'),
      DockItemData(
        label: '事务',
        icon: 'layout-grid',
        badge: store.pendingTodos.length,
      ),
      const DockItemData(label: '贴吧', icon: 'message-circle'),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final dockWidth = constraints.maxWidth - margin * 2;
            final itemWidth = (dockWidth - pad * 2) / 4;
            if ((_itemWidth - itemWidth).abs() > 0.1) {
              _itemWidth = itemWidth;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!_capsule.isAnimating) {
                  _capsule.value = _index * _itemWidth;
                }
              });
            }
            return Stack(
              children: [
                const Positioned.fill(child: _PaperBackdrop()),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _contentCurve,
                    builder: (context, child) {
                      final t = _contentCurve.value.clamp(0.0, 1.0);
                      final opacity = t < 0.58 ? 0.55 + 0.45 * (t / 0.58) : 1.0;
                      final double scale;
                      if (t < 0.58) {
                        scale = _lerp(0.982, 1.006, t / 0.58);
                      } else if (t < 0.80) {
                        scale = _lerp(1.006, 0.999, (t - 0.58) / 0.22);
                      } else {
                        scale = _lerp(0.999, 1, (t - 0.80) / 0.20);
                      }
                      final dy = t < 0.58
                          ? _lerp(capRpx(context, 14), 0, t / 0.58)
                          : 0.0;
                      final progress = (1 - t).clamp(0.0, 1.0);
                      final dx = _slideDirection * progress * capRpx(context, 22);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.scale(
                            scale: scale,
                            alignment: const Alignment(0, -0.64),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: IndexedStack(
                      index: _index,
                      children: [
                        HomeTab(onOpenTab: _select, visitSignal: _homeVisit),
                        const ScheduleTab(),
                        AffairsTab(onOpenTab: _select),
                        const TiebaTab(),
                      ],
                    ),
                  ),
                ),
                if (safeTop > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: safeTop,
                    child: const ColoredBox(color: AppColors.bg),
                  ),
                Positioned(
                  left: margin,
                  right: margin,
                  bottom: dockBottom,
                  child: GlassDock(
                    items: items,
                    selected: _index,
                    capsulePosition: _capsule,
                    jelly: _jelly,
                    itemWidth: _itemWidth,
                    onSelect: _select,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);
}

class _PaperBackdrop extends StatelessWidget {
  const _PaperBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
        Positioned(
          top: -120,
          left: -100,
          right: -100,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 0.9,
                colors: [
                  AppColors.accent.withValues(alpha: 0.08),
                  AppColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: -120,
          width: 320,
          height: 320,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.7,
                colors: [
                  AppColors.gold.withValues(alpha: 0.10),
                  AppColors.gold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
