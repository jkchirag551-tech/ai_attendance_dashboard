import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_config.dart';
import 'core/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await OfflineCache.init();
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'MR. Attendance',
          debugShowCheckedModeBanner: false,
          theme: appState.currentTheme,
          home: const SplashScreen(),
        );
      },
    );
  }
}
