import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    required this.size,
    required this.stroke,
    required this.color,
    required this.track,
    required this.holeColor,
    this.showPercent = true,
    this.valueStyle,
    this.unitStyle,
  });

  final int percent;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Color holeColor;
  final bool showPercent;
  final TextStyle? valueStyle;
  final TextStyle? unitStyle;

  @override
  Widget build(BuildContext context) {
    final safe = percent.clamp(0, 100);
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: safe.toDouble()),
        duration: disabled ? Duration.zero : const Duration(milliseconds: 680),
        curve: Curves.easeOutCubic,
        builder: (context, animated, child) {
          final shown = animated.round().clamp(0, 100);
          return CustomPaint(
            painter: _RingPainter(
              percent: shown,
              stroke: stroke,
              color: color,
              track: track,
              hole: holeColor,
            ),
            child: Center(
              child: showPercent
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$shown',
                          style:
                              valueStyle ??
                              TextStyle(
                                fontSize: size * 0.24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                letterSpacing: -0.6,
                                height: 1,
                              ),
                        ),
                        Text(
                          '%',
                          style:
                              unitStyle ??
                              TextStyle(
                                fontSize: size * 0.12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                                height: 1,
                              ),
                        ),
                      ],
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.percent,
    required this.stroke,
    required this.color,
    required this.track,
    required this.hole,
  });

  final int percent;
  final double stroke;
  final Color color;
  final Color track;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);
    if (percent > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * percent / 100,
        false,
        progressPaint,
      );
    }
    final holePaint = Paint()..color = hole;
    canvas.drawCircle(center, radius - stroke / 2, holePaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent ||
      old.color != color ||
      old.track != track ||
      old.hole != hole ||
      old.stroke != stroke;
}
