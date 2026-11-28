import 'package:flutter/material.dart';

import '../theme.dart';

class CapPage extends StatelessWidget {
  const CapPage({super.key, required this.child, this.bottomNavigationBar});

  final Widget child;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned.fill(child: CapPageBackground()),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class CapPageBackground extends StatelessWidget {
  const CapPageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
        Positioned(
          top: -90,
          left: -80,
          right: -80,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, -1),
                radius: 0.92,
                colors: [
                  const Color(0xFF2452AA).withValues(alpha: 0.12),
                  const Color(0xFF2452AA).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          left: -140,
          width: 320,
          height: 300,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  AppColors.gold.withValues(alpha: 0.12),
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
