import 'dart:ui';
import 'package:flutter/material.dart';
import '../cache_service.dart';
import '../torr9_api.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await Torr9Api().login(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      final token = result['token'] ?? 'dummy_token_123';
      await CacheService().updateCacheEntry('auth_token', token);

      if (token != 'dummy_token_123') {
        try {
          final meResult = await Torr9Api().getMe(token);
          await CacheService().updateCacheEntry('user_profile', meResult);
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sleek Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
              ),
            ),
          ),
          // Decorative glowing orb 1
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              ),
            ),
          ),
          // Decorative glowing orb 2
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
              ),
            ),
          ),
          // Heavy blur layer to create glassmorphism background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),
          // Foreground Form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Torr9',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Colors.white70,
                            ),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                              ), // Red 500
                              textAlign: TextAlign.center,
                            ),
                          ),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _handleLogin,
                                child: const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
