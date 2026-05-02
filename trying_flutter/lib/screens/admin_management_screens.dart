import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/app_config.dart';
import '../models/app_models.dart';
import '../services/attendance_api_service.dart';
import '../widgets/shared_widgets.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key, this.title = 'User Management', this.filterRole});
  final String title;
  final String? filterRole;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _api = const AttendanceApiService();
  List<AppUser> _allUsers = [];
  String _activeFilter = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.filterRole ?? 'all';
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _api.fetchAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _bulkUpload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result == null) return;
    
    setState(() => _isLoading = true);
    try {
      await _api.bulkRegister(result.files.first.bytes!);
      _loadUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk upload successful!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      setState(() => _isLoading = false);
    }
  }

  List<AppUser> get _filteredUsers {
    if (_activeFilter == 'all') return _allUsers;
    return _allUsers.where((u) => u.role == _activeFilter).toList();
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.title,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: onSurface),
                      ),
                      const Spacer(),
                      if (widget.filterRole == null)
                        IconButton(
                          onPressed: _bulkUpload,
                          icon: Icon(Icons.upload_file_rounded, color: onSurface),
                          tooltip: 'Bulk Register (Excel)',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: 'View All', active: _activeFilter == 'all', onTap: () => setState(() => _activeFilter = 'all')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Students', active: _activeFilter == 'student', onTap: () => setState(() => _activeFilter = 'student')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Teachers', active: _activeFilter == 'teacher', onTap: () => setState(() => _activeFilter = 'teacher')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Admins', active: _activeFilter == 'admin', onTap: () => setState(() => _activeFilter = 'admin')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: onSurface))
                        : GlassPanel(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 24,
                            child: _filteredUsers.isEmpty 
                                ? Center(child: Text('No users found.', style: TextStyle(color: onSurface.withValues(alpha: 0.4))))
                                : ListView.builder(
                                    itemCount: _filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = _filteredUsers[index];
                                      return _UserListTile(user: user);
                                    },
                                  ),
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

class _FaceGuidePainter extends CustomPainter {
  final bool isAligned;
  _FaceGuidePainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isAligned ? Colors.green.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path()
      ..addOval(Rect.fromLTWH(
        size.width * 0.1, 
        size.height * 0.1, 
        size.width * 0.8, 
        size.height * 0.8,
      ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isStudent = user.role == 'student';
    final percentage = user.attendancePercentage;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: onSurface.withValues(alpha: 0.1),
            child: Icon(
              isStudent ? Icons.school_rounded : (user.role == 'teacher' ? Icons.person_rounded : Icons.admin_panel_settings_rounded),
              color: onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullname, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onSurface)),
                Text('${user.userid} • ${user.role.toUpperCase()}', style: TextStyle(color: onSurface.withValues(alpha: 0.4), fontSize: 13)),
                if (user.email != null && user.email!.isNotEmpty)
                  Text(user.email!, style: TextStyle(color: onSurface.withValues(alpha: 0.3), fontSize: 11)),
              ],
            ),
          ),
          if (isStudent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getPercentageColor(percentage).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _getPercentageColor(percentage),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getPercentageColor(double p) {
    if (p >= 75) return Colors.green.shade700;
    if (p >= 60) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: active ? onSurface : onSurface.withValues(alpha: 0.05),
      side: BorderSide(color: active ? onSurface : onSurface.withValues(alpha: 0.1)),
      labelStyle: TextStyle(
        color: active ? theme.colorScheme.surface : onSurface.withValues(alpha: 0.7),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() => _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  final _api = const AttendanceApiService();
  List<dynamic> _monthlyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await _api.fetchMonthlyAttendance();
      setState(() {
        _monthlyData = response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Monthly Attendance Log',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: onSurface))
                        : GlassPanel(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 24,
                            child: _monthlyData.isEmpty
                                ? Center(child: Text('No attendance data found.', style: TextStyle(color: onSurface.withValues(alpha: 0.4))))
                                : ListView.builder(
                                    itemCount: _monthlyData.length,
                                    itemBuilder: (context, index) {
                                      final item = _monthlyData[index];
                                      return InkWell(
                                        onTap: item['count'] > 0 
                                          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyAttendanceScreen(month: item['month']))) 
                                          : null,
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: onSurface.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(item['month'], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: onSurface)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(color: onSurface, borderRadius: BorderRadius.circular(10)),
                                                child: Text('${item['count']} RECORDS', style: TextStyle(color: theme.colorScheme.surface, fontSize: 12, fontWeight: FontWeight.w900)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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

class DailyAttendanceScreen extends StatefulWidget {
  final String month;
  const DailyAttendanceScreen({super.key, required this.month});

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  final _api = const AttendanceApiService();
  List<dynamic> _dailyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await _api.fetchDailyAttendance(widget.month);
      setState(() {
        _dailyData = response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Daily Logs: ${widget.month}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: onSurface))
                        : GlassPanel(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 24,
                            child: _dailyData.isEmpty
                                ? Center(child: Text('No daily data found.', style: TextStyle(color: onSurface.withValues(alpha: 0.4))))
                                : ListView.builder(
                                    itemCount: _dailyData.length,
                                    itemBuilder: (context, index) {
                                      final item = _dailyData[index];
                                      return InkWell(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayStudentsAttendanceScreen(date: item['date']))),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: onSurface.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(item['date'], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: onSurface)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(color: onSurface, borderRadius: BorderRadius.circular(10)),
                                                child: Text('${item['count']} SCANS', style: TextStyle(color: theme.colorScheme.surface, fontSize: 12, fontWeight: FontWeight.w900)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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

class DayStudentsAttendanceScreen extends StatefulWidget {
  final String date;
  const DayStudentsAttendanceScreen({super.key, required this.date});

  @override
  State<DayStudentsAttendanceScreen> createState() => _DayStudentsAttendanceScreenState();
}

class _DayStudentsAttendanceScreenState extends State<DayStudentsAttendanceScreen> {
  final _api = const AttendanceApiService();
  List<dynamic> _studentData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await _api.fetchDayStudentsAttendance(widget.date);
      setState(() {
        _studentData = response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Students: ${widget.date}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: onSurface))
                        : GlassPanel(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 24,
                            child: _studentData.isEmpty
                                ? Center(child: Text('No students found.', style: TextStyle(color: onSurface.withValues(alpha: 0.4))))
                                : ListView.builder(
                                    itemCount: _studentData.length,
                                    itemBuilder: (context, index) {
                                      final item = _studentData[index];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: onSurface.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['username'], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: onSurface)),
                                                Text(item['subject'], style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.5))),
                                              ],
                                            ),
                                            Text(item['time'], style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
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

class AdminRegisterScreen extends StatefulWidget {
  final String? fixedRole;
  const AdminRegisterScreen({super.key, this.fixedRole});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _api = const AttendanceApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _fullnameController = TextEditingController();
  final _useridController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedRole = 'student';
  bool _isLoading = false;
  List<int>? _faceBytes;
  CameraController? _cameraController;

  // ML Kit Face Guide
  late FaceDetector _faceDetector;
  bool _canProcess = true;
  String _guideText = 'Align face in circle';
  bool _isFaceAligned = false;

  @override
  void initState() {
    super.initState();
    if (widget.fixedRole != null) {
      _selectedRole = widget.fixedRole!;
    }
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableTracking: true,
      ),
    );
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    if (cameras.isEmpty) return;
    
    CameraDescription selectedCamera = cameras[0];
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        selectedCamera = camera;
        break;
      }
    }

    _cameraController = CameraController(
      selectedCamera, 
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
      _cameraController?.startImageStream(_processGuideStream);
    }
  }

  Future<void> _processGuideStream(CameraImage image) async {
    if (!_canProcess || _faceBytes != null) return;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          if (faces.isEmpty) {
            _guideText = 'No face detected';
            _isFaceAligned = false;
          } else {
            final face = faces.first;
            // Guide Logic: Check if face is centered and large enough
            final double faceWidth = face.boundingBox.width;
            if (faceWidth < 120) {
              _guideText = 'Move closer';
              _isFaceAligned = false;
            } else {
              _guideText = 'Face aligned! Hold still';
              _isFaceAligned = true;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Guide error: $e');
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
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
      if (_cameraController!.description.lensDirection == CameraLensDirection.front) {
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

  Future<void> _captureFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    _cameraController?.stopImageStream();
    final image = await _cameraController!.takePicture();
    final bytes = await image.readAsBytes();

    setState(() {
      _faceBytes = bytes;
      _cameraController?.dispose();
      _cameraController = null;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == 'student' && _faceBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture face for student registration')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await _api.registerUser(
        role: _selectedRole,
        fullname: _fullnameController.text.trim(),
        userid: _useridController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        faceImageBytes: _faceBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User registered successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Register User',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassPanel(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionLabel('Role'),
                          const SizedBox(height: 8),
                          if (widget.fixedRole != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: inputDecoration(onSurface).copyWith(color: onSurface.withValues(alpha: 0.05)),
                              child: Text(widget.fixedRole!.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
                            )
                          else
                            Container(
                              decoration: inputDecoration(onSurface),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRole,
                                  isExpanded: true,
                                  dropdownColor: theme.cardColor,
                                  items: const [
                                    DropdownMenuItem(value: 'student', child: Text('Student')),
                                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                                  ],
                                  onChanged: (v) => setState(() => _selectedRole = v!),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                            const SectionLabel('Face Biometrics'),
                            const SizedBox(height: 12),
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 240,
                                      height: 240,
                                      color: onSurface.withValues(alpha: 0.1),
                                      child: _cameraController != null && _cameraController!.value.isInitialized
                                          ? Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                CameraPreview(_cameraController!),
                                                // Oval guide overlay
                                                CustomPaint(
                                                  painter: _FaceGuidePainter(isAligned: _isFaceAligned),
                                                ),
                                              ],
                                            )
                                          : (_faceBytes != null
                                              ? Image.memory(Uint8List.fromList(_faceBytes!), fit: BoxFit.cover)
                                              : Icon(Icons.face_retouching_natural_rounded, size: 64, color: onSurface.withValues(alpha: 0.4))),
                                    ),
                                  ),
                                  if (_cameraController != null)
                                    Positioned(
                                      bottom: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _guideText,
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_cameraController != null)
                              FilledButton.icon(
                                onPressed: _isFaceAligned ? _captureFace : null, 
                                icon: const Icon(Icons.camera_rounded), 
                                label: const Text('Capture Enrollment'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _isFaceAligned ? onSurface : onSurface.withValues(alpha: 0.2), 
                                  foregroundColor: theme.colorScheme.surface,
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                  onPressed: _startCamera,
                                  icon: const Icon(Icons.videocam_rounded),
                                  label: Text(_faceBytes == null ? 'Start Enrollment Guide' : 'Retake Enrollment'),
                                  style: OutlinedButton.styleFrom(foregroundColor: onSurface, side: BorderSide(color: onSurface))),
                            const SizedBox(height: 18),
                          const SectionLabel('Full Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fullnameController,
                            style: TextStyle(color: onSurface),
                            decoration: fieldDecoration(onSurface: onSurface, hintText: 'John Doe', prefixIcon: Icons.person_outline),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('User ID / Roll No'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _useridController,
                            style: TextStyle(color: onSurface),
                            decoration: fieldDecoration(onSurface: onSurface, hintText: 'STU001', prefixIcon: Icons.badge_outlined),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Username'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(color: onSurface),
                            decoration: fieldDecoration(onSurface: onSurface, hintText: 'johndoe', prefixIcon: Icons.alternate_email_rounded),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(color: onSurface),
                            decoration: fieldDecoration(onSurface: onSurface, hintText: '••••••••', prefixIcon: Icons.lock_outline_rounded),
                            validator: (v) => v!.length < 4 ? 'Min 4 chars' : null,
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Email Address'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: onSurface),
                            decoration: fieldDecoration(onSurface: onSurface, hintText: 'student@example.com', prefixIcon: Icons.email_outlined),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Phone Number'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            style: TextStyle(color: onSurface),
                            decoration: fieldDecoration(onSurface: onSurface, hintText: '+91 XXXXX XXXXX', prefixIcon: Icons.phone_outlined),
                            validator: (v) => v!.isEmpty ? 'Phone number is required' : null,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _register,
                              style: FilledButton.styleFrom(backgroundColor: onSurface, foregroundColor: theme.colorScheme.surface),
                              child: _isLoading ? CircularProgressIndicator(color: theme.colorScheme.surface) : const Text('Register User'),
                            ),
                          ),
                        ],
                      ),
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
