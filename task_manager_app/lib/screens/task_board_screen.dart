import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/group_provider.dart';
import 'task_detail_dialog.dart';
import 'add_task_dialog.dart';
import 'settings_screen.dart';

import '../widgets/custom_dotted_border.dart';

class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollingTimer;
  String _activeTab = 'board';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();
      context.read<GroupProvider>().loadPendingInvites();
    });
    // Poll the API every 3 seconds to fetch updates in real-time
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        final groupProvider = context.read<GroupProvider>();
        if (groupProvider.groups.isNotEmpty) {
          context.read<TaskProvider>().loadTasks(quiet: true);
        }
        groupProvider.loadGroups(quiet: true);
        groupProvider.loadPendingInvites();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
        }
      }
    }
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        taskId: task.id,
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    final first = parts.first[0].toUpperCase();
    final last = parts.last[0].toUpperCase();
    return '$first$last';
  }

  Widget _buildSidebar(BuildContext context, bool isDrawer) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.watch<AuthProvider>();

    final sidebarBg = theme.colorScheme.surfaceContainerHighest;
    final activeColor = theme.colorScheme.primary;
    final textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final activeTextColor = Colors.white;

    Widget buildNavItem({
      required IconData icon,
      required String label,
      required bool isActive,
      required VoidCallback onTap,
      Color? customIconColor,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          onTap: () {
            onTap();
            if (isDrawer) {
              Navigator.pop(context);
            }
          },
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(
            icon,
            color: isActive ? activeTextColor : (customIconColor ?? textColor),
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isActive ? activeTextColor : textColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 240,
      color: sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'TASKS',
              style: TextStyle(
                color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
          buildNavItem(
            icon: Icons.home_rounded,
            label: 'All Tasks',
            isActive: _activeTab == 'board' && taskProvider.filterMode == 'all',
            onTap: () {
              setState(() {
                _activeTab = 'board';
              });
              taskProvider.setFilterMode('all');
            },
          ),
          buildNavItem(
            icon: Icons.check_box_outlined,
            label: 'My Tasks',
            isActive: _activeTab == 'board' && taskProvider.filterMode == 'my',
            onTap: () {
              setState(() {
                _activeTab = 'board';
              });
              taskProvider.setFilterMode('my');
            },
          ),
          const Spacer(),
          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: 8),
          buildNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: _activeTab == 'settings',
            onTap: () {
              setState(() {
                _activeTab = 'settings';
              });
            },
          ),
          buildNavItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            isActive: false,
            customIconColor: Colors.redAccent,
            onTap: () async {
              try {
                await authProvider.signOut();
                if (mounted) {
                  context.read<GroupProvider>().clear();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to logout: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final groupProvider = context.watch<GroupProvider>();
    final groups = groupProvider.groups;
    final activeGroup = groupProvider.activeGroup;
    final isGroupLoading = groupProvider.isLoading;

    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.tasks;
    final isLoading = taskProvider.isLoading || isGroupLoading;
    final errorMessage = taskProvider.errorMessage ?? groupProvider.errorMessage;

    final currentUserId = context.watch<AuthProvider>().currentUser?['id'] as String?;
    final userName = context.watch<AuthProvider>().currentUser?['name'] ?? 'User';
    final initials = _getInitials(userName);

    Widget innerContent;

    if (_activeTab == 'settings') {
      innerContent = const SettingsContent();
    } else {
      final filteredTasks = taskProvider.filterMode == 'my'
          ? tasks.where((t) => t.assignedTo == currentUserId).toList()
          : tasks;

      final todoTasks = filteredTasks.where((t) => t.status == 'todo').toList();
      final inProgressTasks = filteredTasks.where((t) => t.status == 'in_progress').toList();
      final doneTasks = filteredTasks.where((t) => t.status == 'done').toList();

      if (isLoading) {
        innerContent = const Center(
          child: CircularProgressIndicator(),
        );
      } else if (errorMessage != null) {
        innerContent = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Error: $errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<GroupProvider>().loadGroups(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      } else if (groups.isEmpty) {
        innerContent = _buildOnboardingScreen();
      } else {
        innerContent = LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              final double colWidth = constraints.maxWidth > 1100
                  ? (constraints.maxWidth - 64) / 3
                  : 340.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: colWidth,
                        child: _buildTaskColumn(
                          title: 'To Do',
                          status: 'todo',
                          icon: Icons.circle_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                          tasks: todoTasks,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: colWidth,
                        child: _buildTaskColumn(
                          title: 'In Progress',
                          status: 'in_progress',
                          icon: Icons.circle,
                          color: const Color(0xFF06B6D4),
                          tasks: inProgressTasks,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: colWidth,
                        child: _buildTaskColumn(
                          title: 'Done',
                          status: 'done',
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF10B981),
                          tasks: doneTasks,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                    indicatorColor: theme.colorScheme.primary,
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
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0C16) : const Color(0xFFEEF2F6),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (isMobile) ...[
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TaskFlow ERP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Text(
                      'Enterprise Edition',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (groups.isNotEmpty && _activeTab == 'board') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: activeGroup != null && groups.any((g) => g['id'] == activeGroup['id'])
                          ? groups.firstWhere((g) => g['id'] == activeGroup['id'])
                          : null,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      hint: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Select Workspace', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      items: groups.map<DropdownMenuItem<dynamic>>((g) {
                        return DropdownMenuItem<dynamic>(
                          value: g,
                          child: Text(
                            g['name'] as String,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          groupProvider.setActiveGroup(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_activeTab == 'board' && groups.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () => _showAddTaskForStatus('todo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Task'),
                ),
                const SizedBox(width: 12),
              ],
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_activeTab == 'board' && groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      taskProvider.filterMode == 'my' ? 'My Tasks' : 'All Tasks',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Organize and track all tasks in one place.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: innerContent,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 800;

        return Scaffold(
          drawer: isMobile ? Drawer(child: _buildSidebar(context, true)) : null,
          body: isMobile
              ? _buildMainContent(context, true)
              : Row(
                  children: [
                    _buildSidebar(context, false),
                    Expanded(
                      child: _buildMainContent(context, false),
                    ),
                  ],
                ),
        );
      },
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

  Widget _buildEmptyState({
    required String status,
    required bool isDark,
  }) {
    IconData icon;
    String title;
    String subtitle;
    Color iconColor;

    switch (status) {
      case 'todo':
        icon = Icons.inventory_2_outlined;
        title = 'Ready for work';
        subtitle = 'No tasks waiting in queue';
        iconColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
        break;
      case 'in_progress':
        icon = Icons.autorenew_rounded;
        title = 'Active focus';
        subtitle = 'Nothing currently in progress';
        iconColor = const Color(0xFF06B6D4);
        break;
      case 'done':
      default:
        icon = Icons.verified_outlined;
        title = 'All caught up';
        subtitle = 'Completed tasks will appear here';
        iconColor = const Color(0xFF10B981);
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          status == 'in_progress'
              ? SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                )
              : Icon(
                  icon,
                  size: 40,
                  color: iconColor,
                ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
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
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        _updateStatus(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovering
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.98))
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: isHovering ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    Icon(
                      icon,
                      size: 18,
                      color: isDark ? color.withValues(alpha: 0.9) : color,
                    ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF222535)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tasks.length.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Colors.grey),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: _buildTaskList(tasks, status),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: CustomDottedBorder(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: 8,
                  strokeWidth: 1.0,
                  gap: 4,
                  dashLength: 6,
                  child: TextButton.icon(
                    onPressed: () => _showAddTaskForStatus(status),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF44546F),
                      minimumSize: const Size(double.infinity, 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Add Task',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
        onWillAcceptWithDetails: (details) => details.data.status != columnStatus,
        onAcceptWithDetails: (details) {
          _updateStatus(details.data, columnStatus);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHovering
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isHovering
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    )
                  : null,
            ),
            child: isHovering
                ? Center(
                    child: Text(
                      'Drop here to update status',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : _buildEmptyState(status: columnStatus, isDark: isDark),
          );
        },
      );
    }

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != columnStatus,
      onAcceptWithDetails: (details) {
        _updateStatus(details.data, columnStatus);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovering
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.02))
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

    Color priorityColor;
    Color priorityTextColor;
    switch (task.priority) {
      case 'high':
        priorityColor = isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEE2E2);
        priorityTextColor = isDark ? const Color(0xFFEF4444) : const Color(0xFFB91C1C);
        break;
      case 'medium':
        priorityColor = isDark ? const Color(0xFF3D2E1A) : const Color(0xFFFEF3C7);
        priorityTextColor = isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309);
        break;
      case 'low':
      default:
        priorityColor = isDark ? const Color(0xFF1E2235) : const Color(0xFFF1F5F9);
        priorityTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        break;
    }

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

    final creatorName = task.creatorName ?? 'User';
    final creatorInitials = _getInitials(creatorName);

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${months[task.createdAt.month - 1]} ${task.createdAt.day}';

    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
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
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
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
                                Text(
                                  'Move Back',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        if (nextStatus != null)
                          PopupMenuItem(
                            value: nextStatus,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Move Forward',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
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
              if (hasAttachments) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.attachment_rounded,
                      size: 12,
                      color: Colors.grey,
                    ),
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
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Created by $creatorName',
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.85),
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
                        Tooltip(
                          message: 'Assigned to ${task.assigneeName ?? 'User'}',
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.85),
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
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
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

    final childWhenDragging = Opacity(opacity: 0.35, child: card);

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

  // Beautiful onboarding view when user belongs to no groups/workspaces
  Widget _buildOnboardingScreen() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupProvider = context.watch<GroupProvider>();
    final pendingInvites = groupProvider.pendingInvites;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header
              Icon(
                Icons.workspace_premium_rounded,
                size: 64,
                color: isDark ? Colors.amber.shade400 : Colors.amber.shade200,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to TaskFlow Workspaces',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Workspaces secure your projects and keep tasks separate. To start adding cards, please create a new workspace or accept an invitation below.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Create Workspace Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_business_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Create a New Workspace',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Start a workspace and invite team members to collaborate in real-time.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _showCreateGroupDialog,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Create Workspace'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Invitations Section
              if (pendingInvites.isNotEmpty) ...[
                Text(
                  'Pending Invitations (${pendingInvites.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingInvites.length,
                  itemBuilder: (context, index) {
                    final invite = pendingInvites[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              invite['groupName'] as String,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (invite['groupDescription'] != null) ...[
                              Text(
                                invite['groupDescription'] as String,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              'Invited by: ${invite['invitedByName']} (${invite['invitedByEmail']})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black45,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await context.read<GroupProvider>().declineInvite(invite['id'] as String);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Invitation declined')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error,
                                  ),
                                  child: const Text('Decline'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await context.read<GroupProvider>().acceptInvite(invite['id'] as String);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Workspace joined successfully!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Join Workspace'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined, color: Colors.white70),
                      SizedBox(width: 12),
                      Text(
                        'No pending invitations found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isSavingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: isSavingNotifier,
        builder: (context, isSaving, child) => AlertDialog(
          title: const Text('Create New Workspace'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Workspace Name',
                    hintText: 'e.g. Engineering Team',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      isSavingNotifier.value = true;
                      try {
                        await context.read<GroupProvider>().createGroup(
                              name: nameController.text.trim(),
                              description: descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workspace created successfully!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        isSavingNotifier.value = false;
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      descController.dispose();
      isSavingNotifier.dispose();
    });
  }
}
