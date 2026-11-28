import 'package:flutter/material.dart';

import '../theme.dart';

/// Soft breathing placeholder used while lists are loading.
class CapSkeletonPulse extends StatefulWidget {
  const CapSkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<CapSkeletonPulse> createState() => _CapSkeletonPulseState();
}

class _CapSkeletonPulseState extends State<CapSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.42,
    end: 0.82,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class CapSkeletonBox extends StatelessWidget {
  const CapSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder shaped like a Tieba thread card.
class CapThreadSkeleton extends StatelessWidget {
  const CapThreadSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CapSkeletonPulse(
      child: Container(
        padding: EdgeInsets.all(capRpx(context, 22)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(capRpx(context, 30)),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: capRpx(context, 46),
                  height: capRpx(context, 46),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: capRpx(context, 12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CapSkeletonBox(
                      width: capRpx(context, 150),
                      height: capRpx(context, 22),
                      radius: capRpx(context, 7),
                    ),
                    SizedBox(height: capRpx(context, 7)),
                    CapSkeletonBox(
                      width: capRpx(context, 220),
                      height: capRpx(context, 16),
                      radius: capRpx(context, 6),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 16)),
            CapSkeletonBox(
              width: double.infinity,
              height: capRpx(context, 30),
              radius: capRpx(context, 9),
            ),
            SizedBox(height: capRpx(context, 9)),
            CapSkeletonBox(
              width: capRpx(context, 440),
              height: capRpx(context, 20),
              radius: capRpx(context, 7),
            ),
            SizedBox(height: capRpx(context, 14)),
            CapSkeletonBox(
              width: double.infinity,
              height: capRpx(context, 150),
              radius: capRpx(context, 18),
            ),
          ],
        ),
      ),
    );
  }
}

class CapThreadSkeletonList extends StatelessWidget {
  const CapThreadSkeletonList({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i += 1) ...[
          if (i > 0) SizedBox(height: capRpx(context, 14)),
          const CapThreadSkeleton(),
        ],
      ],
    );
  }
}