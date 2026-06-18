import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/task_provider.dart';

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
  String _priority = 'medium';
  String? _assignedUserId;
  
  bool _isSaving = false;
  bool _isUploading = false;
  final List<Map<String, dynamic>> _attachments = [];
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await ApiService().fetchUsers();
      setState(() {
        _users = list;
      });
    } catch (e) {
      // Fail silently, fallback to empty user list
    }
  }

  Future<void> _pickAndUploadFiles() async {
    setState(() {
      _isUploading = true;
    });

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
            // Upload immediately to the API
            final uploadedData = await ApiService().uploadFile(
              filePath: filePath,
              fileBytes: fileBytes,
              fileName: fileName,
            );
            
            setState(() {
              _attachments.add({
                'fileName': uploadedData['fileName'],
                'fileUrl': uploadedData['url'],
                'fileType': uploadedData['fileType'],
                'fileSize': uploadedData['fileSize'],
              });
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<TaskProvider>().createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        status: widget.initialStatus,
        assignedTo: _assignedUserId,
        attachments: _attachments,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
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
                    Text(
                      'Create New Task',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                    hintText: 'Enter task title',
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
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Enter task description',
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Dropdown
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _priority = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Assign To Dropdown
                DropdownButtonFormField<String?>(
                  value: _assignedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Assign To (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ..._users.map((u) => DropdownMenuItem<String?>(
                          value: u['id'] as String,
                          child: Text(u['name'] as String),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _assignedUserId = value;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Attachments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attachments',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isUploading || _isSaving ? null : _pickAndUploadFiles,
                      icon: _isUploading
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(_isUploading ? 'Uploading...' : 'Add Files'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Attachments List
                if (_attachments.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(128)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _attachments.length,
                      itemBuilder: (context, index) {
                        final att = _attachments[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.attach_file_rounded, size: 18),
                          title: Text(
                            att['fileName'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_formatFileSize(att['fileSize'] as int)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 18),
                            onPressed: () => _removeAttachment(index),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                        style: BorderStyle.none,
                      ),
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'No files attached yet',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving || _isUploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                // Wait, valueColor: AlwaysStoppedAnimation(Colors.white) is fine in Flutter
                              ),
                            )
                          : const Text('Create Task'),
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
