import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/adaptive_prefetch_engine.dart';
import 'services/device_id_store.dart';
import 'utils/app_routes.dart';
import 'utils/flutter_nav.dart';
import 'utils/profile_thumbnail_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureProfileImageCache();
  DeviceIdStore.warm();
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(systemUiDarkBackground);
  }
  AdaptivePrefetchEngine.load();
  runApp(const WelfogFlutterPlayApp());
}

class WelfogFlutterPlayApp extends StatelessWidget {
  const WelfogFlutterPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      onGenerateInitialRoutes: AppRoutes.onGenerateInitialRoutes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
