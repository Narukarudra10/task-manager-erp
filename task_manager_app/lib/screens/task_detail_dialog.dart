import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../providers/task_provider.dart';
import '../providers/group_provider.dart';

class TaskDetailDialog extends StatelessWidget {
  final int taskId;

  const TaskDetailDialog({
    super.key,
    required this.taskId,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String type) {
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type.startsWith('video/')) return Icons.video_file_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _openAttachment(String url) async {
    String absoluteUrl = url;
    if (url.startsWith('/')) {
      final baseUrl = ApiService().baseUrl;
      absoluteUrl = '$baseUrl$url';
    }
    final uri = Uri.parse(absoluteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $absoluteUrl';
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

  Future<void> _confirmDelete(BuildContext context, Task task) async {
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
      if (!context.mounted) return;
      Navigator.pop(context); // Close TaskDetailDialog
      try {
        await context.read<TaskProvider>().deleteTask(task);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  Future<void> _updateAssignee(BuildContext context, int taskId, String? newAssigneeId) async {
    try {
      await context.read<TaskProvider>().updateTaskAssignee(taskId, newAssigneeId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignee updated successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update assignee: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskProvider = context.watch<TaskProvider>();
    final groupProvider = context.watch<GroupProvider>();

    final tasks = taskProvider.tasks;
    final taskIndex = tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    final task = tasks[taskIndex];
    final hasAttachments = task.attachments.isNotEmpty;
    final isAssigning = taskProvider.isAssigning;

    // Get priority badge color
    Color priorityColor;
    Color priorityTextColor;
    switch (task.priority) {
      case 'high':
        priorityColor = Colors.red.shade100;
        priorityTextColor = Colors.red.shade900;
        break;
      case 'medium':
        priorityColor = Colors.amber.shade100;
        priorityTextColor = Colors.amber.shade900;
        break;
      case 'low':
      default:
        priorityColor = Colors.blueGrey.shade100;
        priorityTextColor = Colors.blueGrey.shade900;
        break;
    }

    // Get next/prev status
    String? nextStatus;
    String? prevStatus;
    String? nextLabel;
    String? prevLabel;
    if (task.status == 'todo') {
      nextStatus = 'in_progress';
      nextLabel = 'In Progress';
    } else if (task.status == 'in_progress') {
      prevStatus = 'todo';
      prevLabel = 'To Do';
      nextStatus = 'done';
      nextLabel = 'Done';
    } else if (task.status == 'done') {
      prevStatus = 'in_progress';
      prevLabel = 'In Progress';
    }

    // Creator initials
    final creatorName = task.creatorName ?? 'User';
    final creatorEmail = task.creatorEmail ?? '';
    final creatorInitials = _getInitials(creatorName);

    final members = groupProvider.activeGroupMembers;

    // Helper to get selected assignee name
    String assigneeName = 'Unassigned';
    if (task.assignedTo != null) {
      final match = members.firstWhere(
        (m) => m['id'] == task.assignedTo,
        orElse: () => null,
      );
      if (match != null) {
        assigneeName = match['name'] as String;
      } else {
        assigneeName = task.assigneeName ?? 'User';
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Priority and Status badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${task.priority.toUpperCase()} PRIORITY',
                      style: TextStyle(
                        color: priorityTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                task.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Created on ${task.createdAt.month}/${task.createdAt.day}/${task.createdAt.year} at ${task.createdAt.hour}:${task.createdAt.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const Divider(height: 32),

              // Description
              Text(
                'Description',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(128)),
                ),
                child: Text(
                  task.description != null && task.description!.isNotEmpty
                      ? task.description!
                      : 'No description provided.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
              const SizedBox(height: 20),

              // Assignee Dropdown Section
              Text(
                'Assigned To',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: task.assignedTo != null
                          ? theme.colorScheme.secondary
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      child: Text(
                        task.assignedTo != null ? _getInitials(assigneeName) : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isAssigning
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: task.assignedTo,
                                isExpanded: true,
                                hint: const Text('Unassigned', style: TextStyle(fontSize: 14)),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Unassigned', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey, fontSize: 14)),
                                  ),
                                  if (task.assignedTo != null && !members.any((u) => u['id'] == task.assignedTo))
                                    DropdownMenuItem<String?>(
                                      value: task.assignedTo,
                                      child: Text(task.assigneeName ?? 'Loading...', style: const TextStyle(fontSize: 14)),
                                    ),
                                  ...members.map((u) => DropdownMenuItem<String?>(
                                        value: u['id'] as String,
                                        child: Text(u['name'] as String, style: const TextStyle(fontSize: 14)),
                                      )),
                                ],
                                onChanged: (value) => _updateAssignee(context, task.id, value),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Created By
              Text(
                'Created By',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        creatorInitials,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creatorName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (creatorEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              creatorEmail,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Attachments
              Text(
                'Attachments (${task.attachments.length})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (hasAttachments)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: task.attachments.length,
                  itemBuilder: (context, index) {
                    final att = task.attachments[index];
                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(_getFileIcon(att.fileType), size: 20),
                        title: Text(
                          att.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        subtitle: Text(
                          _formatFileSize(att.fileSize),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                        onTap: () => _openAttachment(att.fileUrl),
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(76)),
                  ),
                  child: const Text(
                    'No attachments',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 28),

              // Action buttons at footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, task),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                  Row(
                    children: [
                      if (prevStatus != null) ...[
                        ElevatedButton(
                          onPressed: () {
                            context.read<TaskProvider>().updateTaskStatus(task, prevStatus!);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 16),
                              const SizedBox(width: 4),
                              Text(prevLabel!, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (nextStatus != null)
                        ElevatedButton(
                          onPressed: () {
                            context.read<TaskProvider>().updateTaskStatus(task, nextStatus!);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(nextLabel!, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
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
  }
}
