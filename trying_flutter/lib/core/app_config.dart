import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

late List<CameraDescription> cameras;

const String _envBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://ai-attendance-v2.onrender.com',
);

String get baseUrl {
  if (kIsWeb) {
    return const String.fromEnvironment('BASE_URL').isNotEmpty 
      ? const String.fromEnvironment('BASE_URL') 
      : ''; 
  }

  // For local development on a physical phone:
  // 1. Find your laptop's IP address (e.g., 192.168.1.5)
  // 2. Uncomment and update the line below:
  // return 'http://192.168.1.5:5001';

  return _envBaseUrl;
}
