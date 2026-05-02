import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/app_config.dart';
import '../services/attendance_api_service.dart';
import '../widgets/shared_widgets.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> with SingleTickerProviderStateMixin {
  final _api = const AttendanceApiService();
  CameraController? _controller;
  String _scanResult = 'Initializing AI...';
  bool _isProcessing = false;
  final String _selectedSubject = 'Daily Check-in';
  bool _livenessVerified = false;
  String _livenessPrompt = '';
  late AnimationController _scanAnimController;

  // ML Kit
  late FaceDetector _faceDetector;
  bool _canProcess = true;
  bool _isCheckingLiveness = false;
  
  final List<String> _prompts = ['Blink your eyes', 'Turn head left', 'Turn head right', 'Smile slightly'];
  String _currentRequiredAction = '';

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
      ),
    );

    _initCamera();
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    _controller?.dispose();
    _scanAnimController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      setState(() => _scanResult = 'No camera found.');
      return;
    }

    CameraDescription selectedCamera = cameras[0];
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        selectedCamera = camera;
        break;
      }
    }

    _controller = CameraController(selectedCamera, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
    
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startLivenessTest();
      }
    } catch (e) {
      setState(() => _scanResult = 'Camera Error: $e');
    }
  }

  void _startLivenessTest() {
    final random = Random();
    _currentRequiredAction = _prompts[random.nextInt(_prompts.length)];
    
    setState(() {
      _livenessVerified = false;
      _isCheckingLiveness = true;
      _livenessPrompt = 'Action: $_currentRequiredAction';
      _scanResult = 'Keep face in frame';
    });

    _controller?.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_canProcess || _isProcessing || !_isCheckingLiveness) return;
    
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        setState(() => _scanResult = 'No face detected');
        return;
      }

      final face = faces.first;
      bool success = false;

      // Real Liveness Logic
      switch (_currentRequiredAction) {
        case 'Blink your eyes':
          if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
            if (face.leftEyeOpenProbability! < 0.2 && face.rightEyeOpenProbability! < 0.2) {
              success = true;
            }
          }
          break;
        case 'Turn head left':
          if (face.headEulerAngleY != null && face.headEulerAngleY! > 25) {
            success = true;
          }
          break;
        case 'Turn head right':
          if (face.headEulerAngleY != null && face.headEulerAngleY! < -25) {
            success = true;
          }
          break;
        case 'Smile slightly':
          if (face.smilingProbability != null && face.smilingProbability! > 0.8) {
            success = true;
          }
          break;
      }

      if (success && mounted) {
        _isCheckingLiveness = false;
        await _controller?.stopImageStream();
        setState(() {
          _livenessVerified = true;
          _livenessPrompt = 'Liveness Verified ✅';
          _scanResult = 'Marking Attendance...';
        });
        _scan();
      } else {
        setState(() => _scanResult = 'Performing: $_currentRequiredAction');
      }
    } catch (e) {
      debugPrint('ML Kit Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final sensorOrientation = _controller!.description.sensorOrientation;
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = orientations[MediaQuery.of(context).orientation == Orientation.portrait ? DeviceOrientation.portraitUp : DeviceOrientation.landscapeLeft];
      if (rotationCompensation == null) return null;
      if (_controller!.description.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _scan() async {
    if (_controller == null) return;
    _isProcessing = true;

    try {
      final picture = await _controller!.takePicture();
      final bytes = await picture.readAsBytes();
      final result = await _api.scanFrame(bytes, subject: _selectedSubject);
      
      if (!mounted) return;
      
      setState(() {
        _scanResult = result.message;
        _livenessPrompt = 'Verification Successful!';
      });
      
      if (result.message.contains('success') || result.message.contains('Welcome')) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanResult = e.toString();
          _livenessVerified = false;
          _livenessPrompt = 'Verification Failed';
        });
      }
    } finally {
      if (mounted) _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedDashboardBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface)),
                      const SizedBox(width: 8),
                      Text('AI Check-in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black,
                                  child: _controller?.value.isInitialized == true
                                      ? CameraPreview(_controller!)
                                      : Center(child: CircularProgressIndicator(color: theme.colorScheme.onSurface)),
                                ),
                              ),
                              if (!_livenessVerified)
                                AnimatedBuilder(
                                  animation: _scanAnimController,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: _scanAnimController.value * 300, 
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 4),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        GlassPanel(
                          padding: const EdgeInsets.all(24),
                          borderRadius: 28,
                          child: Column(
                            children: [
                              Text(_selectedSubject, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 8),
                              Text(_scanResult, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                              if (_livenessPrompt.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(_livenessPrompt, style: TextStyle(color: _livenessPrompt.contains('Failed') ? Colors.redAccent : Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 18)),
                              ],
                              if (!_isProcessing && (_scanResult.contains('Failed') || _scanResult.contains('not recognized') || _scanResult.contains('detected'))) ...[
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _startLivenessTest,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try Again'),
                                    style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.onSurface, foregroundColor: theme.colorScheme.surface),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
