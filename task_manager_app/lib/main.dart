import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screens.dart';
import 'screens/task_board_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/task_provider.dart';
import 'providers/group_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProxyProvider<GroupProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, groupProvider, taskProvider) {
            final activeGroup = groupProvider.activeGroup;
            final groupId = activeGroup != null ? activeGroup['id'] as int? : null;
            return taskProvider!..updateActiveGroup(groupId);
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'TaskFlow ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF06B6D4),
          surface: const Color(0xFFF1F5F9), // column background
          surfaceContainer: const Color(0xFFFFFFFF), // card background
          surfaceContainerHighest: const Color(0xFFF8FAFC), // sidebar background
          outlineVariant: const Color(0xFFE2E8F0), // border lines
        ),
        scaffoldBackgroundColor: const Color(0xFFEEF2F6),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF06B6D4),
          surface: const Color(0xFF111422), // column background
          surfaceContainer: const Color(0xFF161A2B), // card background
          surfaceContainerHighest: const Color(0xFF0E111E), // sidebar background
          outlineVariant: const Color(0xFF20263C), // border lines
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0C16),
        cardTheme: const CardThemeData(
          color: Color(0xFF161A2B),
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF111422),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const MainNavigationWrapper(),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  bool _showSignUp = false;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    _checkDeepLink();
  }

  void _checkDeepLink() {
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('reset_token')) {
      setState(() {
        _resetToken = uri.queryParameters['reset_token'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (_resetToken != null) {
      return ResetPasswordScreen(token: _resetToken!);
    }

    if (authProvider.isCheckingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      return const TaskBoardScreen();
    }

    if (_showSignUp) {
      return SignUpScreen(
        onNavigateToSignIn: () {
          setState(() {
            _showSignUp = false;
          });
        },
      );
    }

    return SignInScreen(
      onNavigateToSignUp: () {
        setState(() {
          _showSignUp = true;
        });
      },
    );
  }
}

