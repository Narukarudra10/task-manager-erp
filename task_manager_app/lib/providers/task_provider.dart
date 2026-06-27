import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  final ApiService _apiService = ApiService();
  int? _activeGroupId;

  // New state variables for no-setState policy
  String _filterMode = 'all';
  bool _isAssigning = false;

  // Task Creation states
  String _createPriority = 'medium';
  String? _createAssignedUserId;
  bool _isCreateSaving = false;
  bool _isCreateUploading = false;
  List<Map<String, dynamic>> _createAttachments = [];

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get activeGroupId => _activeGroupId;

  String get filterMode => _filterMode;
  bool get isAssigning => _isAssigning;

  String get createPriority => _createPriority;
  String? get createAssignedUserId => _createAssignedUserId;
  bool get isCreateSaving => _isCreateSaving;
  bool get isCreateUploading => _isCreateUploading;
  List<Map<String, dynamic>> get createAttachments => _createAttachments;

  void setFilterMode(String mode) {
    if (_filterMode != mode) {
      _filterMode = mode;
      notifyListeners();
    }
  }

  void setCreatePriority(String priority) {
    _createPriority = priority;
    notifyListeners();
  }

  void setCreateAssignedUserId(String? userId) {
    _createAssignedUserId = userId;
    notifyListeners();
  }

  void resetCreateState() {
    _createPriority = 'medium';
    _createAssignedUserId = null;
    _isCreateSaving = false;
    _isCreateUploading = false;
    _createAttachments = [];
    notifyListeners();
  }

  Future<void> uploadAttachment({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    _isCreateUploading = true;
    notifyListeners();
    try {
      final uploadedData = await _apiService.uploadFile(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      _createAttachments.add({
        'fileName': uploadedData['fileName'],
        'fileUrl': uploadedData['url'],
        'fileType': uploadedData['fileType'],
        'fileSize': uploadedData['fileSize'],
      });
    } finally {
      _isCreateUploading = false;
      notifyListeners();
    }
  }

  void removeCreateAttachment(int index) {
    _createAttachments.removeAt(index);
    notifyListeners();
  }

  void updateActiveGroup(int? groupId) {
    if (_activeGroupId != groupId) {
      _activeGroupId = groupId;
      _tasks = [];
      _errorMessage = null;
      loadTasks();
    }
  }

  Future<void> loadTasks({bool quiet = false}) async {
    if (_activeGroupId == null) {
      _tasks = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (!quiet) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _apiService.fetchTasks(groupId: _activeGroupId);
      _tasks = list.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
      _errorMessage = null;
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

  Future<void> createTask({
    required String title,
    String? description,
    String priority = 'medium',
    String status = 'todo',
    List<String> assignees = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    if (_activeGroupId == null) {
      throw Exception('No active group selected. Cannot create task.');
    }
    _isCreateSaving = true;
    notifyListeners();
    try {
      await _apiService.createTask(
        title: title,
        groupId: _activeGroupId!,
        description: description,
        priority: priority,
        status: status,
        assignees: assignees,
        attachments: attachments,
      );
      await loadTasks(quiet: true);
      resetCreateState();
    } finally {
      _isCreateSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateTaskStatus(Task task, String newStatus) async {
    try {
      await _apiService.updateTask(id: task.id, status: newStatus);
      await loadTasks(quiet: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTaskAssignees(int taskId, List<String> assignees) async {
    _isAssigning = true;
    notifyListeners();
    try {
      await _apiService.updateTask(
        id: taskId,
        assignees: assignees,
      );
      await loadTasks(quiet: true);
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _apiService.deleteTask(task.id);
      await loadTasks(quiet: true);
    } catch (e) {
      rethrow;
    }
  }
}
