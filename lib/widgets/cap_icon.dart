import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Original CapuLife line icons (Lucide, ISC), bundled as monochrome SVG masks.
class CapIcon extends StatelessWidget {
  const CapIcon(
    this.name, {
    super.key,
    required this.size,
    this.color = const Color(0xFF101C2D),
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
