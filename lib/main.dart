import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/cap_store.dart';
import 'services/cap_capture.dart';
import 'services/cap_reminders.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  final store = await CapStore.load();
  runApp(CapuLifeNativeApp(store: store));
  CapReminders.warmStart(store);
  CapCapture.setWatchedApps(store.settings.captureApps);
  CapCapture.setPageCaptureEnabled(store.settings.autoLedger);
  CapCapture.sync(store);
}

class CapuLifeNativeApp extends StatelessWidget {
  const CapuLifeNativeApp({super.key, required this.store});

  final CapStore store;

  @override
  Widget build(BuildContext context) {
    return CapScope(
      store: store,
      child: MaterialApp(
        title: 'CapuLife',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        scrollBehavior: const _PaperScrollBehavior(),
        builder: (context, child) {
          final reduceMotion = CapScope.of(context).settings.reduceMotion;
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(disableAnimations: reduceMotion),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const ShellPage(),
      ),
    );
  }
}

class _PaperScrollBehavior extends MaterialScrollBehavior {
  const _PaperScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
