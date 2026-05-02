import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/attendance_api_service.dart';
import '../widgets/shared_widgets.dart';

class AcademicCalendarScreen extends StatefulWidget {
  final bool isAdmin;

  const AcademicCalendarScreen({super.key, this.isAdmin = false});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  final _api = const AttendanceApiService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _api.fetchCalendarEvents();
      setState(() {
        _allEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return _allEvents.where((e) => e.date == dateStr).toList();
  }

  void _showAddEventDialog(DateTime day) {
    if (!widget.isAdmin) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final existing = _getEventsForDay(day);
    
    final titleController = TextEditingController(text: existing.isNotEmpty ? existing.first.title : '');
    String type = existing.isNotEmpty ? existing.first.type : 'holiday';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Edit Day: $dateStr', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: fieldDecoration(onSurface: Theme.of(context).colorScheme.onSurface, hintText: 'Reason (e.g. Diwali Holiday)', prefixIcon: Icons.edit_rounded),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Holiday', style: TextStyle(fontSize: 12)),
                      value: 'holiday',
                      groupValue: type,
                      onChanged: (v) => setDialogState(() => type = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Working', style: TextStyle(fontSize: 12)),
                      value: 'working',
                      groupValue: type,
                      onChanged: (v) => setDialogState(() => type = v!),
                    ),
                  ),
                ],
              ),
              if (existing.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    await _api.deleteCalendarEvent(existing.first.id);
                    await _loadEvents();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  label: const Text('Remove Event', style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await _api.saveCalendarEvent(dateStr, titleController.text.trim(), type);
                await _loadEvents();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface)),
                      const SizedBox(width: 8),
                      Text('Academic Calendar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: onSurface)),
                      const Spacer(),
                      if (widget.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('EDIT MODE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : GlassPanel(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 28,
                        child: Column(
                          children: [
                            TableCalendar(
                              firstDay: DateTime.utc(2025, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                                if (widget.isAdmin) {
                                  _showAddEventDialog(selectedDay);
                                }
                              },
                              onFormatChanged: (format) {
                                setState(() => _calendarFormat = format);
                              },
                              eventLoader: _getEventsForDay,
                              calendarStyle: CalendarStyle(
                                todayDecoration: BoxDecoration(color: onSurface.withValues(alpha: 0.1), shape: BoxShape.circle),
                                selectedDecoration: BoxDecoration(color: onSurface, shape: BoxShape.circle),
                                markerDecoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: onSurface),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, events) {
                                  if (events.isEmpty) return null;
                                  final ev = events.first as CalendarEvent;
                                  return Positioned(
                                    bottom: 1,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: ev.type == 'holiday' ? Colors.redAccent : Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            if (_selectedDay != null) ...[
                              SectionLabel('Events for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}'),
                              const SizedBox(height: 12),
                              if (_getEventsForDay(_selectedDay!).isEmpty)
                                const Text('Normal Working Day', style: TextStyle(color: Colors.grey))
                              else
                                ..._getEventsForDay(_selectedDay!).map((e) => Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: (e.type == 'holiday' ? Colors.redAccent : Colors.green).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(e.type == 'holiday' ? Icons.beach_access_rounded : Icons.work_rounded, color: e.type == 'holiday' ? Colors.redAccent : Colors.green),
                                      const SizedBox(width: 16),
                                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                )),
                            ] else
                              const Center(child: Text('Select a day to see details')),
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
