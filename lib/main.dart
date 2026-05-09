import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cache_service.dart';
import 'torr9_api.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await CacheService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Torr9 Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // Indigo
          secondary: Color(0xFF10B981), // Emerald
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Will default to system if Inter isn't provided
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1)),
          ),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _checkAuth() async {
    final token = await CacheService().getCacheEntry('auth_token');
    if (token != null && token.toString().isNotEmpty) {
      try {
        // Refresh profile data from API on start
        final profile = await Torr9Api().getMe(token.toString());
        await CacheService().updateCacheEntry('user_profile', profile);
      } catch (e) {
        // If the token is revoked or invalid (401), logout the user
        if (e.toString().contains('401')) {
          await CacheService().removeCacheEntry('auth_token');
          await CacheService().removeCacheEntry('user_profile');
          return const LoginScreen();
        }
        // For other errors (e.g. offline), we still proceed with existing cache
        debugPrint('App start profile refresh failed: $e');
      }
      return const MainScreen();
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkAuth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
