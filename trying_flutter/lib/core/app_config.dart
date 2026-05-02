import 'package:camera/camera.dart';

late List<CameraDescription> cameras;

const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.0.100:5001',
);
