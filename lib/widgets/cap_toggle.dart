import 'package:flutter/material.dart';

import '../theme.dart';

class CapToggle extends StatelessWidget {
  const CapToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.width,
    this.height,
    this.thumbSize,
    this.travel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double? width;
  final double? height;
  final double? thumbSize;
  final double? travel;

  @override
  Widget build(BuildContext context) {
    final w = width ?? capRpx(context, 72);
    final h = height ?? capRpx(context, 42);
    final thumb = thumbSize ?? capRpx(context, 34);
    final pad = (h - thumb) / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: capsuleMotionFast,
        curve: capsuleSpringCurve,
        width: w,
        height: h,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: value ? AppColors.ink : const Color(0x24101C2D),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: capsuleMotion,
          curve: capsuleSpringCurve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
