import 'package:flutter/material.dart';

import '../theme.dart';

OverlayEntry? _activeToast;
int _toastToken = 0;

void showCapToast(BuildContext context, String message) {
  if (message.trim().isEmpty) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final token = ++_toastToken;
  _activeToast?.remove();
  _activeToast = null;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastView(
      message: message,
      onDone: () {
        if (token != _toastToken) return;
        entry.remove();
        if (identical(_activeToast, entry)) _activeToast = null;
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1700), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: capsuleSpringCurve),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 30),
                vertical: capRpx(context, 20),
              ),
              decoration: BoxDecoration(
                color: const Color(0xE60B1422),
                borderRadius: BorderRadius.circular(capRpx(context, 18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: capRpx(context, 24),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFFBF2),
                  height: 1.45,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
