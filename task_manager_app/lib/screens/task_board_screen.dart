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
    final isDark = theme.brightness == Brightness.dark;
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

    final mainContent = isLoading
        ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)))
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.white70),
                    const SizedBox(height: 16),
                    Text('Error: $errorMessage', style: const TextStyle(color: Colors.white)),
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
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              tasks: todoTasks,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTaskColumn(
                              title: 'In Progress',
                              status: 'in_progress',
                              icon: Icons.schedule_rounded,
                              color: isDark ? Colors.blue.shade400 : Colors.blue.shade700,
                              tasks: inProgressTasks,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTaskColumn(
                              title: 'Done',
                              status: 'done',
                              icon: Icons.check_circle_outline_rounded,
                              color: isDark ? Colors.green.shade400 : Colors.green.shade700,
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
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          indicatorColor: Colors.white,
                          indicatorSize: TabBarIndicatorSize.tab,
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
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _buildTaskList(todoTasks, 'todo'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _buildTaskList(inProgressTasks, 'in_progress'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _buildTaskList(doneTasks, 'done'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                },
              );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF0079BF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: Colors.white),
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
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterMode,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0067A3),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_rounded, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text('All Tasks', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'my',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_rounded, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text('My Tasks', style: TextStyle(color: Colors.white)),
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
                backgroundColor: Colors.white.withOpacity(0.15),
                side: BorderSide.none,
                avatar: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFF0079BF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                label: Text(
                  userName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
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
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A), // Slate 900
                    const Color(0xFF0D1B2A), // Midnight blue
                    const Color(0xFF1B263B), // Navy blue
                  ]
                : [
                    const Color(0xFF0079BF), // Trello blue
                    const Color(0xFF0091E6), // Vivid blue
                    const Color(0xFF51A2E8), // Light soft blue
                  ],
          ),
        ),
        child: mainContent,
      ),
    );
  }

  void _showAddTaskForStatus(String status) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddTaskDialog(initialStatus: status),
    );

    if (result == true && mounted) {
      context.read<TaskProvider>().loadTasks(quiet: true);
    }
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
                ? (isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.98))
                : (isDark ? const Color(0xFF101214) : const Color(0xFFF1F2F4)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? theme.colorScheme.primary.withOpacity(0.6)
                  : Colors.transparent,
              width: isHovering ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: isDark ? color.withOpacity(0.9) : color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF172B4D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22252A) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tasks.length.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: _buildTaskList(tasks, status),
                ),
              ),
              // "+ Add a card" button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: TextButton.icon(
                  onPressed: () => _showAddTaskForStatus(status),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : const Color(0xFF44546F),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add a card', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
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
    final isDark = theme.brightness == Brightness.dark;
    if (tasks.isEmpty) {
      return DragTarget<Task>(
        onWillAccept: (data) => data != null && data.status != columnStatus,
        onAccept: (task) {
          _updateStatus(task, columnStatus);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHovering
                    ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isHovering
                    ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), style: BorderStyle.solid)
                    : null,
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
            color: isHovering
                ? (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02))
                : Colors.transparent,
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
    final isDark = theme.brightness == Brightness.dark;

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

    // Format date like "Jun 18"
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[task.createdAt.month - 1]} ${task.createdAt.day}';

    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22252A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF303540) : Colors.grey.shade200,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showTaskDetails(task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top row: Priority Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityTextColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 2. Title and Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF172B4D),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Compact dropdown trigger
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, size: 16, color: Colors.grey),
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
                  ),
                ],
              ),

              // 3. Description preview
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF44546F),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],

              // 4. Attachments indicator
              if (hasAttachments) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attachment_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${task.attachments.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              
              // 5. Divider
              Divider(height: 1, color: isDark ? const Color(0xFF2C323D) : Colors.grey.shade100),
              const SizedBox(height: 8),

              // 6. Footer: Date on left, Avatars on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date badge (Trello style icon + date)
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  // Avatars stacked or spaced
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Creator Avatar
                      Tooltip(
                        message: 'Created by $creatorName',
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.85),
                          child: Text(
                            creatorInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (task.assignedTo != null) ...[
                        const SizedBox(width: 4),
                        // Assignee Avatar
                        Tooltip(
                          message: 'Assigned to ${task.assigneeName ?? 'User'}',
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: theme.colorScheme.secondary.withOpacity(0.85),
                            child: Text(
                              _getInitials(task.assigneeName ?? 'User'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22252A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
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
