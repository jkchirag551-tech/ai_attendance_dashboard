import 'package:flutter/material.dart';
import '../widgets/shared_widgets.dart';

class PostNoticeDialog extends StatefulWidget {
  const PostNoticeDialog({
    super.key,
    required this.authorName,
    required this.authorRole,
    required this.onPost,
  });

  final String authorName;
  final String authorRole;
  final Function(String, String, bool, bool) onPost;

  @override
  State<PostNoticeDialog> createState() => _PostNoticeDialogState();
}

class _PostNoticeDialogState extends State<PostNoticeDialog> {
  final _controller = TextEditingController();
  String _selectedCategory = 'Info';
  bool _isPosting = false;
  bool _broadcastEmail = false;
  bool _broadcastSms = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text('Post New Notice', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Category'),
            const SizedBox(height: 8),
            Container(
              decoration: inputDecoration(onSurface),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: theme.cardColor,
                  iconEnabledColor: onSurface,
                  style: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'Info', child: Text('Information')),
                    DropdownMenuItem(value: 'Urgent', child: Text('Urgent Action')),
                    DropdownMenuItem(value: 'Event', child: Text('Upcoming Event')),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const SectionLabel('Notice Content'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 4,
              style: TextStyle(color: onSurface),
              decoration: fieldDecoration(onSurface: onSurface, hintText: 'Type notice content...', prefixIcon: Icons.edit_note_rounded),
            ),
            const SizedBox(height: 18),
            const SectionLabel('Broadcast options'),
            CheckboxListTile(
              title: Text('Send via Email', style: TextStyle(color: onSurface, fontSize: 14)),
              value: _broadcastEmail,
              onChanged: (v) => setState(() => _broadcastEmail = v!),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: onSurface,
              checkColor: theme.colorScheme.surface,
            ),
            CheckboxListTile(
              title: Text('Send via SMS', style: TextStyle(color: onSurface, fontSize: 14)),
              value: _broadcastSms,
              onChanged: (v) => setState(() => _broadcastSms = v!),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: onSurface,
              checkColor: theme.colorScheme.surface,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: onSurface.withValues(alpha: 0.6)))),
        FilledButton(
          onPressed: _isPosting
              ? null
              : () async {
                  if (_controller.text.trim().isEmpty) return;
                  setState(() => _isPosting = true);
                  await widget.onPost(_controller.text.trim(), _selectedCategory, _broadcastEmail, _broadcastSms);
                  if (context.mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(backgroundColor: onSurface, foregroundColor: theme.colorScheme.surface),
          child: _isPosting ? CircularProgressIndicator(color: theme.colorScheme.surface) : const Text('Post Notice'),
        ),
      ],
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.currentSettings, required this.onSave});
  final Map<String, dynamic> currentSettings;
  final Function(Map<String, dynamic>) onSave;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _startTime;
  late TextEditingController _endTime;
  late TextEditingController _startDate;
  late TextEditingController _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startTime = TextEditingController(text: widget.currentSettings['working_day_start_time']?.toString() ?? '09:00');
    _endTime = TextEditingController(text: widget.currentSettings['working_day_end_time']?.toString() ?? '17:00');
    _startDate = TextEditingController(text: widget.currentSettings['semester_start_date']?.toString() ?? '2026-01-15');
    _endDate = TextEditingController(text: widget.currentSettings['semester_end_date']?.toString() ?? '2026-06-20');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text('System Settings', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Day Start Time'),
            const SizedBox(height: 8),
            TextField(
              controller: _startTime, 
              style: TextStyle(color: onSurface),
              decoration: fieldDecoration(onSurface: onSurface, hintText: '09:00', prefixIcon: Icons.access_time_rounded)
            ),
            const SizedBox(height: 16),
            const SectionLabel('Day End Time'),
            const SizedBox(height: 8),
            TextField(
              controller: _endTime, 
              style: TextStyle(color: onSurface),
              decoration: fieldDecoration(onSurface: onSurface, hintText: '17:00', prefixIcon: Icons.access_time_filled_rounded)
            ),
            const SizedBox(height: 16),
            const SectionLabel('Semester Start'),
            const SizedBox(height: 8),
            TextField(
              controller: _startDate, 
              style: TextStyle(color: onSurface),
              decoration: fieldDecoration(onSurface: onSurface, hintText: 'YYYY-MM-DD', prefixIcon: Icons.calendar_today_rounded)
            ),
            const SizedBox(height: 16),
            const SectionLabel('Semester End'),
            const SizedBox(height: 8),
            TextField(
              controller: _endDate, 
              style: TextStyle(color: onSurface),
              decoration: fieldDecoration(onSurface: onSurface, hintText: 'YYYY-MM-DD', prefixIcon: Icons.calendar_month_rounded)
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: onSurface.withValues(alpha: 0.6)))),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  await widget.onSave({
                    'working_day_start_time': _startTime.text,
                    'working_day_end_time': _endTime.text,
                    'semester_start_date': _startDate.text,
                    'semester_end_date': _endDate.text,
                  });
                  if (context.mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(backgroundColor: onSurface, foregroundColor: theme.colorScheme.surface),
          child: _isSaving ? CircularProgressIndicator(color: theme.colorScheme.surface) : const Text('Save Changes'),
        ),
      ],
    );
  }
}
