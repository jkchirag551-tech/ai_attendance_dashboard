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
  return _envBaseUrl;
}
