import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/attendance_api_service.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/shared_widgets.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final _api = const AttendanceApiService();
  List<Notice> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    try {
      final notices = await _api.fetchNotices();
      setState(() {
        _notices = notices;
        _isLoading = false;
      });
    } catch (_) {
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
                        'Notices',
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
                            child: ListView(
                              children: [
                                NoticeBoard(notices: _notices, onRefresh: _loadNotices),
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
