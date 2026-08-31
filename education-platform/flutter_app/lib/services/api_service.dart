import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/subject.dart';

class ApiService {
  // يُستبدل بعنوان الـ API الفعلي عند النشر
  static const String baseUrl = 'https://api.education-platform.example.com';

  final _storage = const FlutterSecureStorage();

  Future<String?> _token() => _storage.read(key: 'access_token');

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// تسجيل الدخول بالرقم المدني أو رقم الطالب.
  Future<String> login({required String identifier, required String idType}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'id_type': idType}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      throw ApiException(body['detail'] ?? 'تعذّر تسجيل الدخول');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    await _storage.write(key: 'access_token', value: data['access_token']);
    await _storage.write(key: 'full_name', value: data['full_name']);
    return data['full_name'] as String;
  }

  Future<bool> isLoggedIn() async => (await _token()) != null;

  Future<void> logout() => _storage.deleteAll();

  /// جميع المواد المقررة على الطالب الحالي — تُستدعى فور الدخول للـ Dashboard.
  Future<List<Subject>> fetchMySubjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/subjects/me'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذّر تحميل المواد الدراسية');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Subject.fromJson(json)).toList();
  }

  Future<List<LessonSummary>> fetchSubjectLessons(String subjectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/subjects/$subjectId/lessons'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException('تعذّر تحميل دروس المادة');
    }

    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => LessonSummary.fromJson(json)).toList();
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
