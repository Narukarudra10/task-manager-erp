import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  AuthProvider() {
    checkSession();
  }

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _apiService.isAuthenticated;
  Map<String, dynamic>? get currentUser => _apiService.currentUser;

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = Hive.box('settings');
      
      // Load and apply session token (Web and Native)
      final savedToken = box.get('session_token') as String?;
      if (savedToken != null) {
        _apiService.sessionToken = savedToken;
      }

      if (!kIsWeb) {
        // Native session restoration: load cookie from Hive
        final savedCookie = box.get('session_cookie') as String?;
        if (savedCookie != null) {
          _apiService.sessionCookie = savedCookie;
        }
      }

      // Check session validity with the backend
      final sessionData = await _apiService.getSession();
      
      if (sessionData == null) {
        // If session is invalid, clean up local cache
        _apiService.sessionToken = null;
        await box.delete('session_token');
        if (!kIsWeb) {
          _apiService.sessionCookie = null;
          await box.delete('session_cookie');
        }
      }
    } catch (e) {
      _apiService.sessionToken = null;
      final box = Hive.box('settings');
      await box.delete('session_token');
      if (!kIsWeb) {
        _apiService.sessionCookie = null;
        await box.delete('session_cookie');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.signIn(email: email, password: password);
      final box = Hive.box('settings');
      await box.put('session_token', _apiService.sessionToken);
      if (!kIsWeb) {
        await box.put('session_cookie', _apiService.sessionCookie);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.signUp(name: name, email: email, password: password);
      final box = Hive.box('settings');
      await box.put('session_token', _apiService.sessionToken);
      if (!kIsWeb) {
        await box.put('session_cookie', _apiService.sessionCookie);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.signOut();
      final box = Hive.box('settings');
      await box.delete('session_token');
      if (!kIsWeb) {
        await box.delete('session_cookie');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.deleteAccount();
      final box = Hive.box('settings');
      await box.delete('session_token');
      if (!kIsWeb) {
        await box.delete('session_cookie');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String name}) async {
    await _apiService.updateProfile(name: name);
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
