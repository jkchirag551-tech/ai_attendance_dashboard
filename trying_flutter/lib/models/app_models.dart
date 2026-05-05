class LoginResult {
  const LoginResult({
    required this.role,
    required this.username,
  });

  final String role;
  final String username;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      role: json['role']?.toString() ?? 'student',
      username: json['username']?.toString() ?? '',
    );
  }
}

class ScanResult {
  const ScanResult({required this.message});

  final String message;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(message: json['message']?.toString() ?? 'Scan complete');
  }
}

class AttendanceLog {
  const AttendanceLog({
    required this.username,
    required this.date,
    required this.time,
    required this.status,
    this.matchScore,
    this.proofUrl,
  });

  final String username;
  final String date;
  final String time;
  final String status;
  final String? matchScore;
  final String? proofUrl;

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      username: json['username']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Verified',
      matchScore: json['match_score']?.toString(),
      proofUrl: json['proof_url']?.toString(),
    );
  }
}

class StudentHistoryLog {
  const StudentHistoryLog({
    required this.date,
    required this.time,
    required this.status,
  });

  final String date;
  final String time;
  final String status;

  factory StudentHistoryLog.fromJson(Map<String, dynamic> json) {
    return StudentHistoryLog(
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Verified',
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalAdmins,
    required this.presentToday,
    required this.recentLogs,
  });

  final int totalStudents;
  final int totalTeachers;
  final int totalAdmins;
  final int presentToday;
  final List<AttendanceLog> recentLogs;

  factory AdminDashboardData.empty() {
    return const AdminDashboardData(
      totalStudents: 0,
      totalTeachers: 0,
      totalAdmins: 0,
      presentToday: 0,
      recentLogs: [],
    );
  }

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final rawLogs = (json['recent_logs'] ?? json['records'] ?? []) as List<dynamic>;
    return AdminDashboardData(
      totalStudents: _asInt(json['total_students']),
      totalTeachers: _asInt(json['total_teachers']),
      totalAdmins: _asInt(json['total_admins']),
      presentToday: _asInt(json['present_today']),
      recentLogs: rawLogs
          .map((item) => AttendanceLog.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class TeacherDashboardData {
  const TeacherDashboardData({
    required this.totalStudents,
    required this.todaysScans,
    required this.recentLogs,
  });

  final int totalStudents;
  final int todaysScans;
  final List<AttendanceLog> recentLogs;

  factory TeacherDashboardData.empty() {
    return const TeacherDashboardData(totalStudents: 0, todaysScans: 0, recentLogs: []);
  }

  factory TeacherDashboardData.fromJson(Map<String, dynamic> json) {
    final rawLogs = (json['recent_logs'] ?? []) as List<dynamic>;
    return TeacherDashboardData(
      totalStudents: _asInt(json['total_students']),
      todaysScans: _asInt(json['todays_scans']),
      recentLogs: rawLogs
          .map((item) => AttendanceLog.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.totalDaysPresent,
    required this.totalWorkingDays,
    required this.attendancePercentage,
    required this.semesterStart,
    required this.semesterEnd,
    required this.history,
    required this.heatmap,
  });

  final int totalDaysPresent;
  final int totalWorkingDays;
  final double attendancePercentage;
  final String semesterStart;
  final String semesterEnd;
  final List<StudentHistoryLog> history;
  final Map<DateTime, int> heatmap;

  factory StudentDashboardData.empty() {
    return const StudentDashboardData(
      totalDaysPresent: 0,
      totalWorkingDays: 0,
      attendancePercentage: 0.0,
      semesterStart: '',
      semesterEnd: '',
      history: [],
      heatmap: {},
    );
  }

  factory StudentDashboardData.fromJson(Map<String, dynamic> json) {
    final rawHistory = (json['history'] ?? []) as List<dynamic>;
    final rawHeatmap = (json['heatmap'] ?? {}) as Map<String, dynamic>;
    
    Map<DateTime, int> parsedHeatmap = {};
    rawHeatmap.forEach((key, value) {
      try {
        parsedHeatmap[DateTime.parse(key)] = (value as num).toInt();
      } catch (_) {}
    });

    return StudentDashboardData(
      totalDaysPresent: _asInt(json['total_days_present']),
      totalWorkingDays: _asInt(json['total_working_days']),
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      semesterStart: json['semester_start']?.toString() ?? '',
      semesterEnd: json['semester_end']?.toString() ?? '',
      history: rawHistory
          .map((item) => StudentHistoryLog.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      heatmap: parsedHeatmap,
    );
  }
}

class Notice {
  const Notice({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.content,
    required this.category,
    required this.createdAt,
  });

  final int id;
  final String authorName;
  final String authorRole;
  final String content;
  final String category;
  final String createdAt;

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as int? ?? 0,
      authorName: json['author_name']?.toString() ?? 'System',
      authorRole: json['author_role']?.toString() ?? 'admin',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Info',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullname,
    required this.username,
    required this.userid,
    required this.role,
    required this.attendancePercentage,
    this.email,
    this.phone,
  });

  final int id;
  final String fullname;
  final String username;
  final String userid;
  final String role;
  final double attendancePercentage;
  final String? email;
  final String? phone;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int? ?? 0,
      fullname: json['fullname']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      userid: json['userid']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.type,
  });

  final int id;
  final String date;
  final String title;
  final String type; // 'holiday' or 'working'

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as int? ?? 0,
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'holiday',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
