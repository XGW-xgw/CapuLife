import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Small staggered entrance used by content-first screens. It animates once
/// per widget state, never on ordinary rebuilds, and disables itself when the
/// user has reduced motion enabled.
class CapReveal extends StatefulWidget {
  const CapReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 14),
    this.scaleFrom = 0.992,
  });

  final Widget child;
  final int index;
  final Offset offset;
  final double scaleFrom;

  @override
  State<CapReveal> createState() => _CapRevealState();
}

class _CapRevealState extends State<CapReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<double> _motion = CurvedAnimation(
    parent: _controller,
    curve: capsuleSpringCurve,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeOut),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delay = Duration(
      milliseconds: 24 * widget.index.clamp(0, 8),
    );
    _timer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled) return widget.child;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final t = _motion.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * (1 - t),
              widget.offset.dy * (1 - t),
            ),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}