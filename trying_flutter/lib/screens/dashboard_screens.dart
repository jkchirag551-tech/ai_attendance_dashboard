import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

import '../models/app_models.dart';
import '../services/attendance_api_service.dart';
import '../services/report_service.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/dashboard_widgets.dart';
import 'admin_management_screens.dart';
import 'face_scan_screen.dart';
import 'notice_screen.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import '../widgets/dialog_widgets.dart';
import '../services/notification_service.dart';

class AdminDashboard extends StatefulWidget {
  final String username;
  const AdminDashboard({super.key, required this.username});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _api = const AttendanceApiService();
  AdminDashboardData data = AdminDashboardData.empty();
  List<Map<String, dynamic>> _weeklyStats = [];
  List<AppUser> _allUsers = [];
  double _lowAttendanceThreshold = 75.0;
  bool _isLoading = true;
  bool _isExporting = false;
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _initSocket();
  }

  void _initSocket() {
    try {
      _socket = IO.io(_api.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });

      _socket?.on('new_checkin', (payload) {
        if (mounted) {
          setState(() {
            data.recentLogs.insert(0, AttendanceLog.fromJson(payload as Map<String, dynamic>));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Identity Verified: ${payload['username']}'), behavior: SnackBarBehavior.floating),
          );
        }
      });
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final response = await _api.fetchAdminDashboard();
      final stats = await _api.fetchWeeklyStats();
      final users = await _api.fetchAllUsers();
      final settings = await _api.fetchSettings();
      
      setState(() {
        data = response;
        _weeklyStats = stats;
        _allUsers = users;
        if (settings.containsKey('low_attendance_threshold')) {
          _lowAttendanceThreshold = double.tryParse(settings['low_attendance_threshold'].toString()) ?? 75.0;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      await ReportService.generateAuditReport(
        allUsers: _allUsers,
        recentLogs: data.recentLogs,
        threshold: _lowAttendanceThreshold,
      );
      await HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report generation failed: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showThresholdSettings() {
    showDialog(
      context: context,
      builder: (context) {
        double tempThreshold = _lowAttendanceThreshold;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Anomaly Threshold', style: TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Flag students with attendance below ${tempThreshold.toInt()}%', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Slider(
                    value: tempThreshold,
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${tempThreshold.toInt()}%',
                    onChanged: (val) => setDialogState(() => tempThreshold = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    await _api.updateSettings({'low_attendance_threshold': tempThreshold.toString()});
                    if (mounted) {
                      setState(() => _lowAttendanceThreshold = tempThreshold);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Threshold updated successfully')));
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      final token = await NotificationService.getToken();
      if (token == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification system not initialized.')));
        return;
      }
      await _api.sendTestNotification(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test signal dispatched to this device! 📡'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return DashboardShell(
      title: '',
      subtitle: '',
      currentRoute: 'dashboard',
      username: widget.username,
      accentIcon: Icons.admin_panel_settings_rounded,
      hideHeader: true,
      hideBottomNav: true,
      child: Stack(
        children: [
          _isLoading
              ? const _ShimmerDashboard()
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: onSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Presence Intelligence',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: onSurface),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyAttendanceScreen())),
                            icon: Icon(Icons.calendar_month_rounded, color: onSurface),
                            tooltip: 'Monthly Log',
                          ),
                          IconButton(
                            onPressed: _showThresholdSettings,
                            icon: Icon(Icons.tune_rounded, color: onSurface),
                            tooltip: 'Analysis Threshold',
                          ),
                          IconButton(
                            onPressed: _sendTestNotification,
                            icon: Icon(Icons.notifications_active_outlined, color: onSurface),
                            tooltip: 'Test Push Notification',
                          ),
                          IconButton(
                            onPressed: _exportPdf,
                            icon: Icon(Icons.ios_share_rounded, color: onSurface, size: 22),
                            tooltip: 'Export Audit',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            Row(
                              children: [
                                Expanded(child: StatCard(title: "Students", value: '${data.totalStudents}', icon: Icons.school_rounded)),
                                const SizedBox(width: 16),
                                Expanded(child: StatCard(title: 'Teachers', value: '${data.totalTeachers}', icon: Icons.person_rounded)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: StatCard(title: "Admins", value: '${data.totalAdmins}', icon: Icons.admin_panel_settings_rounded)),
                                const SizedBox(width: 16),
                                Expanded(child: StatCard(title: 'Present Today', value: '${data.presentToday}', icon: Icons.verified_rounded)),
                              ],
                            ),
                            const SizedBox(height: 32),
                            const SectionLabel('Temporal Analytics'),
                            const SizedBox(height: 16),
                            CheckInChart(stats: _weeklyStats),
                            const SizedBox(height: 32),
                            const SectionLabel('Identity Feed'),
                            const SizedBox(height: 16),
                            LogsTableCard(title: '', logs: data.recentLogs, hideTitle: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          if (_isExporting) const _CinematicLoadingOverlay(),
        ],
      ),
    );
  }
}

class _CinematicLoadingOverlay extends StatefulWidget {
  const _CinematicLoadingOverlay();

  @override
  State<_CinematicLoadingOverlay> createState() => _CinematicLoadingOverlayState();
}

class _CinematicLoadingOverlayState extends State<_CinematicLoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Opacity(
                      opacity: 0.6 + (_pulseController.value * 0.4),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ASSEMBLING AUDIT REPORT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'SYCHRONIZING INTELLIGENCE ENGINE...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherDashboard extends StatefulWidget {
  final String username;
  const TeacherDashboard({super.key, required this.username});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _api = const AttendanceApiService();
  TeacherDashboardData data = TeacherDashboardData.empty();
  List<Map<String, dynamic>> _graphData = [];
  bool _isLoading = true;
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await _api.fetchTeacherDashboard();
      final notices = await _api.fetchNotices();
      if (mounted) {
        setState(() {
          data = response;
        });
        
        final stats = await _api.fetchWeeklyStats();
        if (mounted) setState(() => _graphData = stats);

        if (notices.isNotEmpty && !_noticeShown) {
          final prefs = await SharedPreferences.getInstance();
          final lastSeenId = prefs.getInt('last_notice_id') ?? 0;
          final newestId = notices.first.id;

          if (newestId > lastSeenId) {
            _noticeShown = true;
            await prefs.setInt('last_notice_id', newestId);
            if (mounted) {
              showDialog(
                context: context,
                builder: (_) => NoticePopup(notices: notices),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return DashboardShell(
      title: '',
      subtitle: '',
      currentRoute: 'teacher',
      username: widget.username,
      accentIcon: Icons.class_rounded,
      hideHeader: true,
      hideBottomNav: true,
      child: _isLoading
          ? const _ShimmerDashboard()
          : Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Faculty Workspace',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: onSurface),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen(title: 'Students', filterRole: 'student'))),
                      icon: Icon(Icons.people_alt_rounded, color: onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatCard(title: "Students", value: '${data.totalStudents}', icon: Icons.school_rounded)),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(title: "Today's Scans", value: '${data.todaysScans}', icon: Icons.verified_rounded)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const SectionLabel('Analytics Trend'),
                      const SizedBox(height: 16),
                      CheckInChart(stats: _graphData),
                      const SizedBox(height: 32),
                      const SectionLabel('Daily Activity Log'),
                      const SizedBox(height: 16),
                      LogsTableCard(title: "", logs: data.recentLogs, hideTitle: true),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key, required this.username});

  final String username;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _api = const AttendanceApiService();
  StudentDashboardData data = StudentDashboardData.empty();
  bool _isLoading = true;
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await _api.fetchStudentDashboard(widget.username);
      final notices = await _api.fetchNotices();
      if (mounted) {
        setState(() {
          data = response;
        });

        if (notices.isNotEmpty && !_noticeShown) {
          final prefs = await SharedPreferences.getInstance();
          final lastSeenId = prefs.getInt('last_notice_id') ?? 0;
          final newestId = notices.first.id;

          if (newestId > lastSeenId) {
            _noticeShown = true;
            await prefs.setInt('last_notice_id', newestId);
            if (mounted) {
              showDialog(
                context: context,
                builder: (_) => NoticePopup(notices: notices),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return DashboardShell(
      title: '',
      subtitle: '',
      currentRoute: 'student',
      username: widget.username,
      accentIcon: Icons.person_rounded,
      hideHeader: true,
      hideBottomNav: true,
      child: _isLoading
          ? const _ShimmerDashboard()
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: onSurface,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Presence Portfolio',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: onSurface),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceScanScreen())),
                        icon: Icon(Icons.camera_alt_rounded, color: onSurface, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: AttendanceGauge(percentage: data.attendancePercentage),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  StatCard(title: 'Verified', value: '${data.totalDaysPresent}', icon: Icons.check_circle_outline_rounded),
                                  const SizedBox(height: 12),
                                  StatCard(title: 'Academic Days', value: '${data.totalWorkingDays}', icon: Icons.calendar_month_rounded),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const SectionLabel('Intelligence Feed'),
                        const SizedBox(height: 16),
                        ConsistencyMatrix(
                          datasets: data.heatmap,
                        ),
                        const SizedBox(height: 32),
                        const SectionLabel('Activity History'),
                        const SizedBox(height: 16),
                        LogsTableCard(
                          title: '',
                          hideTitle: true,
                          logs: data.history
                              .map(
                                (item) => AttendanceLog(
                                  username: '',
                                  date: item.date,
                                  time: item.time,
                                  status: item.status,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ConsistencyMatrix extends StatelessWidget {
  const ConsistencyMatrix({super.key, required this.datasets});
  final Map<DateTime, int> datasets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_on_rounded, size: 18, color: onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('Consistency Matrix', style: TextStyle(fontWeight: FontWeight.w700, color: onSurface.withValues(alpha: 0.5), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 20),
          HeatMap(
            datasets: datasets,
            colorsets: {
              1: Colors.blueAccent.withValues(alpha: 0.8),
            },
            colorMode: ColorMode.color,
            defaultColor: onSurface.withValues(alpha: 0.05),
            textColor: onSurface,
            showColorTip: false,
            showText: false,
            scrollable: true,
            size: 28,
            onClick: (value) {
              if (value != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.toString().split(' ')[0])));
              }
            },
          ),
        ],
      ),
    );
  }
}

class SignOutScreen extends StatelessWidget {
  const SignOutScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      body: Stack(
        children: [
          const AnimatedDashboardBackground(),
          SafeArea(
            child: Center(
              child: GlassPanel(
                padding: const EdgeInsets.all(40),
                borderRadius: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, size: 80, color: onSurface.withValues(alpha: 0.8)),
                    const SizedBox(height: 32),
                    Text(
                      'Sign Out?',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: onSurface),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Are you sure you want to terminate your current session?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.6), height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton(
                        onPressed: () => logout(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('CONFIRM LOGOUT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: onSurface.withValues(alpha: 0.1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('GO BACK', style: TextStyle(color: onSurface, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerDashboard extends StatelessWidget {
  const _ShimmerDashboard();


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Shimmer.fromColors(
      baseColor: onSurface.withValues(alpha: 0.1),
      highlightColor: onSurface.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(children: [Container(width: 40, height: 40, color: Colors.white), const SizedBox(width: 12), Container(width: 150, height: 30, color: Colors.white)]),
          const SizedBox(height: 40),
          Row(children: [Container(width: 120, height: 120, color: Colors.white), const SizedBox(width: 20), Expanded(child: Container(height: 100, color: Colors.white))]),
          const SizedBox(height: 40),
          Container(width: double.infinity, height: 200, color: Colors.white),
        ],
      ),
    );
  }
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentRoute,
    required this.username,
    required this.accentIcon,
    required this.child,
    this.action,
    this.hideHeader = false,
    this.hideBottomNav = false,
  });

  final String title;
  final String subtitle;
  final String currentRoute;
  final String username;
  final IconData accentIcon;
  final Widget child;
  final Widget? action;
  final bool hideHeader;
  final bool hideBottomNav;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;
    final isPhone = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: (!isWide && !hideBottomNav)
          ? Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: onSurface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: onSurface.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (currentRoute == 'student')
                      _BottomNavIcon(
                        icon: Icons.camera_front_rounded,
                        label: 'Validate',
                        active: false,
                        color: surface,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceScanScreen())),
                      ),
                    if (currentRoute == 'teacher')
                      _BottomNavIcon(
                        icon: Icons.dashboard_rounded,
                        label: 'Command',
                        active: currentRoute == 'dashboard',
                        color: surface,
                        onTap: () {
                          // No-op or handle appropriately if needed
                        },
                      ),
                    if (currentRoute == 'teacher')
                      _BottomNavIcon(
                        icon: Icons.class_rounded,
                        label: 'Faculty',
                        active: currentRoute == 'teacher',
                        color: surface,
                        onTap: () {
                          if (currentRoute != 'teacher') {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TeacherDashboard(username: username)));
                          }
                        },
                      ),
                    _BottomNavIcon(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      active: false,
                      color: surface,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignOutScreen())),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          const AnimatedDashboardBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isPhone ? 20 : 24),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(width: 280, child: _Sidebar(currentRoute: currentRoute, username: username)),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DashboardHeader(
                                title: title,
                                subtitle: subtitle,
                                icon: accentIcon,
                                action: action,
                              ),
                              const SizedBox(height: 32),
                              Expanded(child: child),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        if (!hideHeader)
                          _DashboardHeader(
                            title: title,
                            subtitle: subtitle,
                            icon: accentIcon,
                            action: action,
                          ),
                        if (!hideHeader) const SizedBox(height: 32),
                        Expanded(child: child),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  const _BottomNavIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? color : color.withValues(alpha: 0.4),
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: active ? color : color.withValues(alpha: 0.4),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentRoute, required this.username});

  final String currentRoute;
  final String username;

  void _showPostNotice(BuildContext context, String username, String role) {
    showDialog(
      context: context,
      builder: (_) => PostNoticeDialog(
        authorName: username,
        authorRole: role,
        onPost: (content, category, push, email, sms) async {
          const api = AttendanceApiService();
          await api.postNotice(content, username, role, category: category, broadcastPush: push, broadcastEmail: email, broadcastSms: sms);
        },
      ),
    );
  }

  void _showAdminSettings(BuildContext context) async {
    const api = AttendanceApiService();
    final currentSettings = await api.fetchSettings();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        currentSettings: currentSettings,
        onSave: (newSettings) async {
          await api.updateSettings(newSettings);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.blur_on_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text('Mr. Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: onSurface)),
            ],
          ),
          const SizedBox(height: 40),
          _NavTile(
            icon: Icons.class_rounded,
            label: 'Faculty Workspace',
            active: currentRoute == 'teacher',
            onTap: () {
              if (currentRoute != 'teacher') {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TeacherDashboard(username: username)));
              }
            },
          ),
          _NavTile(
            icon: Icons.person_rounded,
            label: 'Student Portal',
            active: currentRoute == 'student',
            onTap: () {
              if (currentRoute != 'student') {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentDashboard(username: username)));
              }
            },
          ),
          const SizedBox(height: 16),
          const SectionLabel('Management'),
          const SizedBox(height: 8),
          if (currentRoute == 'teacher') ...[
            _NavTile(
              icon: Icons.person_add_rounded,
              label: 'Enroll User',
              active: false,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminRegisterScreen(fixedRole: 'student'))),
            ),
            _NavTile(
              icon: Icons.people_alt_rounded,
              label: 'Identity Registry',
              active: false,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen(
                title: 'Students',
                filterRole: 'student',
              ))),
            ),
          ],
          _NavTile(
            icon: Icons.campaign_rounded,
            label: 'Official Notices',
            active: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeScreen())),
          ),
          _NavTile(
            icon: Icons.calendar_month_rounded,
            label: 'Academic Calendar',
            active: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicCalendarScreen(isAdmin: false))),
          ),
          _NavTile(
            icon: Icons.account_circle_rounded,
            label: 'My Profile',
            active: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: username, role: currentRoute == 'teacher' ? 'teacher' : 'student'))),
          ),
          if (currentRoute == 'teacher') ...[
            const SizedBox(height: 12),
            _NavTile(
              icon: Icons.add_comment_outlined,
              label: 'Broadcast Notice',
              active: false,
              onTap: () => _showPostNotice(context, username, 'teacher'),
            ),
          ],
          const Spacer(),
          _NavTile(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            active: false,
            danger: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignOutScreen())),
          ),
        ],
      ),
    );
  }
}

