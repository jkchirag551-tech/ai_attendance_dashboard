import 'package:flutter/material.dart';
import '../services/attendance_api_service.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.username, required this.role});
  final String username;
  final String role;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = const AttendanceApiService();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  bool _isUpdating = false;

  Future<void> _changePassword() async {
    if (_oldPassController.text.isEmpty || _newPassController.text.isEmpty) return;
    setState(() => _isUpdating = true);
    try {
      await _api.changePassword(widget.username, _oldPassController.text, _newPassController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!')));
        _oldPassController.clear();
        _newPassController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
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
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface)),
                      const SizedBox(width: 8),
                      Text('My Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: onSurface)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  CircleAvatar(radius: 50, backgroundColor: onSurface.withValues(alpha: 0.1), child: Icon(Icons.person_rounded, size: 50, color: onSurface)),
                  const SizedBox(height: 16),
                  Text(widget.username, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: onSurface)),
                  Text(widget.role.toUpperCase(), style: TextStyle(color: onSurface.withValues(alpha: 0.54), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 40),
                  GlassPanel(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionLabel('Security Settings'),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _oldPassController, 
                          obscureText: true, 
                          style: TextStyle(color: onSurface),
                          decoration: fieldDecoration(onSurface: onSurface, hintText: 'Current Password', prefixIcon: Icons.lock_outline)
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _newPassController, 
                          obscureText: true, 
                          style: TextStyle(color: onSurface),
                          decoration: fieldDecoration(onSurface: onSurface, hintText: 'New Password', prefixIcon: Icons.lock_reset_rounded)
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isUpdating ? null : _changePassword,
                          style: FilledButton.styleFrom(backgroundColor: onSurface, foregroundColor: theme.colorScheme.surface),
                          child: _isUpdating ? CircularProgressIndicator(color: theme.colorScheme.surface) : const Text('Update Password'),
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
