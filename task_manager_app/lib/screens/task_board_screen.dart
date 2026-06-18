import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import 'task_detail_dialog.dart';
import 'add_task_dialog.dart';
import 'settings_screen.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollingTimer;
  String _filterMode = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
    // Poll the API every 2 seconds to fetch updates in real-time
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        context.read<TaskProvider>().loadTasks(quiet: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(Task task, String newStatus) async {
    try {
      await context.read<TaskProvider>().updateTaskStatus(task, newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<TaskProvider>().deleteTask(task);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete task: $e')),
          );
        }
      }
    }
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        onStatusChange: (newStatus) => _updateStatus(task, newStatus),
        onDelete: () => _deleteTask(task),
        onTaskUpdated: () => context.read<TaskProvider>().loadTasks(quiet: true),
      ),
    );
  }

  void _showAddTask() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddTaskDialog(),
    );

    if (result == true && mounted) {
      context.read<TaskProvider>().loadTasks(quiet: true);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    final first = parts.first[0].toUpperCase();
    final last = parts.last[0].toUpperCase();
    return '$first$last';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    final userName = user?['name'] ?? 'User';
    final userEmail = user?['email'] ?? '';
    final initials = _getInitials(userName);
    final currentUserId = user?['id'] as String?;

    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.tasks;
    final isLoading = taskProvider.isLoading;
    final errorMessage = taskProvider.errorMessage;

    final filteredTasks = _filterMode == 'my'
        ? tasks.where((t) => t.assignedTo == currentUserId).toList()
        : tasks;

    final todoTasks = filteredTasks.where((t) => t.status == 'todo').toList();
    final inProgressTasks = filteredTasks.where((t) => t.status == 'in_progress').toList();
    final doneTasks = filteredTasks.where((t) => t.status == 'done').toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('TaskFlow', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Filter Mode Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterMode,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                dropdownColor: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('All Tasks'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'my',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('My Tasks'),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _filterMode = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // User profile chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Tooltip(
              message: userEmail,
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                label: Text(
                  userName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              if (mounted) {
                context.read<TaskProvider>().loadTasks();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<AuthProvider>().signOut();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to sign out: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Error: $errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<TaskProvider>().loadTasks(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      // Desktop/Web side-by-side columns
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTaskColumn(
                                title: 'To Do',
                                status: 'todo',
                                icon: Icons.circle_outlined,
                                color: Colors.grey.shade400,
                                tasks: todoTasks,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTaskColumn(
                                title: 'In Progress',
                                status: 'in_progress',
                                icon: Icons.schedule_rounded,
                                color: Colors.blue.shade600,
                                tasks: inProgressTasks,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTaskColumn(
                                title: 'Done',
                                status: 'done',
                                icon: Icons.check_circle_outline_rounded,
                                color: Colors.green.shade600,
                                tasks: doneTasks,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Mobile tabbed columns
                      return Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: [
                              Tab(text: 'To Do (${todoTasks.length})'),
                              Tab(text: 'In Progress (${inProgressTasks.length})'),
                              Tab(text: 'Done (${doneTasks.length})'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildTaskList(todoTasks, 'todo'),
                                _buildTaskList(inProgressTasks, 'in_progress'),
                                _buildTaskList(doneTasks, 'done'),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
    );
  }

  Widget _buildTaskColumn({
    required String title,
    required String status,
    required IconData icon,
    required Color color,
    required List<Task> tasks,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DragTarget<Task>(
      onWillAccept: (data) => data != null && data.status != status,
      onAccept: (task) {
        _updateStatus(task, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovering
                ? theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.08 : 0.12)
                : (isDark ? const Color(0xFF0D0E15).withOpacity(0.5) : Colors.grey.shade50.withOpacity(0.85)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering
                  ? theme.colorScheme.primary.withOpacity(0.6)
                  : (isDark ? Colors.grey.shade800 : theme.colorScheme.outlineVariant.withOpacity(0.4)),
              width: isHovering ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Accent Indicator Line
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tasks.length.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 8, indent: 16, endIndent: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _buildTaskList(tasks, status),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskList(List<Task> tasks, String columnStatus) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return DragTarget<Task>(
        onWillAccept: (data) => data != null && data.status != columnStatus,
        onAccept: (task) {
          _updateStatus(task, columnStatus);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHovering ? theme.colorScheme.primaryContainer.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isHovering ? 'Drop here to update status' : 'No tasks in this stage',
                  style: TextStyle(
                    color: isHovering ? theme.colorScheme.primary : Colors.grey,
                    fontSize: 13,
                    fontWeight: isHovering ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return DragTarget<Task>(
      onWillAccept: (data) => data != null && data.status != columnStatus,
      onAccept: (task) {
        _updateStatus(task, columnStatus);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovering ? theme.colorScheme.primaryContainer.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    final theme = Theme.of(context);
    final hasAttachments = task.attachments.isNotEmpty;

    // Get priority badge color (Soft Pastel Scheme)
    Color priorityColor;
    Color priorityTextColor;
    switch (task.priority) {
      case 'high':
        priorityColor = const Color(0xFFFEE2E2); // soft red
        priorityTextColor = const Color(0xFF991B1B);
        break;
      case 'medium':
        priorityColor = const Color(0xFFFEF3C7); // soft amber
        priorityTextColor = const Color(0xFF92400E);
        break;
      case 'low':
      default:
        priorityColor = const Color(0xFFF1F5F9); // soft slate/grey
        priorityTextColor = const Color(0xFF475569);
        break;
    }

    // Get next/prev status
    String? nextStatus;
    String? prevStatus;
    if (task.status == 'todo') {
      nextStatus = 'in_progress';
    } else if (task.status == 'in_progress') {
      prevStatus = 'todo';
      nextStatus = 'done';
    } else if (task.status == 'done') {
      prevStatus = 'in_progress';
    }

    // Creator initials
    final creatorName = task.creatorName ?? 'User';
    final creatorInitials = _getInitials(creatorName);

    final isDark = theme.brightness == Brightness.dark;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900.withOpacity(0.85) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTaskDetails(task),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Actions Dropdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 120),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteTask(task);
                      } else {
                        _updateStatus(task, value);
                      }
                    },
                    itemBuilder: (context) => [
                      if (prevStatus != null)
                        PopupMenuItem(
                          value: prevStatus,
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 16),
                              const SizedBox(width: 8),
                              Text('Move Back', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      if (nextStatus != null)
                        PopupMenuItem(
                          value: nextStatus,
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                              const SizedBox(width: 8),
                              Text('Move Forward', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Description preview
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Attachments preview
              if (hasAttachments) ...[
                Row(
                  children: [
                    Icon(Icons.attachment_rounded, size: 12, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${task.attachments.length} attachment${task.attachments.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Footer: Priority, Date, Assignee, and Creator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.priority.toUpperCase(),
                          style: TextStyle(
                            color: priorityTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${task.createdAt.month}/${task.createdAt.day}/${task.createdAt.year}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Assignee Avatar
                      if (task.assignedTo != null) ...[
                        Tooltip(
                          message: 'Assigned to ${task.assigneeName ?? 'User'}',
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: theme.colorScheme.secondary,
                            child: Text(
                              _getInitials(task.assigneeName ?? 'User'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // Creator Avatar
                      Tooltip(
                        message: 'Created by $creatorName',
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            creatorInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final feedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );

    final childWhenDragging = Opacity(
      opacity: 0.35,
      child: card,
    );

    if (kIsWeb) {
      return Draggable<Task>(
        data: task,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: card,
      );
    } else {
      return LongPressDraggable<Task>(
        data: task,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: card,
      );
    }
  }
}
