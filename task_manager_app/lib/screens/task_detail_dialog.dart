import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskDetailDialog extends StatefulWidget {
  final Task task;
  final ValueChanged<String> onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback onTaskUpdated;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.onStatusChange,
    required this.onDelete,
    required this.onTaskUpdated,
  });

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  List<dynamic> _users = [];
  String? _assignedUserId;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _assignedUserId = widget.task.assignedTo;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await ApiService().fetchUsers();
      setState(() {
        _users = list;
      });
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> _updateAssignee(String? newAssigneeId) async {
    setState(() {
      _isAssigning = true;
    });

    try {
      await ApiService().updateTask(
        id: widget.task.id,
        assignedTo: newAssigneeId ?? '',
      );
      setState(() {
        _assignedUserId = newAssigneeId;
      });
      widget.onTaskUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignee updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update assignee: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  String _getAssigneeName() {
    if (_assignedUserId == null) return 'Unassigned';
    final userMatch = _users.firstWhere(
      (u) => u['id'] == _assignedUserId,
      orElse: () => null,
    );
    if (userMatch != null) return userMatch['name'] as String;
    return widget.task.assigneeName ?? 'User';
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAttachments = widget.task.attachments.isNotEmpty;

    // Get priority badge color
    Color priorityColor;
    Color priorityTextColor;
    switch (widget.task.priority) {
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
    if (widget.task.status == 'todo') {
      nextStatus = 'in_progress';
      nextLabel = 'In Progress';
    } else if (widget.task.status == 'in_progress') {
      prevStatus = 'todo';
      prevLabel = 'To Do';
      nextStatus = 'done';
      nextLabel = 'Done';
    } else if (widget.task.status == 'done') {
      prevStatus = 'in_progress';
      prevLabel = 'In Progress';
    }

    // Creator initials
    final creatorName = widget.task.creatorName ?? 'User';
    final creatorEmail = widget.task.creatorEmail ?? '';
    final creatorInitials = _getInitials(creatorName);

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
                      '${widget.task.priority.toUpperCase()} PRIORITY',
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
                      widget.task.status.replaceAll('_', ' ').toUpperCase(),
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
                widget.task.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Created on ${widget.task.createdAt.month}/${widget.task.createdAt.day}/${widget.task.createdAt.year} at ${widget.task.createdAt.hour}:${widget.task.createdAt.minute.toString().padLeft(2, '0')}',
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
                  widget.task.description != null && widget.task.description!.isNotEmpty
                      ? widget.task.description!
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
                      backgroundColor: _assignedUserId != null
                          ? theme.colorScheme.secondary
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      child: Text(
                        _assignedUserId != null ? _getInitials(_getAssigneeName()) : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isAssigning
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
                                value: _assignedUserId,
                                isExpanded: true,
                                hint: const Text('Unassigned', style: TextStyle(fontSize: 14)),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Unassigned', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey, fontSize: 14)),
                                  ),
                                  if (_assignedUserId != null && !_users.any((u) => u['id'] == _assignedUserId))
                                    DropdownMenuItem<String?>(
                                      value: _assignedUserId,
                                      child: Text(widget.task.assigneeName ?? 'Loading...', style: const TextStyle(fontSize: 14)),
                                    ),
                                  ..._users.map((u) => DropdownMenuItem<String?>(
                                        value: u['id'] as String,
                                        child: Text(u['name'] as String, style: const TextStyle(fontSize: 14)),
                                      )),
                                ],
                                onChanged: (value) => _updateAssignee(value),
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
                'Attachments (${widget.task.attachments.length})',
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
                  itemCount: widget.task.attachments.length,
                  itemBuilder: (context, index) {
                    final att = widget.task.attachments[index];
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
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
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
                            Navigator.pop(context);
                            widget.onStatusChange(prevStatus!);
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
                            Navigator.pop(context);
                            widget.onStatusChange(nextStatus!);
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
