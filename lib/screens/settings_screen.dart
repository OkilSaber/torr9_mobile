import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../cache_service.dart';
import '../torr9_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _adultContent = false;
  bool _hideRatio = false;
  final TextEditingController _citationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSaving = false;
  Map<String, dynamic>? _profileData;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    final isVisible = bottomInset > 0;
    
    // Only unfocus if the keyboard was previously visible and is now hidden
    if (_isKeyboardVisible && !isVisible && mounted) {
      FocusScope.of(context).unfocus();
    }
    
    _isKeyboardVisible = isVisible;
  }

  Future<void> _loadInitialData() async {
    final profile = await CacheService().getCacheEntry('user_profile');
    if (profile is Map && mounted) {
      setState(() {
        _profileData = Map<String, dynamic>.from(profile);
        _emailController.text = _profileData?['email']?.toString() ?? '';
        _citationController.text = _profileData?['citation']?.toString() ?? '';

        // Use exact properties from the provided cache structure
        _adultContent = _profileData?['want_porn'] == true;
        _hideRatio = _profileData?['hide_ratio'] == true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _citationController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isSaving = true);

    try {
      final token = await CacheService().getCacheEntry('auth_token');
      final userId = _profileData?['id'];

      if (token != null && userId != null) {
        await Torr9Api().updateAvatar(
          token.toString(),
          userId as int,
          File(image.path),
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully!')),
        );
        // Re-fetch profile to update local cache and UI
        final newProfile = await Torr9Api().getMe(token.toString());
        await CacheService().updateCacheEntry('user_profile', newProfile);

        if (!mounted) return;
        await _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload avatar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updateAdultContent(bool val) async {
    setState(() => _adultContent = val);
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      final userId = _profileData?['id'];
      if (token != null && userId != null) {
        await Torr9Api().updateWantPorn(token.toString(), userId as int, val);
        final newProfile = await Torr9Api().getMe(token.toString());
        await CacheService().updateCacheEntry('user_profile', newProfile);
      }
    } catch (e) {
      _showError('Failed to update: $e');
      setState(() => _adultContent = !val);
    }
  }

  Future<void> _updateHideRatio(bool val) async {
    setState(() => _hideRatio = val);
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      final userId = _profileData?['id'];
      if (token != null && userId != null) {
        await Torr9Api().updateHideRatio(token.toString(), userId as int, val);
        final newProfile = await Torr9Api().getMe(token.toString());
        await CacheService().updateCacheEntry('user_profile', newProfile);
      }
    } catch (e) {
      _showError('Failed to update: $e');
      setState(() => _hideRatio = !val);
    }
  }

  Future<void> _updateCitation() async {
    setState(() => _isSaving = true);
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      final userId = _profileData?['id'];
      if (token != null && userId != null) {
        await Torr9Api().updateCitation(
          token.toString(),
          userId as int,
          _citationController.text,
        );
        _showSuccess('Citation updated!');
        final newProfile = await Torr9Api().getMe(token.toString());
        await CacheService().updateCacheEntry('user_profile', newProfile);
      }
    } catch (e) {
      _showError('Failed to update citation: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateEmail() async {
    setState(() => _isSaving = true);
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      final userId = _profileData?['id'];
      if (token != null && userId != null) {
        await Torr9Api().updateEmail(
          token.toString(),
          userId as int,
          _emailController.text,
        );
        _showSuccess('Email updated!');
        final newProfile = await Torr9Api().getMe(token.toString());
        await CacheService().updateCacheEntry('user_profile', newProfile);
      }
    } catch (e) {
      _showError('Failed to update email: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitPasswordChange() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      final userId = _profileData?['id'];
      final username = _profileData?['username']?.toString();

      if (token != null && userId != null && username != null) {
        // 1. Change the password
        await Torr9Api().changePassword(
          token.toString(),
          userId as int,
          _currentPasswordController.text,
          _newPasswordController.text,
        );

        // 2. Automatically login with the new password to update the token
        final loginResponse = await Torr9Api().login(
          username: username,
          password: _newPasswordController.text,
        );

        final newToken = loginResponse['token'];
        if (newToken != null) {
          await CacheService().updateCacheEntry('auth_token', newToken);

          // 3. Re-fetch profile with the new token
          final newProfile = await Torr9Api().getMe(newToken.toString());
          await CacheService().updateCacheEntry('user_profile', newProfile);
        }

        _showSuccess('Password changed and session updated!');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      _showError('Failed to change password: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 24),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.all(20.0), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF1E293B),
                            backgroundImage: (_profileData?['avatar_url'] !=
                                    null)
                                ? NetworkImage(
                                    'https://api.torr9.net/avatars/${_profileData!['avatar_url']}',
                                  )
                                : null,
                            child: (_profileData?['avatar_url'] == null)
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white24,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _uploadAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0F172A),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionTitle('Preferences'),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Adult Content',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          subtitle: const Text(
                            'Show NSFW results',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          value: _adultContent,
                          onChanged: _updateAdultContent,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(color: Colors.white10),
                        SwitchListTile(
                          title: const Text(
                            'Hide Ratio',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          subtitle: const Text(
                            'Don\'t show your ratio to others',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          value: _hideRatio,
                          onChanged: _updateHideRatio,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  _buildSectionTitle('Profile Info'),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _citationController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Citation',
                            alignLabelWithHint: true,
                            hintText: 'Write something about yourself...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _updateCitation,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('Update Citation'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _updateEmail,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('Update Email'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionTitle('Security'),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.lock_reset, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(
                              Icons.check_circle_outline,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _submitPasswordChange,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Change Password'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
