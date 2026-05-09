import 'package:flutter/material.dart';
import '../torr9_api.dart';
import '../cache_service.dart';
import 'login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_stats_screen.dart';
import 'settings_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool fromNetwork = false}) async {
    if (fromNetwork) {
      try {
        final token = await CacheService().getCacheEntry('auth_token');
        if (token != null) {
          final profile = await Torr9Api().getMe(token.toString());
          await CacheService().updateCacheEntry('user_profile', profile);
        }
      } catch (e) {
        if (e.toString().contains('401')) {
          _logout();
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to refresh profile: $e')),
          );
        }
      }
    }

    final profile = await CacheService().getCacheEntry('user_profile');
    if (mounted) {
      setState(() {
        if (profile is Map<String, dynamic>) {
          _profileData = profile;
        } else if (profile is Map) {
          _profileData = Map<String, dynamic>.from(profile);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await CacheService().clearCacheMap();
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  String _formatBytes(num bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  Widget _buildGlassCard({required Widget child, VoidCallback? onTap}) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.all(24.0), child: child),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profileData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No profile data found.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _logout,
              child: const Text('Back to Login'),
            ),
          ],
        ),
      );
    }

    final avatarUrl = _profileData!['avatar_url']?.toString();
    final username = _profileData!['username']?.toString() ?? 'Unknown';
    final email = _profileData!['email']?.toString() ?? '';
    final role = _profileData!['role']?.toString() ?? '';

    final downloaded = _profileData!['total_downloaded_bytes'] as num? ?? 0;
    final uploaded = _profileData!['total_uploaded_bytes'] as num? ?? 0;
    final jeton = _profileData!['jeton_balance'] as num? ?? 0;
    final freeleech = _profileData!['freeleech_tokens'] as num? ?? 0;

    double ratio = 0.0;
    if (downloaded > 0) {
      ratio = uploaded / downloaded;
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadProfile(fromNetwork: true),
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            24,
            32,
            24,
            120,
          ), // Bottom padding for glass nav bar
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ).then((_) => _loadProfile(fromNetwork: true));
                  },
                ),
              ],
            ),
            Center(
              child: Container(
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
                  radius: 64,
                  backgroundColor: const Color(0xFF1E293B),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(
                          'https://api.torr9.net/avatars/$avatarUrl',
                        )
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 64,
                          color: Colors.white54,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                username,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),

            _buildGlassCard(
              onTap: () {
                final userId = _profileData?['id'] as int?;
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserStatsScreen(userId: userId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User ID not found')),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Transfer Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.upload_rounded,
                    Colors.greenAccent,
                    'Uploaded',
                    _formatBytes(uploaded),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.download_rounded,
                    Colors.redAccent,
                    'Downloaded',
                    _formatBytes(downloaded),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.pie_chart_rounded,
                    ratio >= 1.0 ? Colors.greenAccent : Colors.orangeAccent,
                    'Ratio',
                    ratio.toStringAsFixed(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Balances',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.monetization_on_rounded,
                    Colors.amber,
                    'Jetons',
                    '${jeton.toInt()}',
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.card_giftcard_rounded,
                    Colors.purpleAccent,
                    'Freeleech Tokens',
                    '${freeleech.toInt()}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text(
                'LOGOUT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                shadowColor: Colors.transparent,
                side: BorderSide(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