class LogsTableCard extends StatelessWidget {
  const LogsTableCard({super.key, required this.title, required this.logs, this.hideTitle = false});

  final String title;
  final List<AttendanceLog> logs;
  final bool hideTitle;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final visibleLogs = logs.take(15).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideTitle)
          Row(
            children: [
              Icon(Icons.history_rounded, color: onSurface, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onSurface)),
            ],
          ),
        if (!hideTitle) const SizedBox(height: 18),
        if (logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text('No operational data recorded.', style: TextStyle(color: onSurface.withValues(alpha: 0.4)))),
          )
        else
          ...visibleLogs.map((log) => _LogDataRow(log: log)),
      ],
    );
  }
}

class _LogDataRow extends StatelessWidget {
  const _LogDataRow({required this.log});

  final AttendanceLog log;

  void _showProof(BuildContext context) {
    if (log.proofUrl == null) return;
    
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Validation Evidence', style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                '${const AttendanceApiService().baseUrl}${log.proofUrl}',
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 100),
              ),
            ),
            const SizedBox(height: 16),
            Text('Validated at: ${log.time}', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: theme.colorScheme.onSurface))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final status = log.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: log.proofUrl != null ? () => _showProof(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.username.isNotEmpty)
                      Text(
                        log.username,
                        style: TextStyle(fontWeight: FontWeight.w800, color: onSurface, fontSize: 15),
                      ),
                    Text(
                      '${log.date} • ${log.time}',
                      style: TextStyle(color: onSurface.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (log.proofUrl != null)
                Icon(Icons.image_outlined, size: 18, color: onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: onSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: theme.colorScheme.surface, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final baseColor = danger ? Colors.redAccent : onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? onSurface : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: active ? theme.colorScheme.surface : baseColor, size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: active ? theme.colorScheme.surface : baseColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
