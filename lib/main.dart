import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully.");
  } catch (e) {
    debugPrint("Firebase Messaging initialization warning: Make sure you have placed google-services.json (Android) or GoogleService-Info.plist (iOS). Error details: $e");
  }

  runApp(const WelfogApp());
}
