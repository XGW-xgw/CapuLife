import 'package:flutter/material.dart';

import '../theme.dart';
import 'cap_icon.dart';
import 'pressable.dart';

Future<T?> showCapSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double heightFactor = 0.88,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8F081221),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * heightFactor,
    ),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 240),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: builder(sheetContext),
    ),
  );
}

class CapSheetPanel extends StatelessWidget {
  const CapSheetPanel({
    super.key,
    this.title = '',
    this.subtitle = '',
    required this.child,
    this.footer,
    this.onClose,
    this.maxHeight,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onClose;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight:
            maxHeight ?? MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 34),
        capRpx(context, 16),
        capRpx(context, 34),
        capRpx(context, 22) + safeBottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(capRpx(context, 40)),
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF081221).withValues(alpha: 0.22),
            blurRadius: capRpx(context, 90),
            offset: Offset(0, -capRpx(context, 30)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: capRpx(context, 68),
            height: capRpx(context, 7),
            margin: EdgeInsets.only(bottom: capRpx(context, 22)),
            decoration: BoxDecoration(
              color: const Color(0x24101C2D),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (title.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                capRpx(context, 2),
                0,
                capRpx(context, 2),
                capRpx(context, 22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: capRpx(context, 36),
                            fontWeight: FontWeight.w800,
                            letterSpacing: capRpx(context, -1.1),
                            color: AppColors.ink,
                            height: 1.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: capRpx(context, 6)),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: capRpx(context, 22),
                              color: AppColors.muted,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: capRpx(context, 20)),
                  Pressable(
                    scale: 0.94,
                    onTap:
                        onClose ??
                        () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Container(
                      width: capRpx(context, 58),
                      height: capRpx(context, 58),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CapIcon(
                          'x',
                          size: capRpx(context, 32),
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.only(bottom: capRpx(context, 10)),
                child: child,
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.only(top: capRpx(context, 20)),
              child: footer,
            ),
        ],
      ),
    );
  }
}
