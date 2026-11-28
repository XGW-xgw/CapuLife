import 'package:flutter/material.dart';

import '../data/cap_store.dart';
import '../theme.dart';
import '../utils/cap_date.dart';
import 'cap_icon.dart';

class TodoRow extends StatelessWidget {
  const TodoRow({
    super.key,
    required this.item,
    required this.onToggle,
    this.compact = true,
    this.onTap,
    this.showDivider = true,
    this.draggable = false,
    this.onDragStarted,
    this.onDragEnd,
    this.dragging = false,
  });

  final CapTodo item;
  final VoidCallback onToggle;
  final bool compact;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool draggable;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final bool dragging;

  bool get _overdue =>
      item.dueDate.isNotEmpty && !item.done && diffDays(item.dueDate) < 0;

  String get _metaText {
    if (item.dueDate.isEmpty) {
      if (item.reminder && item.reminderAt > 0) {
        final date = DateTime.fromMillisecondsSinceEpoch(item.reminderAt);
        return '提醒 ${formatDateCN(date)} ${pad2(date.hour)}:${pad2(date.minute)}';
      }
      return '';
    }
    final days = diffDays(item.dueDate);
    var label = '';
    if (days == 0) {
      label = '今天';
    } else if (days == 1) {
      label = '明天';
    } else if (days < 0) {
      label = '逾期 ${days.abs()} 天';
    } else {
      label = formatDateCNFromKey(item.dueDate);
    }
    if (item.dueTime.isNotEmpty) label += ' ${item.dueTime}';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaText;
    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: capRpx(context, compact ? 2 : 4),
        vertical: capRpx(context, compact ? 18 : 24),
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.line, width: 1))
            : null,
      ),
      child: Opacity(
        opacity: item.done || dragging ? 0.62 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: capsuleMotionFast,
                curve: capsuleSpringCurve,
                width: capRpx(context, 42),
                height: capRpx(context, 42),
                margin: EdgeInsets.only(top: capRpx(context, 3)),
                decoration: BoxDecoration(
                  color: item.done ? AppColors.ink : AppColors.surface,
                  borderRadius: BorderRadius.circular(capRpx(context, 14)),
                  border: Border.all(
                    color: item.done ? AppColors.ink : AppColors.lineStrong,
                    width: 1.5,
                  ),
                ),
                child: item.done
                    ? Center(
                        child: CapIcon(
                          'check',
                          size: capRpx(context, 24),
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            SizedBox(width: capRpx(context, 20)),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: capRpx(context, compact ? 26 : 27),
                            fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
                            height: 1.4,
                            letterSpacing: capRpx(context, -0.27),
                            color: item.done ? AppColors.muted : AppColors.ink,
                            decoration: item.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: AppColors.muted,
                            decorationThickness: 1,
                          ),
                        ),
                      ),
                      if (item.reminder && !item.done) ...[
                        SizedBox(width: capRpx(context, 10)),
                        CapIcon(
                          'bell',
                          size: capRpx(context, 22),
                          color: AppColors.muted,
                        ),
                      ],
                    ],
                  ),
                  if (!compact && (meta.isNotEmpty || item.note.isNotEmpty)) ...[
                    SizedBox(height: capRpx(context, 7)),
                    Row(
                      children: [
                        if (meta.isNotEmpty)
                          Flexible(
                            child: Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: capRpx(context, 21),
                                color: _overdue ? AppColors.coral : AppColors.muted,
                                fontWeight: _overdue
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        if (meta.isNotEmpty && item.note.isNotEmpty)
                          SizedBox(width: capRpx(context, 12)),
                        if (item.note.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: capRpx(context, 21),
                                color: AppColors.mutedSoft,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!compact && item.tags.isNotEmpty) ...[
                    SizedBox(height: capRpx(context, 7)),
                    Wrap(
                      spacing: capRpx(context, 8),
                      runSpacing: capRpx(context, 8),
                      children: [
                        for (final tag in item.tags)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: capRpx(context, 10),
                              vertical: capRpx(context, 2),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(capRpx(context, 8)),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: capRpx(context, 18),
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
                ),
              ),
            ),
            if (draggable)
              Padding(
                padding: EdgeInsets.only(left: capRpx(context, 12)),
                child: LongPressDraggable<String>(
                  data: item.id,
                  onDragStarted: onDragStarted,
                  onDragEnd: (_) => onDragEnd?.call(),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.sizeOf(context).width - capRpx(context, 90),
                      padding: EdgeInsets.symmetric(
                        horizontal: capRpx(context, 20),
                        vertical: capRpx(context, 16),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(capRpx(context, 18)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.16),
                            blurRadius: capRpx(context, 40),
                            offset: Offset(0, capRpx(context, 18)),
                          ),
                        ],
                      ),
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: capRpx(context, 26),
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.25,
                    child: CapIcon(
                      'grip-vertical',
                      size: capRpx(context, 30),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: capRpx(context, 8)),
                    child: CapIcon(
                      'grip-vertical',
                      size: capRpx(context, 30),
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return body;
  }
}
