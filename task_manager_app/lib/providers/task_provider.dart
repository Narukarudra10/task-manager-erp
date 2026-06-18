import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTasks({bool quiet = false}) async {
    if (!quiet) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _apiService.fetchTasks();
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
    String? assignedTo,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      await _apiService.createTask(
        title: title,
        description: description,
        priority: priority,
        status: status,
        assignedTo: assignedTo,
        attachments: attachments,
      );
      await loadTasks(quiet: true);
    } catch (e) {
      rethrow;
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

  Future<void> deleteTask(Task task) async {
    try {
      await _apiService.deleteTask(task.id);
      await loadTasks(quiet: true);
    } catch (e) {
      rethrow;
    }
  }
}
