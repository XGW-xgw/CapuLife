import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'cap_icon.dart';

class DockItemData {
  const DockItemData({
    required this.label,
    required this.icon,
    this.badge = 0,
  });

  final String label;
  final String icon;
  final int badge;
}

/// Faithful Flutter port of the original CapTabBar.vue liquid-glass dock.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.selected,
    required this.capsulePosition,
    required this.jelly,
    required this.itemWidth,
    required this.onSelect,
  });

  final List<DockItemData> items;
  final int selected;
  final Animation<double> capsulePosition;
  final Animation<double> jelly;
  final double itemWidth;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final height = capRpx(context, 110);
    final pad = capRpx(context, 8);
    final radius = capRpx(context, 34);
    final capsuleRadius = capRpx(context, 24);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18),
            blurRadius: capRpx(context, 54),
            offset: Offset(0, capRpx(context, 24)),
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: capRpx(context, 10),
            offset: Offset(0, capRpx(context, 3)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x85FFFCF5)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.68, -1.6),
                        radius: 1.3,
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.8, 1.6),
                        radius: 1.2,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.20),
                          AppColors.gold.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.6],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.44, -1.6),
                        radius: 1.2,
                        colors: [
                          const Color(0xFF7AA8FF).withValues(alpha: 0.16),
                          const Color(0xFF7AA8FF).withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.36),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.4],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.72),
                          width: capRpx(context, 1),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([capsulePosition, jelly]),
                  builder: (context, child) {
                    final j = springCurve.transform(jelly.value.clamp(0.0, 1.0));
                    final (scaleX, scaleY) = _jellyScale(j);
                    return Positioned(
                      left: pad + capsulePosition.value,
                      top: pad,
                      width: itemWidth,
                      height: height - pad * 2,
                      child: Transform.scale(
                        scaleX: scaleX,
                        scaleY: scaleY,
                        child: child,
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(capsuleRadius),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(capsuleRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: capRpx(context, 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.08),
                            blurRadius: capRpx(context, 18),
                            offset: Offset(0, capRpx(context, 8)),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 1),
                            blurRadius: 0,
                            offset: Offset(0, capRpx(context, 1)),
                          ),
                        ],
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x9EFFFFFF),
                              Color(0x4DFFF7E9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _DockTab(
                              data: items[i],
                              active: selected == i,
                              onTap: () {
                                if (selected == i) return;
                                onSelect(i);
                              },
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
      ),
    );
  }

  static (double, double) _jellyScale(double t) {
    if (t <= 0.30) {
      final p = t / 0.30;
      return (1 + 0.09 * p, 1 - 0.06 * p);
    }
    if (t <= 0.62) {
      final p = (t - 0.30) / 0.32;
      return (1.09 - 0.105 * p, 0.94 + 0.08 * p);
    }
    final p = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
    return (0.985 + 0.015 * p, 1.02 - 0.02 * p);
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final DockItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.ink : AppColors.muted;
    final iconSize = capRpx(context, 42);
    final labelSize = capRpx(context, 21);
    final markerWidth = capRpx(context, 36);
    final markerHeight = capRpx(context, 4);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: capRpx(context, 44),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      duration: capsuleMotionFast,
                      curve: capsuleSpringCurve,
                      scale: active ? 1.07 : 1,
                      child: CapIcon(data.icon, size: iconSize, color: color),
                    ),
                    if (data.badge > 0)
                      Positioned(
                        top: -capRpx(context, 6),
                        right: -capRpx(context, 16),
                        child: Container(
                          height: capRpx(context, 24),
                          constraints: BoxConstraints(
                            minWidth: capRpx(context, 24),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: capRpx(context, 6),
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7644C),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: capRpx(context, 2),
                            ),
                          ),
                          child: Text(
                            data.badge > 9 ? '9+' : '${data.badge}',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Manrope',
                              fontSize: capRpx(context, 15),
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: capRpx(context, 5)),
              AnimatedDefaultTextStyle(
                duration: capsuleMotionFast,
                curve: capsuleSpringCurve,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: labelSize,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: labelSize * 0.02,
                  color: color,
                  height: 1,
                ),
                child: Text(data.label),
              ),
              SizedBox(height: capRpx(context, 4)),
              AnimatedOpacity(
                duration: capsuleMotionFast,
                curve: capsuleSpringCurve,
                opacity: active ? 1 : 0,
                child: AnimatedScale(
                  duration: capsuleMotion,
                  curve: capsuleSpringCurve,
                  scale: active ? 1 : 0.4,
                  child: Container(
                    width: markerWidth,
                    height: markerHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0x00B07F2F),
                          Color(0xFFC89445),
                          Color(0xFFA97428),
                          Color(0xFFC89445),
                          Color(0x00B07F2F),
                        ],
                        stops: [0, 0.16, 0.5, 0.84, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB07F2F).withValues(alpha: 0.26),
                          blurRadius: capRpx(context, 6),
                          offset: Offset(0, capRpx(context, 2)),
                        ),
                      ],
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
}
