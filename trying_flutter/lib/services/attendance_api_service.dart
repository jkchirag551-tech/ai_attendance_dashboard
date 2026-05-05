import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart' as config;
import '../models/app_models.dart';

class AttendanceApiService {
  const AttendanceApiService();

  String get baseUrl => config.baseUrl;

  Future<void> saveFcmToken(String username, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/fcm_token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'token': token}),
    );
    if (response.statusCode != 200) {
      throw const AttendanceApiException('Failed to save notification token.');
    }
  }

  Future<void> signup({
    required String fullname,
    required String userid,
    required String username,
    required String password,
    required String email,
    required String phone,
    required String base64Image,
    String? fcmToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullname': fullname,
        'userid': userid,
        'username': username,
        'password': password,
        'email': email,
        'phone': phone,
        'image': base64Image,
        'fcm_token': fcmToken,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw AttendanceApiException(body['message'] ?? 'Signup failed.');
    }
  }

  Future<void> sendTestNotification(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/test_notification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );
    if (response.statusCode != 200) {
      throw const AttendanceApiException('Failed to send test notification.');
    }
  }

  Future<LoginResult> login({
    required String role,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role,
        'username': username,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw AttendanceApiException(body['message']?.toString() ?? 'Invalid credentials.');
    }

    return LoginResult.fromJson(body);
  }

  Future<AdminDashboardData> fetchAdminDashboard() async {
    return AdminDashboardData.fromJson(await _getJson('$baseUrl/api/dashboard/admin'));
  }

  Future<TeacherDashboardData> fetchTeacherDashboard() async {
    return TeacherDashboardData.fromJson(await _getJson('$baseUrl/api/dashboard/teacher'));
  }

  Future<StudentDashboardData> fetchStudentDashboard(String username) async {
    return StudentDashboardData.fromJson(
      await _getJson('$baseUrl/api/dashboard/student/$username'),
    );
  }

  Future<List<AppUser>> fetchAllUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/users'));
    if (response.statusCode != 200) {
      throw const AttendanceApiException('Failed to load users.');
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> registerUser({
    required String role,
    required String fullname,
    required String userid,
    required String username,
    required String password,
    String? email,
    String? phone,
    List<int>? faceImageBytes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/admin/register');
    final request = http.MultipartRequest('POST', uri);
    
    request.fields.addAll({
      'role': role,
      'fullname': fullname,
      'userid': userid,
      'username': username,
      'password': password,
      'email': email ?? '',
      'phone': phone ?? '',
    });

    if (faceImageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'face_image',
        faceImageBytes,
        filename: 'register_face.jpg',
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw AttendanceApiException(body['message']?.toString() ?? 'Registration failed.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/stats/weekly'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load stats');
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<int>> downloadAttendancePdf() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/export/attendance'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to export PDF');
    return response.bodyBytes;
  }

  Future<List<Notice>> fetchNotices() async {
    final response = await http.get(Uri.parse('$baseUrl/api/notices'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load notices');
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Notice.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> postNotice(
    String content, 
    String authorName, 
    String authorRole, {
    String category = 'Info',
    bool broadcastPush = true,
    bool broadcastEmail = false,
    bool broadcastSms = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/notices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': content,
        'author_name': authorName,
        'author_role': authorRole,
        'category': category,
        'broadcast_push': broadcastPush,
        'broadcast_email': broadcastEmail,
        'broadcast_sms': broadcastSms,
      }),
    );
    if (response.statusCode != 201) throw const AttendanceApiException('Failed to post notice');
  }

  Future<Map<String, dynamic>> fetchSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/settings'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load settings');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchMonthlyAttendance() async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/attendance/monthly'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load monthly attendance');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchDailyAttendance(String month) async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/attendance/daily?month=$month'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load daily attendance');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<List<dynamic>> fetchDayStudentsAttendance(String date) async {
    final response = await http.get(Uri.parse('$baseUrl/api/admin/attendance/students?date=$date'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load student attendance');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings),
    );
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to update settings');
  }

  Future<void> changePassword(String username, String oldPass, String newPass) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/change_password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'old_password': oldPass,
        'new_password': newPass,
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw AttendanceApiException(body['message'] ?? 'Failed to change password');
    }
  }

  Future<void> bulkRegister(List<int> fileBytes) async {
    final uri = Uri.parse('$baseUrl/api/admin/bulk_register');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: 'users.xlsx'));
    final streamedResponse = await request.send();
    if (streamedResponse.statusCode != 201) throw const AttendanceApiException('Bulk upload failed');
  }

  Future<ScanResult> scanFrame(List<int> bytes, {String subject = 'General'}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/scan'));
    request.fields['subject'] = subject;
    request.files.add(http.MultipartFile.fromBytes('frame', bytes, filename: 'scan.jpg'));

    final response = await request.send();
    final responseStr = await response.stream.bytesToString();
    final body = jsonDecode(responseStr) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw AttendanceApiException(body['message'] ?? 'Scan Failed');
    }

    return ScanResult.fromJson(body);
  }

  Future<List<CalendarEvent>> fetchCalendarEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/api/calendar'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to load calendar');
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveCalendarEvent(String date, String title, String type) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/calendar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'date': date, 'title': title, 'type': type}),
    );
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to save event');
  }

  Future<void> deleteCalendarEvent(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/calendar/$id'));
    if (response.statusCode != 200) throw const AttendanceApiException('Failed to delete event');
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw const AttendanceApiException('Failed to load data.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class AttendanceApiException implements Exception {
  const AttendanceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
