import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class GroupProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _groups = [];
  dynamic _activeGroup;
  List<dynamic> _pendingInvites = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> _activeGroupMembers = [];
  bool _isLoadingMembers = false;
  bool _isSendingInvite = false;

  List<dynamic> get groups => _groups;
  dynamic get activeGroup => _activeGroup;
  List<dynamic> get pendingInvites => _pendingInvites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<dynamic> get activeGroupMembers => _activeGroupMembers;
  bool get isLoadingMembers => _isLoadingMembers;
  bool get isSendingInvite => _isSendingInvite;

  Future<void> loadActiveGroupMembers({bool quiet = false}) async {
    if (_activeGroup == null) {
      _activeGroupMembers = [];
      _isLoadingMembers = false;
      notifyListeners();
      return;
    }
    if (!quiet || _activeGroupMembers.isEmpty) {
      _isLoadingMembers = true;
      notifyListeners();
    }
    try {
      final list = await _apiService.fetchGroupMembers(_activeGroup['id'] as int);
      _activeGroupMembers = list;
    } catch (e) {
      _activeGroupMembers = [];
    } finally {
      if (!quiet || _isLoadingMembers) {
        _isLoadingMembers = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadGroups({bool quiet = false}) async {
    if (!quiet) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _apiService.fetchGroups();
      _groups = list;
      _errorMessage = null;

      // Select active group if not already set, or if current active is no longer in the list
      if (_groups.isNotEmpty) {
        if (_activeGroup == null) {
          _activeGroup = _groups.first;
          await loadActiveGroupMembers(quiet: quiet);
        } else {
          final stillExists = _groups.any((g) => g['id'] == _activeGroup['id']);
          if (!stillExists) {
            _activeGroup = _groups.first;
            await loadActiveGroupMembers(quiet: quiet);
          } else {
            // Update active group details (e.g. role, name)
            _activeGroup = _groups.firstWhere((g) => g['id'] == _activeGroup['id']);
            // Refresh members list silently or on changes
            await loadActiveGroupMembers(quiet: quiet);
          }
        }
      } else {
        _activeGroup = null;
        _activeGroupMembers = [];
      }
    } catch (e) {
      if (!quiet) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      if (!quiet) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void setActiveGroup(dynamic group) {
    _activeGroup = group;
    loadActiveGroupMembers(quiet: false);
    notifyListeners();
  }

  Future<void> createGroup({required String name, String? description}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newGroup = await _apiService.createGroup(name: name, description: description);
      await loadGroups(quiet: true);
      // Select the newly created group
      _activeGroup = _groups.firstWhere((g) => g['id'] == newGroup['id'], orElse: () => _groups.isNotEmpty ? _groups.first : null);
      await loadActiveGroupMembers(quiet: false);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingInvites() async {
    try {
      final list = await _apiService.fetchPendingInvites();
      _pendingInvites = list;
      notifyListeners();
    } catch (e) {
      // Fail silently for invites load
    }
  }

  Future<void> acceptInvite(String inviteId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.respondToInvite(inviteId: inviteId, action: 'accept');
      // Reload groups and select the accepted one
      await loadGroups();
      await loadPendingInvites();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> declineInvite(String inviteId) async {
    try {
      await _apiService.respondToInvite(inviteId: inviteId, action: 'decline');
      await loadPendingInvites();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> inviteUser({
    required int groupId,
    required String email,
    String role = 'member',
  }) async {
    _isSendingInvite = true;
    notifyListeners();
    try {
      await _apiService.sendInvite(groupId: groupId, email: email, role: role);
    } finally {
      _isSendingInvite = false;
      notifyListeners();
    }
  }

  void clear() {
    _groups = [];
    _activeGroup = null;
    _pendingInvites = [];
    _activeGroupMembers = [];
    _isLoadingMembers = false;
    _isSendingInvite = false;
    _errorMessage = null;
    notifyListeners();
  }
}
