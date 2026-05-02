import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/app_models.dart';
import 'shared_widgets.dart';

class CheckInChart extends StatelessWidget {
  const CheckInChart({super.key, required this.stats});
  final List<Map<String, dynamic>> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    
    return AspectRatio(
      aspectRatio: 1.7,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        borderRadius: 24,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                    final dateStr = stats[index]['date'] as String;
                    final day = dateStr.split('-').last;
                    return Text(day, style: TextStyle(color: onSurface.withValues(alpha: 0.4), fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(stats.length, (i) => FlSpot(i.toDouble(), (stats[i]['count'] as num).toDouble())),
                isCurved: true,
                color: onSurface,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceGauge extends StatelessWidget {
  const AttendanceGauge({super.key, required this.percentage});
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final color = percentage >= 75 ? Colors.green : (percentage >= 60 ? Colors.orange : Colors.red);
    
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: double.infinity,
              sections: [
                PieChartSectionData(
                  color: color,
                  value: percentage,
                  radius: 12,
                  showTitle: false,
                ),
                PieChartSectionData(
                  color: onSurface.withValues(alpha: 0.05),
                  value: 100 - percentage,
                  radius: 10,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: onSurface)),
                Text('Attendance', style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoticeBoard extends StatelessWidget {
  const NoticeBoard({super.key, required this.notices, this.onRefresh});

  final List<Notice> notices;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded, color: onSurface),
                const SizedBox(width: 10),
                Text('Notice Board', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: onSurface)),
              ],
            ),
            if (onRefresh != null)
              IconButton(onPressed: onRefresh, icon: Icon(Icons.refresh_rounded, size: 20, color: onSurface)),
          ],
        ),
        const SizedBox(height: 16),
        if (notices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(child: Text('No notices posted yet.', style: TextStyle(color: onSurface.withValues(alpha: 0.4)))),
          )
        else
          ...notices.map((n) => _NoticeItem(notice: n)),
      ],
    );
  }
}

class NoticePopup extends StatelessWidget {
  const NoticePopup({super.key, required this.notices});
  final List<Notice> notices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(Icons.campaign_rounded, color: onSurface, size: 28),
          const SizedBox(width: 12),
          Text('New Notices', style: TextStyle(fontWeight: FontWeight.w900, color: onSurface)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notices.length,
            itemBuilder: (context, index) => _NoticeItem(notice: notices[index]),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isUrgent = notice.category.toLowerCase() == 'urgent';
    final isEvent = notice.category.toLowerCase() == 'event';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.withValues(alpha: 0.05) : onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUrgent ? Colors.red.withValues(alpha: 0.2) : onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isUrgent) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                  if (isEvent) Icon(Icons.calendar_today_rounded, color: onSurface, size: 16),
                  if (isUrgent || isEvent) const SizedBox(width: 8),
                  Text(
                    notice.authorName,
                    style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              Text(
                notice.createdAt,
                style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          if (notice.category != 'Info') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: onSurface, borderRadius: BorderRadius.circular(4)),
              child: Text(notice.category.toUpperCase(), style: TextStyle(color: theme.colorScheme.surface, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ],
          const SizedBox(height: 8),
          Text(notice.content, style: TextStyle(height: 1.5, color: onSurface.withValues(alpha: 0.87))),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon, this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final accent = color ?? onSurface;

    return SizedBox(
      width: isPhone ? (screenWidth - 48).clamp(0, 600).toDouble() : 250,
      child: GlassPanel(
        padding: EdgeInsets.all(isPhone ? 16 : 20),
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isPhone ? 8 : 10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(value, style: TextStyle(fontSize: isPhone ? 28 : 34, fontWeight: FontWeight.w800, color: onSurface)),
          ],
        ),
      ),
    );
  }
}
