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
    } else if (data['token'] != null) {
      _sessionToken = data['token'] as String;
    } else if (response.headers['set-auth-token'] != null) {
      _sessionToken = response.headers['set-auth-token'];
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
      String errorMessage = 'Sign up failed';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = (errorData['message'] as String?) ?? errorMessage;
      } on FormatException {
        errorMessage = response.body.isNotEmpty
            ? response.body
            : 'Sign up failed (status ${response.statusCode})';
      }
      throw Exception(errorMessage);
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
      String errorMessage = 'Sign in failed';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = (errorData['message'] as String?) ?? errorMessage;
      } on FormatException {
        errorMessage = response.body.isNotEmpty
            ? response.body
            : 'Sign in failed (status ${response.statusCode})';
      }
      throw Exception(errorMessage);
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
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/users'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to delete account';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = (errorData['error'] as String?) ?? errorMessage;
        } on FormatException {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : 'Failed to delete account (status ${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } finally {
      _sessionCookie = null;
      _sessionToken = null;
      _currentUser = null;
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

  Future<List<dynamic>> fetchTasks({int? groupId}) async {
    final queryParams = groupId != null ? '?groupId=$groupId' : '';
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/tasks$queryParams'),
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
    required int groupId,
    String? description,
    String priority = 'medium',
    String status = 'todo',
    List<String> assignees = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/tasks'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'groupId': groupId,
        'description': description,
        'priority': priority,
        'status': status,
        'assignees': assignees,
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
    List<String>? assignees,
  }) async {
    final body = <String, dynamic>{'id': id};
    if (status != null) body['status'] = status;
    if (assignees != null) body['assignees'] = assignees;

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

  Future<void> updateTaskAssignees(int id, List<String> assignees) async {
    await updateTask(id: id, assignees: assignees);
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

  // Workspaces / Groups API Support
  Future<List<dynamic>> fetchGroups() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/groups'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['groups'] ?? [];
    } else {
      throw Exception('Failed to load groups');
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/groups'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['group'] ?? {};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to create group');
    }
  }

  Future<List<dynamic>> fetchGroupMembers(int groupId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/groups/members?groupId=$groupId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['members'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to load group members');
    }
  }

  Future<List<dynamic>> fetchPendingInvites() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/groups/invites'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['invites'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to load invites');
    }
  }

  Future<Map<String, dynamic>> sendInvite({
    required int groupId,
    required String email,
    String role = 'member',
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/groups/invites'),
      headers: _headers,
      body: jsonEncode({
        'groupId': groupId,
        'email': email,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['invite'] ?? {};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to send invite');
    }
  }

  Future<void> respondToInvite({
    required String inviteId,
    required String action, // 'accept' or 'decline'
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/groups/invites'),
      headers: _headers,
      body: jsonEncode({
        'inviteId': inviteId,
        'action': action,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to update invitation');
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

  Future<void> forgotPassword({required String email}) async {
    final baseUrl = _baseUrl;
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/forget-password'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'redirectTo': '$baseUrl/?reset_token=',
      }),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Failed to send reset email';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = (errorData['message'] as String?) ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/reset-password'),
      headers: _headers,
      body: jsonEncode({
        'token': token,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Failed to reset password';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = (errorData['message'] as String?) ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
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

  Future<void> signInWithGoogle() async {
    // For Flutter Web: redirect to Google OAuth URL
    final callbackUrl = Uri.base.origin;
    final googleUrl = '$_baseUrl/api/auth/sign-in/social?provider=google&callbackURL=$callbackUrl';
    throw Exception('REDIRECT_REQUIRED:$googleUrl');
  }

  Future<void> initiateGoogleSignIn({required String callbackUrl}) async {
    throw Exception('REDIRECT_REQUIRED:$callbackUrl');
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
