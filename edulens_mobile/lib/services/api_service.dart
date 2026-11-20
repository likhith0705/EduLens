
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl =
    'https://edulens-backend-245046756856.asia-south1.run.app';

  static Uri _emailUri(String endpoint, String email) {
    return Uri.parse('$baseUrl/$endpoint/${Uri.encodeComponent(email)}');
  }

  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> googleLogin(
    String idToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google').replace(
        queryParameters: {'token': idToken},
      ),
    );

    debugPrint('Google Login Status: ${response.statusCode}');
    debugPrint('Google Login URL: ${response.request?.url}');

    if (response.statusCode != 200) {
      throw Exception(
        'Google login failed: ${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> getStudentProfile(
    String email,
  ) async {
    final response = await http.get(
      _emailUri('students', email),
    );

    debugPrint('Student Profile Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Student profile request failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> getFaceStatus(
    String email,
  ) async {
    final response = await http.get(
      _emailUri('face/status', email),
    );

    debugPrint('Face Status Code: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Face status request failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> registerFace(
    String email,
    XFile image,
  ) async {
    final extension = image.name.split('.').last.toLowerCase();

    final mediaType = switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };

    final request = http.MultipartRequest(
      'POST',
      _emailUri('face/register', email),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
        contentType: mediaType,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('Face Registration Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Face registration failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> getAttendance(
    String email,
  ) async {
    final response = await http.get(
      _emailUri('attendance', email),
    );

    debugPrint('Attendance Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Attendance request failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> getPerformance(
    String email,
  ) async {
    final response = await http.get(
      _emailUri('performance', email),
    );

    debugPrint('Performance Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'Performance request failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  
static Future<Map<String, dynamic>> recognizeClassroom(
  String idToken,
  XFile image,
) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/face/recognize'),
  );

  request.headers['Authorization'] = 'Bearer $idToken';

  final extension = image.name.toLowerCase();
  final contentType = extension.endsWith('.png')
      ? MediaType('image', 'png')
      : extension.endsWith('.webp')
          ? MediaType('image', 'webp')
          : MediaType('image', 'jpeg');

  request.files.add(
    await http.MultipartFile.fromPath(
      'image',
      image.path,
      filename: image.name,
      contentType: contentType,
    ),
  );

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(
    streamedResponse,
  );

  debugPrint(
    'Classroom Recognition Status: ${response.statusCode}',
  );
  debugPrint(
    'Classroom Recognition Response: ${response.body}',
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Classroom recognition failed: '
      '${response.statusCode} ${response.body}',
    );
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}



static Future<Map<String, dynamic>> confirmAttendance({
  required String idToken,
  required String subject,
  required int hour,
  required String classDate,
  required String section,
  required String department,
  required int semester,
  required List<Map<String, String>> attendanceRecords,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/attendance/confirm'),
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'subject': subject,
      'hour': hour,
      'class_date': classDate,
      'section': section,
      'department': department,
      'semester': semester,
      'attendance_records': attendanceRecords,
    }),
  );

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  debugPrint('Attendance Confirmation: ${response.statusCode}');
  debugPrint('Attendance Response: ${response.body}');

  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] is String
          ? data['detail']
          : jsonEncode(data['detail'] ?? 'Attendance confirmation failed'),
    );
  }

  return data;
}



static Future<Map<String, dynamic>> getClassRoster({
  required String idToken,
  required String department,
  required int semester,
  required String section,
}) async {
  final uri = Uri.parse('$baseUrl/attendance/roster/class')
      .replace(queryParameters: {
    'department': department,
    'semester': semester.toString(),
    'section': section,
  });

  final response = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $idToken'},
  );

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] ?? 'Could not load class roster',
    );
  }

  return data;
}


static Future<Map<String, dynamic>> getAttendanceSessions({
  required String idToken,
  String? department,
  int? semester,
  String? section,
  int limit = 100,
}) async {
  final queryParameters = <String, String>{
    'limit': limit.toString(),
    if (department != null && department.trim().isNotEmpty)
      'department': department.trim(),
    if (semester != null) 'semester': semester.toString(),
    if (section != null && section.trim().isNotEmpty)
      'section': section.trim(),
  };

  final uri = Uri.parse('$baseUrl/attendance/sessions')
      .replace(queryParameters: queryParameters);

  final response = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $idToken'},
  );

  final decoded = jsonDecode(response.body);

  if (response.statusCode != 200) {
    final detail = decoded is Map<String, dynamic>
        ? decoded['detail'] ?? 'Could not load attendance sessions'
        : 'Could not load attendance sessions';

    throw Exception(detail);
  }

  return Map<String, dynamic>.from(decoded as Map);
}

}
