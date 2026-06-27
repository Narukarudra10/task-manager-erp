import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isCheckingSession = true;
  final ApiService _apiService = ApiService();
  bool _isProfileSaving = false;
  bool _isPasswordSaving = false;
  bool _isForgotPasswordLoading = false;
  String? _authError;
  String? _forgotPasswordMessage;

  AuthProvider() {
    checkSession();
  }

  bool get isLoading => _isLoading;
  bool get isCheckingSession => _isCheckingSession;
  bool get isAuthenticated => _apiService.isAuthenticated;
  Map<String, dynamic>? get currentUser => _apiService.currentUser;
  bool get isProfileSaving => _isProfileSaving;
  bool get isPasswordSaving => _isPasswordSaving;
  bool get isForgotPasswordLoading => _isForgotPasswordLoading;
  String? get authError => _authError;
  String? get forgotPasswordMessage => _forgotPasswordMessage;

  void clearAuthError() {
    _authError = null;
    _forgotPasswordMessage = null;
    notifyListeners();
  }

  Future<void> checkSession() async {
    _isCheckingSession = true;
    _isLoading = true;
    notifyListeners();

    try {
      final box = Hive.box('settings');
      
      // Load and apply session token (Web and Native)
      final savedToken = box.get('session_token') as String?;
      if (savedToken == null) {
        _apiService.sessionToken = null;
        _apiService.currentUser = null;
        if (!kIsWeb) {
          _apiService.sessionCookie = null;
        }
        return;
      }

      _apiService.sessionToken = savedToken;

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
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();
    try {
      await _apiService.signIn(email: email, password: password);
      final box = Hive.box('settings');
      await box.put('session_token', _apiService.sessionToken);
      if (!kIsWeb) {
        await box.put('session_cookie', _apiService.sessionCookie);
      }
    } catch (e) {
      _authError = e.toString().replaceAll('Exception: ', '');
      rethrow;
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
    _authError = null;
    notifyListeners();
    try {
      await _apiService.signUp(name: name, email: email, password: password);
      final box = Hive.box('settings');
      await box.put('session_token', _apiService.sessionToken);
      if (!kIsWeb) {
        await box.put('session_cookie', _apiService.sessionCookie);
      }
    } catch (e) {
      _authError = e.toString().replaceAll('Exception: ', '');
      rethrow;
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
    } catch (e) {
      // Ignore backend sign out error to ensure local cache is always cleared
    } finally {
      final box = Hive.box('settings');
      await box.delete('session_token');
      if (!kIsWeb) {
        await box.delete('session_cookie');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.deleteAccount();
    } catch (e) {
      // Ignore backend error to ensure local cache is always cleared
    } finally {
      final box = Hive.box('settings');
      await box.delete('session_token');
      if (!kIsWeb) {
        await box.delete('session_cookie');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String name}) async {
    _isProfileSaving = true;
    notifyListeners();
    try {
      await _apiService.updateProfile(name: name);
    } finally {
      _isProfileSaving = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isPasswordSaving = true;
    notifyListeners();
    try {
      await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      _isPasswordSaving = false;
      notifyListeners();
    }
  }

  Future<void> forgotPassword({required String email}) async {
    _isForgotPasswordLoading = true;
    _authError = null;
    _forgotPasswordMessage = null;
    notifyListeners();
    try {
      await _apiService.forgotPassword(email: email);
      _forgotPasswordMessage = 'Password reset email sent! Check your inbox.';
    } catch (e) {
      _authError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isForgotPasswordLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();
    try {
      await _apiService.resetPassword(token: token, newPassword: newPassword);
    } catch (e) {
      _authError = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    // For Flutter Web: redirect to Google OAuth URL
    // The browser will handle the OAuth flow and redirect back to the app
    // After redirect, checkSession() will detect the new session
    final googleUrl = '${_apiService.baseUrl}/api/auth/sign-in/social?provider=google&callbackURL=/';
    if (Uri.parse(googleUrl).hasScheme) {
      // Use url_launcher to open the Google OAuth URL
      // On web this will navigate in the same tab
      _isLoading = true;
      notifyListeners();
      try {
        await _apiService.initiateGoogleSignIn(callbackUrl: googleUrl);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
