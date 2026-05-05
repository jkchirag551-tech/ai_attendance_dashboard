import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../services/attendance_api_service.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/dialog_widgets.dart';
import 'admin_management_screens.dart';
import 'dashboard_screens.dart';
import 'notice_screen.dart';
import 'profile_screen.dart';
import 'face_scan_screen.dart';
import 'calendar_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final String username;
  final String role;

  const WelcomeScreen({super.key, required this.username, required this.role});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _navigateToDashboard() {
    Widget dashboard;
    if (widget.role == 'teacher') {
      dashboard = TeacherDashboard(username: widget.username);
    } else {
      dashboard = StudentDashboard(username: widget.username);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => dashboard));
  }

  void _showMoreMenu() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final appState = Provider.of<AppState>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 32),
              _MoreMenuItem(icon: Icons.person_outline_rounded, label: 'Account Profile', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: widget.username, role: widget.role))); }),
              _MoreMenuItem(icon: appState.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, label: appState.isDarkMode ? 'Appearance: Light' : 'Appearance: Midnight', onTap: () { Navigator.pop(context); appState.toggleTheme(); }),
              _MoreMenuItem(icon: Icons.campaign_outlined, label: 'Official Notices', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeScreen())); }),
              _MoreMenuItem(icon: Icons.calendar_month_outlined, label: 'Academic Calendar', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => AcademicCalendarScreen(isAdmin: false))); }),
              if (widget.role == 'teacher') ...[
                _MoreMenuItem(icon: Icons.add_comment_outlined, label: 'Broadcast Notice', onTap: () { Navigator.pop(context); _showPostNotice(); }),
              ],
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: theme.dividerColor, height: 1)),
              _MoreMenuItem(icon: Icons.logout_rounded, label: 'Sign Out', danger: true, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SignOutScreen())); }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminSettings() async {
    const api = AttendanceApiService();
    final currentSettings = await api.fetchSettings();
    if (!mounted) return;
    showDialog(context: context, builder: (_) => SettingsDialog(currentSettings: currentSettings, onSave: (newSettings) async { await api.updateSettings(newSettings); }));
  }

  void _showPostNotice() {
    showDialog(
      context: context,
      builder: (_) => PostNoticeDialog(
        authorName: widget.username,
        authorRole: widget.role,
        onPost: (content, category, push, email, sms) async {
          const api = AttendanceApiService();
          await api.postNotice(content, widget.username, widget.role, category: category, broadcastPush: push, broadcastEmail: email, broadcastSms: sms);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: (!isWide)
          ? Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: onSurface, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: onSurface.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: _buildNavItems(context, widget.role, surface)),
              ),
            )
          : null,
      body: Stack(
        children: [
          const AnimatedDashboardBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.blur_on_rounded, size: 24, color: Colors.white)
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Mr. Attendance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: onSurface, letterSpacing: 0.5)),
                          ],
                        ),
                        if (isWide) IconButton(onPressed: _navigateToDashboard, icon: Icon(Icons.grid_view_rounded, color: onSurface, size: 24)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('MR.\nTECHLAB', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0, color: onSurface, letterSpacing: -2.0)),
                  const SizedBox(height: 24),
                  Text('We design intelligent digital solutions — from powerful websites and mobile apps to advanced software systems that help businesses grow faster in the modern world.', style: TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.6), height: 1.6, fontWeight: FontWeight.w500)),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context, String role, Color iconColor) {
    if (role == 'teacher') {
      return [
        _WelcomeNavIcon(icon: Icons.person_add_rounded, label: 'Enroll', color: iconColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRegisterScreen(fixedRole: 'student')))),
        _WelcomeNavIcon(icon: Icons.people_alt_rounded, label: 'Governance', color: iconColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen(title: 'Students', filterRole: 'student')))),
        _WelcomeNavIcon(icon: Icons.history_rounded, label: 'Activity', color: iconColor, onTap: _navigateToDashboard),
        _WelcomeNavIcon(icon: Icons.more_horiz_rounded, label: 'More', color: iconColor, onTap: _showMoreMenu),
      ];
    } else {
      return [
        _WelcomeNavIcon(icon: Icons.camera_front_rounded, label: 'Validate', color: iconColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceScanScreen()))),
        _WelcomeNavIcon(icon: Icons.history_rounded, label: 'Records', color: iconColor, onTap: _navigateToDashboard),
        _WelcomeNavIcon(icon: Icons.more_horiz_rounded, label: 'More', color: iconColor, onTap: _showMoreMenu),
      ];
    }
  }
}

class _MoreMenuItem extends StatelessWidget {
  const _MoreMenuItem({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final color = danger ? Colors.redAccent : onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: onSurface.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.2), size: 14),
          ],
        ),
      ),
    );
  }
}

class _WelcomeNavIcon extends StatelessWidget {
  const _WelcomeNavIcon({required this.icon, required this.label, required this.onTap, required this.color});
  final IconData icon;
  final String label;
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.7), letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
