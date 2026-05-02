import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';

class ReportService {
  static Future<void> generateAuditReport({
    required List<AppUser> allUsers,
    required List<AttendanceLog> recentLogs,
    double threshold = 75.0,
  }) async {
    final pdf = pw.Document();

    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

    final anomalies = allUsers.where((u) => u.role == 'student' && u.attendancePercentage < threshold).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header with Logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PRESENCE AUDIT REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Generated on ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                height: 50,
                width: 50,
                child: pw.Image(logoImage),
              ),
            ],
          ),
          pw.Divider(thickness: 2, color: PdfColors.blueGrey900),
          pw.SizedBox(height: 24),

          // Summary Stats
          pw.Text('INSTITUTIONAL SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Total Users', allUsers.length.toString()),
              _buildStat('Students', allUsers.where((u) => u.role == 'student').length.toString()),
              _buildStat('Anomalies (<${threshold.toInt()}%)', anomalies.length.toString()),
            ],
          ),
          pw.SizedBox(height: 32),

          // Anomalies Section
          if (anomalies.isNotEmpty) ...[
            pw.Text('ATTENDANCE ANOMALIES (Below ${threshold.toInt()}%)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Name', 'ID', 'Percentage'],
              data: anomalies.map((u) => [u.fullname, u.userid, '${u.attendancePercentage}%']).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              },
            ),
            pw.SizedBox(height: 32),
          ],

          // Recent Activity
          pw.Text('RECENT IDENTITY FEED', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['User', 'Date', 'Time', 'Status'],
            data: recentLogs.take(15).map((l) => [l.username, l.date, l.time, l.status]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
          ),
          
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Text('PRODUCED BY MR. TECH-LAB INTELLIGENCE ENGINE', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, letterSpacing: 2)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
        pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }
}
