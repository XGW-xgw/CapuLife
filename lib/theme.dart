import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFFF4F1E9);
  static const bgDeep = Color(0xFFECE7DA);
  static const surface = Color(0xFFFFFDF8);
  static const surfaceSoft = Color(0xFFF8F5ED);
  static const ink = Color(0xFF101C2D);
  static const ink2 = Color(0xFF2D3848);
  static const muted = Color(0xFF666D74);
  static const mutedSoft = Color(0xFF7F8582);
  static const line = Color(0x17101C2D);
  static const lineStrong = Color(0x29101C2D);
  static const accent = Color(0xFF1646B8);
  static const accentSoft = Color(0xFFE9EEFB);
  static const gold = Color(0xFFC89445);
  static const goldSoft = Color(0xFFF5E6C8);
  static const coral = Color(0xFFCD5B45);
  static const coralSoft = Color(0xFFF8E3DE);
  static const mint = Color(0xFF2B7365);
  static const mintSoft = Color(0xFFE0EFE9);
  static const night = Color(0xFF0D1A2E);
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ).copyWith(
        surface: AppColors.surface,
        primary: AppColors.accent,
        onSurface: AppColors.ink,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    fontFamily: 'Manrope',
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CapPageTransitionsBuilder(),
        TargetPlatform.iOS: CapPageTransitionsBuilder(),
        TargetPlatform.macOS: CapPageTransitionsBuilder(),
        TargetPlatform.linux: CapPageTransitionsBuilder(),
        TargetPlatform.windows: CapPageTransitionsBuilder(),
      },
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.ink, height: 1.45),
      bodySmall: TextStyle(color: AppColors.muted, height: 1.45),
    ),
  );
}

/// The original web app is laid out on a 750rpx design grid.
double capRpx(BuildContext context, num value) =>
    MediaQuery.sizeOf(context).width * value / 750;

abstract final class AppText {
  static const display = TextStyle(
    fontFamily: 'Fraunces',
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    letterSpacing: -0.8,
  );

  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const section = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontSize: 12.5,
    color: AppColors.muted,
    height: 1.55,
  );

  static const caption = TextStyle(
    fontSize: 10,
    letterSpacing: 0.6,
    fontWeight: FontWeight.w700,
    color: AppColors.mutedSoft,
  );
}

const springCurve = Cubic(0.32, 1.5, 0.52, 1);
const softSpringCurve = Cubic(0.22, 1.12, 0.36, 1);

/// App-wide capsule motion: a springy, slightly overshooting settle used by
/// segmented pills, toggles and selected chips.
const capsuleSpringCurve = Cubic(0.18, 1.38, 0.3, 1);
const capsuleMotion = Duration(milliseconds: 420);
const capsuleMotionFast = Duration(milliseconds: 300);

/// Routes that host an Android platform WebView are excluded from page-level
/// opacity/transform transitions to avoid platform-view snapshot artifacts.
const capWebViewRouteName = 'cap.webview';

/// Page-level motion: a compact rise + fade with a soft spring-like settle.
class CapPageTransitionsBuilder extends PageTransitionsBuilder {
  const CapPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled || route.settings.name == capWebViewRouteName) {
      return child;
    }
    final settle = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.62, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );
    final depth = Tween<double>(begin: 1, end: 0.992).animate(secondary);
    final dim = Tween<double>(begin: 1, end: 0.94).animate(secondary);
    return AnimatedBuilder(
      animation: secondary,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.028),
            end: Offset.zero,
          ).animate(settle),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(settle),
            child: child,
          ),
        ),
      ),
      builder: (context, page) => Opacity(
        opacity: dim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: depth.value.clamp(0.0, 1.0),
          child: page,
        ),
      ),
    );
  }
}
