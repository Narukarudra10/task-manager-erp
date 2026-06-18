import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'http_client.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  http.Client _client = createClient();

  @visibleForTesting
  set client(http.Client value) {
    _client = value;
  }
  String _baseUrl = _defaultBaseUrl;
  String? _sessionCookie;
  String? _sessionToken;
  Map<String, dynamic>? _currentUser;

  static String get _defaultBaseUrl {
    if (kIsWeb) {
      final baseUri = Uri.base;
      final portStr = baseUri.hasPort ? ':${baseUri.port}' : '';
      return '${baseUri.scheme}://${baseUri.host}$portStr';
    }
    if (!kIsWeb && Platform.isAndroid) {
      // Connect to host machine from Android emulator
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _sessionCookie != null || _sessionToken != null || _currentUser != null;
  Map<String, dynamic>? get currentUser => _currentUser;

  String? get sessionCookie => _sessionCookie;
  set sessionCookie(String? value) {
    _sessionCookie = value;
  }

  String? get sessionToken => _sessionToken;
  set sessionToken(String? value) {
    _sessionToken = value;
  }

  set currentUser(Map<String, dynamic>? user) {
    _currentUser = user;
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  void _updateTokenAndCookie(http.Response response, Map<String, dynamic> data) {
    if (data['session'] != null && data['session']['token'] != null) {
      _sessionToken = data['session']['token'] as String;
    }
    _updateCookie(response);
  }

  void _updateCookie(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      // Parse cookies
      final cookies = rawCookie.split(',');
      List<String> cookieParts = [];
      for (var cookie in cookies) {
        final parts = cookie.split(';');
        if (parts.isNotEmpty) {
          cookieParts.add(parts[0].trim());
        }
      }
      if (cookieParts.isNotEmpty) {
        _sessionCookie = cookieParts.join('; ');
      }
    }
  }

  Future<Map<String, dynamic>?> getSession() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/get-session');
      final response = await _client.get(
        uri,
        headers: _headers,
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == 'null') {
          _currentUser = null;
          return null;
        }
        final data = jsonDecode(response.body);
        if (data != null && data['user'] != null) {
          _updateTokenAndCookie(response, data);
          _currentUser = data['user'];
          return data;
        }
      }
      _currentUser = null;
      return null;
    } catch (e) {
      _currentUser = null;
      return null;
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/sign-up/email'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _updateTokenAndCookie(response, data);
      _currentUser = data['user'];
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Sign up failed');
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/sign-in/email'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _updateTokenAndCookie(response, data);
      _currentUser = data['user'];
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Sign in failed');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.post(
        Uri.parse('$_baseUrl/api/auth/sign-out'),
        headers: _headers,
      );
    } finally {
      _sessionCookie = null;
      _sessionToken = null;
      _currentUser = null;
    }
  }

  Future<void> deleteAccount() async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/users'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      _sessionCookie = null;
      _sessionToken = null;
      _currentUser = null;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to delete account');
    }
  }

  Future<List<dynamic>> fetchUsers() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/users'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['users'] ?? [];
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<List<dynamic>> fetchTasks() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/tasks'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['tasks'] ?? [];
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    String priority = 'medium',
    String? assignedTo,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/tasks'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'priority': priority,
        'assignedTo': assignedTo,
        'attachments': attachments,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to create task');
    }
  }

  Future<void> updateTask({
    required int id,
    String? status,
    String? assignedTo,
  }) async {
    final body = <String, dynamic>{'id': id};
    if (status != null) body['status'] = status;
    
    // Allow unassigning tasks by sending an empty string which maps to null on the backend
    if (assignedTo != null) {
      body['assignedTo'] = assignedTo.isEmpty ? null : assignedTo;
    }

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/tasks'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to update task');
    }
  }

  Future<void> updateTaskStatus(int id, String status) async {
    await updateTask(id: id, status: status);
  }

  Future<void> deleteTask(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/tasks?id=$id'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to delete task');
    }
  }

  Future<void> updateProfile({required String name}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/update-user'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Update local current user details
      if (_currentUser != null && data['user'] != null) {
        _currentUser!['name'] = data['user']['name'];
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update profile');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/change-password'),
      headers: _headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'revokeOtherSessions': true,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to change password');
    }
  }

  Future<Map<String, dynamic>> uploadFile({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    if (filePath == null && fileBytes == null) {
      throw Exception('Either filePath or fileBytes must be provided');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/upload'),
    );

    // Attach headers
    if (_sessionToken != null) {
      request.headers['Authorization'] = 'Bearer $_sessionToken';
    }
    if (_sessionCookie != null) {
      request.headers['Cookie'] = _sessionCookie!;
    }
    request.headers['Accept'] = 'application/json';

    // Add file
    final mimeType = _getMimeType(fileName);
    final contentType = MediaType.parse(mimeType);

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: contentType,
        ),
      );
    } else {
      // Native only: verify and add from path
      final file = File(filePath!);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          contentType: contentType,
        ),
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'File upload failed');
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').pop().toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}

extension ListExtensions<T> on List<T> {
  T pop() => removeLast();
}
