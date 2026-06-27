import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback onNavigateToSignUp;

  const SignInScreen({
    super.key,
    required this.onNavigateToSignUp,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearAuthError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<AuthProvider>().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {
      // AuthProvider captures error into its authError field.
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                
                try {
                  await context.read<AuthProvider>().forgotPassword(email: email);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
                    );
                  }
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading;
    final errorMessage = authProvider.authError;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0B1E),
                    const Color(0xFF131535),
                    const Color(0xFF0F1026),
                  ]
                : [
                    const Color(0xFFF3F5FA),
                    const Color(0xFFE8EBF5),
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand Title above the card
                Text(
                  'TaskFlow ERP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Card Container
                Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2235) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282B4F) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                        blurRadius: 30,
                        spreadRadius: 1,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(36.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Badge Icon
                          Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF25294A) : const Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your TaskFlow ERP account to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Error message if any
                          if (errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
                              ),
                              child: Text(
                                errorMessage,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            labelText: 'Email Address',
                            hintText: 'Enter your email address',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            isDark: isDark,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Password Field
                          _buildTextField(
                            controller: _passwordController,
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icons.lock_outlined,
                            obscureText: _obscurePassword,
                            isDark: isDark,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Forgot Password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button with Gradient
                          _buildGradientButton(
                            text: 'Sign In',
                            onPressed: isLoading ? null : _submit,
                            isLoading: isLoading,
                          ),
                          const SizedBox(height: 24),

                          // "or continue with" divider
                          _buildDivider(isDark),
                          const SizedBox(height: 20),

                          // Social Login Placeholders
                          _buildSocialRow(isDark, context),
                          const SizedBox(height: 24),

                          // Navigation to Register Screen
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () {
                                        context.read<AuthProvider>().clearAuthError();
                                        widget.onNavigateToSignUp();
                                      },
                                child: Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  final VoidCallback onNavigateToSignIn;

  const SignUpScreen({
    super.key,
    required this.onNavigateToSignIn,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearAuthError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<AuthProvider>().signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {
      // AuthProvider captures error into its authError field.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading;
    final errorMessage = authProvider.authError;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0B1E),
                    const Color(0xFF131535),
                    const Color(0xFF0F1026),
                  ]
                : [
                    const Color(0xFFF3F5FA),
                    const Color(0xFFE8EBF5),
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand Title above the card
                Text(
                  'TaskFlow ERP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Card Container
                Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2235) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282B4F) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                        blurRadius: 30,
                        spreadRadius: 1,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(36.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Badge Icon
                          Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF25294A) : const Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Create your account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join TaskFlow ERP to start managing your projects.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Error message if any
                          if (errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
                              ),
                              child: Text(
                                errorMessage,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Full Name Field
                          _buildTextField(
                            controller: _nameController,
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icons.person_outline_rounded,
                            isDark: isDark,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            labelText: 'Email Address',
                            hintText: 'Enter your email address',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            isDark: isDark,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Password Field
                          _buildTextField(
                            controller: _passwordController,
                            labelText: 'Password',
                            hintText: 'Create a password',
                            prefixIcon: Icons.lock_outlined,
                            obscureText: _obscurePassword,
                            isDark: isDark,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Submit Button with Gradient
                          _buildGradientButton(
                            text: 'Create Account',
                            onPressed: isLoading ? null : _submit,
                            isLoading: isLoading,
                          ),
                          const SizedBox(height: 24),

                          // "or continue with" divider
                          _buildDivider(isDark),
                          const SizedBox(height: 20),

                          // Social Login Placeholders
                          _buildSocialRow(isDark, context),
                          const SizedBox(height: 24),

                          // Navigation to Login Screen
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () {
                                        context.read<AuthProvider>().clearAuthError();
                                        widget.onNavigateToSignIn();
                                      },
                                child: Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({
    super.key,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<AuthProvider>().resetPassword(
        token: widget.token,
        newPassword: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful! Please sign in.')),
        );
        // Navigate back to sign in
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen(onNavigateToSignUp: _dummyNavigate)),
          (route) => false,
        );
      }
    } catch (e) {
       // Handled by AuthProvider error state
    }
  }

  static void _dummyNavigate() {}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading;
    final errorMessage = authProvider.authError;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2235) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF282B4F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your new password below.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...[
                    Text(errorMessage, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  _buildTextField(
                    controller: _passwordController,
                    labelText: 'New Password',
                    hintText: 'Enter new password',
                    prefixIcon: Icons.lock_outlined,
                    obscureText: _obscurePassword,
                    isDark: isDark,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter new password',
                    prefixIcon: Icons.lock_clock_outlined,
                    obscureText: _obscurePassword,
                    isDark: isDark,
                    validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 24),
                  _buildGradientButton(
                    text: 'Reset Password',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper methods for clean visual elements

Widget _buildTextField({
  required TextEditingController controller,
  required String labelText,
  required String hintText,
  required IconData prefixIcon,
  bool obscureText = false,
  Widget? suffixIcon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  required bool isDark,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: TextStyle(
      color: isDark ? Colors.white : const Color(0xFF1E293B),
      fontSize: 14.5,
    ),
    decoration: InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontSize: 13.5,
      ),
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        fontSize: 13.5,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF13152C) : Colors.white,
      prefixIcon: Icon(
        prefixIcon,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF232746) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF232746) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF6366F1),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    ),
    validator: validator,
  );
}

Widget _buildGradientButton({
  required String text,
  required VoidCallback? onPressed,
  required bool isLoading,
}) {
  return Container(
    height: 50,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: onPressed == null
          ? null
          : const LinearGradient(
              colors: [
                Color(0xFF5E6FFF),
                Color(0xFFB84DF8),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
      color: onPressed == null ? Colors.grey.withOpacity(0.3) : null,
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.zero,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
    ),
  );
}

Widget _buildDivider(bool isDark) {
  return Row(
    children: [
      Expanded(
        child: Divider(
          color: isDark ? const Color(0xFF2A2E50) : const Color(0xFFE2E8F0),
          thickness: 1,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'or continue with',
          style: TextStyle(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Expanded(
        child: Divider(
          color: isDark ? const Color(0xFF2A2E50) : const Color(0xFFE2E8F0),
          thickness: 1,
        ),
      ),
    ],
  );
}

Widget _buildSocialRow(bool isDark, BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _buildSocialButton(
        iconWidget: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.png',
          width: 20,
          height: 20,
          errorBuilder: (context, error, stackTrace) => const Text(
            'G',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        onTap: () {
          context.read<AuthProvider>().signInWithGoogle();
        },
        isDark: isDark,
      ),
      const SizedBox(width: 16),
      _buildSocialButton(
        iconWidget: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Octicons-mark-github.svg/1024px-Octicons-mark-github.png',
          width: 20,
          height: 20,
          color: isDark ? Colors.white : Colors.black,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.code_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
        ),
        onTap: () {},
        isDark: isDark,
      ),
    ],
  );
}

Widget _buildSocialButton({
  required Widget iconWidget,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13152C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF232746) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: iconWidget,
      ),
    ),
  );
}
