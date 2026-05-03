import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/attendance_api_service.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/video_background.dart';
import '../services/notification_service.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = const AttendanceApiService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedRole = 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _checkPersistence();
  }

  Future<void> _checkPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');
    final savedRole = prefs.getString('saved_role');

    if (savedUsername != null && savedPassword != null) {
      _usernameController.text = savedUsername;
      _passwordController.text = savedPassword;
      setState(() {
        _selectedRole = savedRole ?? 'student';
        _rememberMe = true;
      });
      final wasLoggedOut = prefs.getBool('was_logged_out') ?? false;
      if (!wasLoggedOut) {
        _login();
      } else {
        await prefs.setBool('was_logged_out', false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final result = await _api.login(role: _selectedRole, username: _usernameController.text.trim(), password: _passwordController.text);
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_username', _usernameController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setString('saved_role', _selectedRole);
      } else {
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
        await prefs.remove('saved_role');
      }
      if (!mounted) return;
      // Sync FCM Token for notifications
      NotificationService.updateToken(result.username.isEmpty ? _usernameController.text.trim() : result.username);

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => WelcomeScreen(username: result.username.isEmpty ? _usernameController.text.trim() : result.username, role: result.role)));
    } on AttendanceApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Authentication server unreachable.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const VideoBackground(
            videoPath: 'assets/videos/moon.mp4',
            opacity: 0.5,
          ),
          const AnimatedDashboardBackground(),
          SafeArea(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: isWide
                        ? Row(
                            children: [
                              const Expanded(child: _LoginHeroPanel()),
                              const SizedBox(width: 48),
                              Expanded(child: Align(alignment: Alignment.centerLeft, child: _LoginCard(formKey: _formKey, usernameController: _usernameController, passwordController: _passwordController, selectedRole: _selectedRole, obscurePassword: _obscurePassword, isLoading: _isLoading, rememberMe: _rememberMe, errorMessage: _errorMessage, onRoleChanged: (v) => setState(() => _selectedRole = v), onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword), onRememberMeChanged: (v) => setState(() => _rememberMe = v!), onSubmit: _login))),
                            ],
                          )
                        : Center(child: _LoginCard(formKey: _formKey, usernameController: _usernameController, passwordController: _passwordController, selectedRole: _selectedRole, obscurePassword: _obscurePassword, isLoading: _isLoading, rememberMe: _rememberMe, errorMessage: _errorMessage, onRoleChanged: (v) => setState(() => _selectedRole = v), onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword), onRememberMeChanged: (v) => setState(() => _rememberMe = v!), onSubmit: _login)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(999), border: Border.all(color: onSurface.withValues(alpha: 0.05))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: Image.asset(
                  'assets/images/logo.png', 
                  width: 32, 
                  height: 32, 
                  fit: BoxFit.contain, 
                  errorBuilder: (_, __, ___) => const Icon(Icons.blur_on_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Text('Mr. Attendance', style: TextStyle(fontWeight: FontWeight.w700, color: onSurface)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('MR. TECH-LAB', style: TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w900, color: onSurface, letterSpacing: -1.5)),
        const SizedBox(height: 16),
        Text('We design intelligent digital solutions — from powerful websites and mobile apps to advanced software systems that help businesses grow faster in the modern world.', style: TextStyle(color: onSurface.withValues(alpha: 0.6), fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)),
        const SizedBox(height: 28),
        const Wrap(spacing: 14, runSpacing: 14, children: [FeatureChip(icon: Icons.auto_graph_rounded, label: 'Enterprise Analytics'), FeatureChip(icon: Icons.verified_user_rounded, label: 'Neural Verification'), FeatureChip(icon: Icons.calendar_month_rounded, label: 'Governed Workflow')]),
        if (kIsWeb) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('/static/app-release.apk'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.android_rounded, size: 20),
            label: const Text('DOWNLOAD MOBILE APP (APK)', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
            style: OutlinedButton.styleFrom(
              foregroundColor: onSurface,
              side: BorderSide(color: onSurface.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.formKey, required this.usernameController, required this.passwordController, required this.selectedRole, required this.obscurePassword, required this.isLoading, required this.rememberMe, required this.errorMessage, required this.onRoleChanged, required this.onTogglePassword, required this.onRememberMeChanged, required this.onSubmit});
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String selectedRole;
  final bool obscurePassword;
  final bool isLoading;
  final bool rememberMe;
  final String errorMessage;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: GlassPanel(
        padding: const EdgeInsets.all(28),
        borderRadius: 24,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          onSurface.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black, 
                      shape: BoxShape.circle, 
                      border: Border.all(color: onSurface.withValues(alpha: 0.1), width: 1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.blur_on_rounded, color: onSurface, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text('Portal Access', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: onSurface)), 
                        const SizedBox(height: 4), 
                        Text('Authenticate to your workspace', style: TextStyle(color: onSurface.withValues(alpha: 0.54), fontSize: 13))
                      ]
                    )
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const SectionLabel('Identity Type'),
              const SizedBox(height: 8),
              Container(
                decoration: inputDecoration(onSurface),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    iconEnabledColor: onSurface,
                    style: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'teacher', child: Text('Faculty')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrator'))
                    ],
                    onChanged: (value) { if (value != null) onRoleChanged(value); },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SectionLabel('Username'),
              const SizedBox(height: 8),
              TextFormField(
                controller: usernameController, 
                style: TextStyle(color: onSurface), 
                validator: (value) => value == null || value.trim().isEmpty ? 'Identifier required' : null, 
                decoration: fieldDecoration(onSurface: onSurface, hintText: 'Enter account username', prefixIcon: Icons.person_outline_rounded)
              ),
              const SizedBox(height: 20),
              const SectionLabel('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController, 
                obscureText: obscurePassword, 
                style: TextStyle(color: onSurface), 
                validator: (value) => value == null || value.isEmpty ? 'Credential required' : null, 
                decoration: fieldDecoration(
                  onSurface: onSurface, 
                  hintText: 'Enter account password', 
                  prefixIcon: Icons.lock_outline_rounded, 
                  suffix: IconButton(
                    onPressed: onTogglePassword, 
                    icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: onSurface.withValues(alpha: 0.54))
                  )
                )
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    height: 24, 
                    width: 24, 
                    child: Checkbox(
                      value: rememberMe, 
                      onChanged: onRememberMeChanged, 
                      activeColor: onSurface, 
                      checkColor: theme.colorScheme.surface, 
                      side: BorderSide(color: onSurface, width: 1.5)
                    )
                  ),
                  const SizedBox(width: 8),
                  Text('Maintain session', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onSurface.withValues(alpha: 0.87))),
                ]
              ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
                  child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13))
                )
              ],
              const SizedBox(height: 40),
              SizedBox(
                height: 56, 
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onSubmit, 
                  style: FilledButton.styleFrom(
                    backgroundColor: onSurface, 
                    foregroundColor: theme.colorScheme.surface, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ), 
                  icon: isLoading 
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.surface)) 
                    : const Icon(Icons.login_rounded), 
                  label: Text(isLoading ? 'Authenticating...' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
