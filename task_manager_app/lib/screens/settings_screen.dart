import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isProfileSaving = false;
  bool _isPasswordSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ApiService().currentUser;
    _nameController = TextEditingController(text: user?['name'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() {
      _isProfileSaving = true;
    });

    try {
      await context.read<AuthProvider>().updateProfile(
        name: _nameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProfileSaving = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _isPasswordSaving = true;
    });

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
    } finally {
      if (mounted) {
        setState(() {
          _isPasswordSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final user = context.read<AuthProvider>().currentUser;
    final userEmail = user?['email'] as String? ?? '';
    final confirmationController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final text = confirmationController.text.trim();
            final isMatching = text.toLowerCase() == userEmail.toLowerCase();

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
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isMatching
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete Forever'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Deleting account...')),
      );

      try {
        await context.read<AuthProvider>().deleteAccount();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final currentThemeMode = themeProvider.themeMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Theme Options Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            color: theme.colorScheme.primary,
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
                      const SizedBox(height: 16),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Light'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Dark'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.settings_brightness_outlined),
                            label: Text('System'),
                          ),
                        ],
                        selected: {currentThemeMode},
                        onSelectionChanged: (Set<ThemeMode> selection) {
                          themeProvider.setThemeMode(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Profile Details Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Profile Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProfileSaving ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isProfileSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Save Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Change Password Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_person_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your current password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a new password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm New Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.check_circle_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your new password';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPasswordSaving
                                ? null
                                : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isPasswordSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sign Out Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: theme.colorScheme.primary,
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
                      const SizedBox(height: 8),
                      Text(
                        'Sign out of your account on this device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await context.read<AuthProvider>().signOut();
                              if (context.mounted) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed to sign out: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign Out'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Account Management Card (Delete Account)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.shade200.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dangerous_outlined,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Account Management',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleting your account is permanent. This will delete your profile, credentials, and all tasks created by you.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _confirmDeleteAccount(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Delete Account',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
