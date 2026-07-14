import 'package:flutter/material.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/safe_insets.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

class WelfogApp extends StatelessWidget {
  const WelfogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welfog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorObservers: [play.appRouteObserver],
      initialRoute: SplashScreen.routeName,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // Android edge-to-edge can report padding.bottom = 0 while the system
      // nav/gesture bar still covers content. Re-inject viewPadding so SafeArea
      // and bottom CTAs automatically clear those buttons app-wide.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: ensureSystemBottomPadding(mq),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
