import 'package:flutter/material.dart';

import '../theme.dart';
import 'cap_icon.dart';
import 'pressable.dart';

class CapAppHeader extends StatelessWidget {
  const CapAppHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.back = false,
    this.right,
    this.left,
  });

  final String title;
  final String subtitle;
  final bool back;
  final Widget? right;
  final Widget? left;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: safeTop),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          capRpx(context, 36),
          capRpx(context, 12),
          capRpx(context, 36),
          capRpx(context, 8),
        ),
        constraints: BoxConstraints(minHeight: capRpx(context, 92)),
        child: Row(
          children: [
            SizedBox(
              width: capRpx(context, 200),
              child: Row(
                children: [
                  if (back)
                    Pressable(
                      onTap: () => Navigator.maybePop(context),
                      scale: 0.94,
                      child: Container(
                        width: capRpx(context, 68),
                        height: capRpx(context, 68),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.line, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: CapIcon(
                            'chevron-left',
                            size: capRpx(context, 38),
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  if (left != null) ...[
                    SizedBox(width: capRpx(context, 14)),
                    left!,
                  ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: capRpx(context, 30),
                      fontWeight: FontWeight.w800,
                      letterSpacing: capRpx(context, -0.6),
                      color: AppColors.ink,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: capRpx(context, 2)),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: capRpx(context, 20),
                        letterSpacing: capRpx(context, 0.4),
                        color: AppColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: capRpx(context, 200),
              child: Align(
                alignment: Alignment.centerRight,
                child: right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, this.onTap});

  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = capRpx(context, 68);
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: CapIcon(icon, size: capRpx(context, 32), color: AppColors.ink),
        ),
      ),
    );
  }
}
