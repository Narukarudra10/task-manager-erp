import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/custom_dotted_border.dart';

class AddTaskDialog extends StatefulWidget {
  final String initialStatus;
  const AddTaskDialog({super.key, this.initialStatus = 'todo'});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedAssigneeIds = [];

  InputDecoration _getInputDecoration({
    required String label,
    required String hint,
    IconData? prefixIcon,
    required bool isDark,
    required ThemeData theme,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF161A2B) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 13),
      hintStyle: const TextStyle(fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().resetCreateState();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'webm', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          final filePath = kIsWeb ? null : file.path;
          final fileName = file.name;
          final fileBytes = file.bytes;
          if (filePath != null || fileBytes != null) {
            await context.read<TaskProvider>().uploadAttachment(
              filePath: filePath,
              fileBytes: fileBytes,
              fileName: fileName,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    context.read<TaskProvider>().removeCreateAttachment(index);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final taskProvider = context.read<TaskProvider>();
    try {
      await taskProvider.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: taskProvider.createPriority,
        status: widget.initialStatus,
        assignees: _selectedAssigneeIds,
        attachments: taskProvider.createAttachments,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: \$e')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '\$bytes B';
    if (bytes < 1024 * 1024) return '\${(bytes / 1024).toStringAsFixed(1)} KB';
    return '\${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskProvider = context.watch<TaskProvider>();
    final groupProvider = context.watch<GroupProvider>();

    final isSaving = taskProvider.isCreateSaving;
    final isUploading = taskProvider.isCreateUploading;
    final attachments = taskProvider.createAttachments;
    final priority = taskProvider.createPriority;
    final members = groupProvider.activeGroupMembers;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '📋 ',
                          style: TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Create New Task',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Title
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _getInputDecoration(
                    label: 'Task Title',
                    hint: 'Enter task title',
                    isDark: isDark,
                    theme: theme,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: _getInputDecoration(
                    label: 'Description (optional)',
                    hint: 'Enter task description',
                    isDark: isDark,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Dropdown
                DropdownButtonFormField<String>(
                  value: priority,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  dropdownColor: isDark ? const Color(0xFF161A2B) : Colors.white,
                  decoration: _getInputDecoration(
                    label: 'Priority',
                    hint: 'Select priority',
                    isDark: isDark,
                    theme: theme,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      taskProvider.setCreatePriority(value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Multi-Assignee Section
                Text(
                  'Assign To',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((member) {
                    final userId = member['id'] as String;
                    final isSelected = _selectedAssigneeIds.contains(userId);
                    return FilterChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: isSelected ? Colors.white : theme.colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          _getInitials(member['name'] as String),
                          style: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      label: Text(member['name'] as String, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedAssigneeIds.add(userId);
                          } else {
                            _selectedAssigneeIds.remove(userId);
                          }
                        });
                      },
                      selectedColor: theme.colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Attachments Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attachments',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (attachments.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: isUploading || isSaving ? null : _pickAndUploadFiles,
                        icon: isUploading
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_rounded, size: 16),
                        label: Text(
                          isUploading ? 'Uploading...' : 'Add Files',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Attachments List / Upload Zone
                if (attachments.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        final att = attachments[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.attach_file_rounded, size: 18),
                          title: Text(
                            att['fileName'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            _formatFileSize(att['fileSize'] as int),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 18),
                            onPressed: () => _removeAttachment(index),
                          ),
                        );
                      },
                    ),
                  )
                else
                  GestureDetector(
                    onTap: isUploading || isSaving ? null : _pickAndUploadFiles,
                    child: CustomDottedBorder(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: 8,
                      strokeWidth: 1.2,
                      gap: 5.0,
                      dashLength: 5.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161A2B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Drag & drop files or click to browse',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supports JPG, PNG, GIF, MP4, PDF, DOCX',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSaving || isUploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Task',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
