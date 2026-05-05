import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../services/attendance_api_service.dart';
import '../services/notification_service.dart';
import '../widgets/shared_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = const AttendanceApiService();
  final _formKey = GlobalKey<FormState>();

  final _fullnameController = TextEditingController();
  final _useridController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  CameraController? _cameraController;
  XFile? _capturedImage;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _fullnameController.dispose();
    _useridController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }

      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras detected on this device.');
        return;
      }

      CameraDescription selectedCamera = cameras[0];
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      _cameraController = CameraController(selectedCamera, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Camera Permission Error: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      setState(() => _capturedImage = image);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to capture image: $e');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_capturedImage == null) {
      setState(() => _errorMessage = 'Please capture your face for registration.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final bytes = await _capturedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fcmToken = await NotificationService.getToken();

      await _api.signup(
        fullname: _fullnameController.text.trim(),
        userid: _useridController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        base64Image: base64Image,
        fcmToken: fcmToken,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Waiting for admin approval.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } on AttendanceApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedDashboardBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded)),
                  const SizedBox(height: 20),
                  Text('Create Account', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: onSurface, letterSpacing: -1.5)),
                  Text('Join the MR. Attendance network', style: TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 32),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildField('Full Name', _fullnameController, Icons.person_outline_rounded),
                        _buildField('ID Number / Roll No', _useridController, Icons.badge_outlined),
                        _buildField('Username', _usernameController, Icons.alternate_email_rounded),
                        _buildField('Password', _passwordController, Icons.lock_outline_rounded, isPassword: true),
                        _buildField('Email', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        _buildField('Phone Number', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const SectionLabel('Face Registration'),
                  const SizedBox(height: 12),

                  if (_capturedImage == null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _cameraController != null && _cameraController!.value.isInitialized
                          ? CameraPreview(_cameraController!)
                          : Container(color: Colors.black, child: const Center(child: CircularProgressIndicator())),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
                      ),
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _captureImage,
                      icon: Icon(_capturedImage == null ? Icons.camera_alt_rounded : Icons.refresh_rounded),
                      label: Text(_capturedImage == null ? 'Capture Face' : 'Retake Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: onSurface.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _register,
                      style: FilledButton.styleFrom(
                        backgroundColor: onSurface,
                        foregroundColor: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, TextInputType? keyboardType}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
            validator: (v) => v == null || v.isEmpty ? 'Field required' : null,
            decoration: fieldDecoration(
              onSurface: onSurface,
              hintText: 'Enter $label',
              prefixIcon: icon,
            ),
          ),
        ],
      ),
    );
  }
}
