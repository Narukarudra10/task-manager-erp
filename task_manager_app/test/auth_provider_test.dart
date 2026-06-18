import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:task_manager_app/providers/auth_provider.dart';
import 'package:task_manager_app/services/api_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return handler(request);
  }
}

void main() {
  late Directory tempDir;
  late ApiService apiService;

  setUp(() async {
    // Initialize temporary Hive database
    tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');

    // Reset ApiService singleton state
    apiService = ApiService();
    apiService.sessionToken = null;
    apiService.sessionCookie = null;
    apiService.currentUser = null;
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('AuthProvider signIn stores token in Hive and sets isAuthenticated', () async {
    final responsePayload = {
      'user': {
        'id': 'user_123',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
      },
      'session': {
        'token': 'mock_session_token_xyz',
      }
    };

    apiService.client = MockHttpClient((request) async {
      if (request.url.path.contains('/api/auth/get-session')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('null')),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/api/auth/sign-in/email')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responsePayload))),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(Stream.value([]), 404);
    });

    final authProvider = AuthProvider();
    await authProvider.checkSession(); // Wait for auto startup session check to finish
    
    // Initial state: not authenticated
    expect(authProvider.isAuthenticated, isFalse);

    // Call sign in
    await authProvider.signIn(email: 'jane@example.com', password: 'password123');

    // Verify state updates
    expect(authProvider.isAuthenticated, isTrue);
    expect(authProvider.currentUser?['name'], equals('Jane Doe'));
    expect(apiService.sessionToken, equals('mock_session_token_xyz'));

    // Verify token was stored in Hive
    final box = Hive.box('settings');
    expect(box.get('session_token'), equals('mock_session_token_xyz'));
  });

  test('AuthProvider checkSession restores session from Hive token', () async {
    // Put token in Hive before initialization
    final box = Hive.box('settings');
    await box.put('session_token', 'cached_token_123');

    final responsePayload = {
      'user': {
        'id': 'user_123',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
      },
    };

    apiService.client = MockHttpClient((request) async {
      if (request.url.path.contains('/api/auth/get-session')) {
        expect(request.headers['Authorization'], equals('Bearer cached_token_123'));
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responsePayload))),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(Stream.value([]), 404);
    });

    final authProvider = AuthProvider();
    await authProvider.checkSession(); // Wait for session check to finish

    expect(authProvider.isAuthenticated, isTrue);
    expect(authProvider.currentUser?['email'], equals('jane@example.com'));
  });

  test('AuthProvider deleteAccount calls DELETE api and clears session state', () async {
    // Pre-populate session
    apiService.sessionToken = 'active_token';
    apiService.currentUser = {'id': 'user_123', 'email': 'jane@example.com'};
    final box = Hive.box('settings');
    await box.put('session_token', 'active_token');

    final getSessionPayload = {
      'user': {
        'id': 'user_123',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
      },
    };

    apiService.client = MockHttpClient((request) async {
      if (request.url.path.contains('/api/auth/get-session')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(getSessionPayload))),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'DELETE' && request.url.path.contains('/api/users')) {
        expect(request.headers['Authorization'], equals('Bearer active_token'));
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'success': true}))),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(Stream.value([]), 404);
    });

    final authProvider = AuthProvider();
    await authProvider.checkSession(); // Wait for session check to finish

    expect(authProvider.isAuthenticated, isTrue);

    // Call delete account
    await authProvider.deleteAccount();

    // Verify state cleared
    expect(authProvider.isAuthenticated, isFalse);
    expect(authProvider.currentUser, isNull);
    expect(apiService.sessionToken, isNull);
    expect(box.get('session_token'), isNull);
  });
}
