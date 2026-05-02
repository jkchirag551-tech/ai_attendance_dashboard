import 'package:camera/camera.dart';

late List<CameraDescription> cameras;

const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://ai-attendance-v2.onrender.com',
);
