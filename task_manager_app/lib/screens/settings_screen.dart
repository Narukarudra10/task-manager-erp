import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/group_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: const SettingsContent(),
    );
  }
}

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _inviteFormKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();
      context.read<GroupProvider>().loadPendingInvites();
    });
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite(int groupId) async {
    if (!_inviteFormKey.currentState!.validate()) return;
    final email = _inviteEmailController.text.trim();

    try {
      await context.read<GroupProvider>().inviteUser(
        groupId: groupId,
        email: email,
      );
      _inviteEmailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invite: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    try {
      await context.read<AuthProvider>().changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change password: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final user = context.read<AuthProvider>().currentUser;
    final userEmail = user?['email'] as String? ?? '';
    final confirmationController = TextEditingController();
    final isMatchingNotifier = ValueNotifier<bool>(false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Your Account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is irreversible. All your data, tasks, and attachments will be deleted forever.',
              ),
              const SizedBox(height: 16),
              Text(
                'To confirm, please type your email address:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userEmail,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  isMatchingNotifier.value =
                      val.trim().toLowerCase() == userEmail.toLowerCase();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isMatchingNotifier,
              builder: (context, isMatching, child) {
                return ElevatedButton(
                  onPressed: isMatching
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete Forever'),
                );
              },
            ),
          ],
        );
      },
    );

    confirmationController.dispose();
    isMatchingNotifier.dispose();

    if (confirm == true) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Deleting account...')),
      );

      try {
        await context.read<AuthProvider>().deleteAccount();
        if (mounted) {
          context.read<GroupProvider>().clear();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
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
                            const SnackBar(
                              content: Text('Workspace created successfully!'),
                            ),
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

  Widget _buildThemeOption(
      BuildContext context, ThemeMode mode, String label, bool isDark, ThemeData theme, ThemeProvider themeProvider) {
    final isSelected = themeProvider.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => themeProvider.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2E344D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: isDark ? const Color(0xFF3F486B) : const Color(0xFFCBD5E1), width: 1)
                : null,
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    required ThemeData theme,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 13),
          decoration: _getInputDecoration(hint: hint, isDark: isDark, theme: theme),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _getInputDecoration({
    required String hint,
    required bool isDark,
    required ThemeData theme,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? const Color(0xFF0E111E) : const Color(0xFFF8FAFC),
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
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final activeGroup = groupProvider.activeGroup;
    final groupsList = groupProvider.groups;
    final isAdmin = activeGroup != null && activeGroup['role'] == 'admin';

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Heading
              Text(
                'Settings',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your workspace, appearance, security, and account settings.',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Card 1: Appearance
              Card(
                color: theme.colorScheme.surfaceContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Appearance',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0E111E) : const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _buildThemeOption(context, ThemeMode.light, 'Light', isDark, theme, themeProvider),
                            _buildThemeOption(context, ThemeMode.dark, 'Dark', isDark, theme, themeProvider),
                            _buildThemeOption(context, ThemeMode.system, 'System', isDark, theme, themeProvider),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Card 2: Workspace Management
              Card(
                color: theme.colorScheme.surfaceContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.business_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Workspace Management',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => _showCreateGroupDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text(
                              'Create Workspace',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Active Workspace Label & Dropdown
                      Text(
                        'Active Workspace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (groupsList.isEmpty)
                        const Text(
                          'You do not belong to any workspaces yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E111E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<dynamic>(
                              value: activeGroup != null && groupsList.any((g) => g['id'] == activeGroup['id'])
                                  ? groupsList.firstWhere((g) => g['id'] == activeGroup['id'])
                                  : null,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF161A2B) : Colors.white,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              items: groupsList.map((g) {
                                return DropdownMenuItem<dynamic>(
                                  value: g,
                                  child: Text(g['name'] as String),
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
                      const SizedBox(height: 24),

                      // Workspace Members
                      if (activeGroup != null) ...[
                        Text(
                          'Workspace Members',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (groupProvider.isLoadingMembers)
                          const Center(child: CircularProgressIndicator())
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: groupProvider.activeGroupMembers.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final m = groupProvider.activeGroupMembers[index];
                              final name = m['name'] as String? ?? 'User';
                              final email = m['email'] as String? ?? '';
                              final role = m['role'] as String? ?? 'member';
                              final isMe = m['id'] == ApiService().currentUser?['id'];

                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    foregroundColor: theme.colorScheme.primary,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$name ${isMe ? "(You)" : ""}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        if (email.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2E344D) : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // Invite Member Form
                        if (isAdmin) ...[
                          const Divider(height: 32),
                          Text(
                            'Invite Member',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Form(
                            key: _inviteFormKey,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _inviteEmailController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: _getInputDecoration(
                                      hint: 'Enter email to invite',
                                      isDark: isDark,
                                      theme: theme,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter email';
                                      }
                                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                        return 'Invalid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: groupProvider.isSendingInvite
                                      ? null
                                      : () => _sendInvite(activeGroup['id'] as int),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                  ),
                                  child: groupProvider.isSendingInvite
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Pending Invitations Card
              Builder(
                builder: (context) {
                  final pendingInvites = groupProvider.pendingInvites;

                  if (pendingInvites.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      Card(
                        color: theme.colorScheme.surfaceContainer,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.mark_email_unread_outlined,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Workspace Invitations',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: pendingInvites.length,
                                itemBuilder: (context, index) {
                                  final invite = pendingInvites[index];
                                  return Card(
                                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            invite['groupName'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Invited by ${invite['invitedByName']}',
                                            style: TextStyle(
                                              color: isDark ? Colors.white60 : Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () async {
                                                  await context.read<GroupProvider>().declineInvite(
                                                        invite['id'] as String,
                                                      );
                                                },
                                                style: TextButton.styleFrom(
                                                  foregroundColor: theme.colorScheme.error,
                                                ),
                                                child: const Text('Decline'),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await context.read<GroupProvider>().acceptInvite(
                                                        invite['id'] as String,
                                                      );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Joined workspace!'),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: const Text('Join'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // Card 3: Change Password
              Card(
                color: theme.colorScheme.surfaceContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _passwordFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Change Password',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 650;
                            final inputs = [
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: _buildInputField(
                                  label: 'Current Password',
                                  hint: '••••••••',
                                  controller: _currentPasswordController,
                                  isDark: isDark,
                                  theme: theme,
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter current password';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: _buildInputField(
                                  label: 'New Password',
                                  hint: 'Enter new password',
                                  controller: _newPasswordController,
                                  isDark: isDark,
                                  theme: theme,
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter new password';
                                    }
                                    if (value.length < 6) {
                                      return 'At least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: _buildInputField(
                                  label: 'Confirm Password',
                                  hint: 'Confirm new password',
                                  controller: _confirmPasswordController,
                                  isDark: isDark,
                                  theme: theme,
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Confirm new password';
                                    }
                                    if (value != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ];

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: inputs,
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: inputs.map((w) => w is Expanded ? w.child : w).toList(),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: authProvider.isPasswordSaving ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                            child: authProvider.isPasswordSaving
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Card 4: Session
              Card(
                color: theme.colorScheme.surfaceContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Session',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign out of your account on this device.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await context.read<AuthProvider>().signOut();
                              if (context.mounted) {
                                context.read<GroupProvider>().clear();
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed to sign out: $e')),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Card 5: Delete Account
              Card(
                color: theme.colorScheme.surfaceContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Deleting your account is permanent. This will delete your profile, credentials, and all tasks created by you.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => _confirmDeleteAccount(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade600.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
