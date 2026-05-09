import 'package:flutter/material.dart';
import '../torr9_api.dart';
import '../cache_service.dart';
import 'torrent_detail_screen.dart';
import 'exclusivity_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _torrents = [];
  List<dynamic> _trendingMovies = [];
  List<dynamic> _trendingSeries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExclusivities();
  }

  Future<void> _loadExclusivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await CacheService().getCacheEntry('auth_token');
      if (token == null) throw Exception("Not logged in");

      // For testing, if it's the dummy token, we could throw or mock.
      // Assuming testing with a real token is available now.
      final result = await Torr9Api().getExclusivities(token.toString());
      final featuredResult = await Torr9Api().getFeaturedMovies(
        token.toString(),
      );
      final featuredSeriesResult = await Torr9Api().getFeaturedSeries(
        token.toString(),
      );
      if (mounted) {
        final rawTorrents = result['torrents'] as List<dynamic>? ?? [];
        final rawFeatured = featuredResult['items'] as List<dynamic>? ?? [];
        final rawFeaturedSeries = featuredSeriesResult['items'] as List<dynamic>? ?? [];
        final Map<int, Map<String, dynamic>> grouped = {};

        for (var t in rawTorrents) {
          if (t is Map<String, dynamic>) {
            final tmdbId = t['tmdb_id'] as int?;
            if (tmdbId != null) {
              if (!grouped.containsKey(tmdbId)) {
                grouped[tmdbId] = t;
              }
            } else {
              final id = t['id'] as int;
              grouped[-id] = t;
            }
          }
        }

        setState(() {
          _torrents = grouped.values.toList();
          _trendingMovies = rawFeatured;
          _trendingSeries = rawFeaturedSeries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadExclusivities,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadExclusivities,
              child: ListView(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 120,
                ), // Bottom padding for glass nav
                children: [
                  _buildHorizontalList(
                    'Exclusivities',
                    Icons.whatshot,
                    Colors.orangeAccent,
                    _torrents,
                  ),
                  const SizedBox(height: 24),
                  _buildHorizontalList(
                    'Trending Movies',
                    Icons.movie,
                    Colors.greenAccent,
                    _trendingMovies,
                    isFeatured: true,
                  ),
                  const SizedBox(height: 24),
                  _buildHorizontalList(
                    'Trending Series',
                    Icons.tv,
                    Colors.lightBlueAccent,
                    _trendingSeries,
                    isFeatured: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHorizontalList(
    String title,
    IconData icon,
    Color iconColor,
    List<dynamic> items, {
    bool isFeatured = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280, // Card height
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final t = items[index] as Map<String, dynamic>;
              return SizedBox(
                width: 150, // Card width
                child: GestureDetector(
                  onTap: () {
                    if (title == 'Exclusivities' && t['tmdb_id'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExclusivityDetailScreen(
                            tmdbId: t['tmdb_id'] as int,
                            categoryName: t['category_name']?.toString() ?? t['parent_category_name']?.toString() ?? 'Unknown',
                            fallbackTitle: t['title']?.toString() ?? 'Unknown',
                            fallbackPosterUrl: t['poster_url']?.toString(),
                          ),
                        ),
                      );
                      return;
                    }

                    final torrentId = t['torrent_id'] ?? t['id'];
                    if (torrentId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TorrentDetailScreen(
                            torrentId: torrentId as int,
                            fallbackTitle: t['title']?.toString() ?? 'Unknown',
                            fallbackPosterUrl: t['poster_url']?.toString(),
                          ),
                        ),
                      );
                    }
                  },
                  child: isFeatured
                      ? _buildFeaturedCard(t)
                      : _buildTorrentCard(t),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTorrentCard(Map<String, dynamic> t) {
    final title = t['title']?.toString() ?? 'Unknown';
    final posterUrl = t['poster_url']?.toString();
    final seeders = t['seeders'];
    final size = t['file_size_bytes'];
    final isFreeleech = t['is_freeleech'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl != null && posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black26,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.black26,
                          child: const Icon(
                            Icons.movie,
                            size: 48,
                            color: Colors.white54,
                          ),
                        ),
                  if (isFreeleech)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Free',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (seeders != null && size != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward,
                                size: 12,
                                color: Colors.greenAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$seeders',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatBytes(size),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> t) {
    final title = t['title']?.toString() ?? 'Unknown';
    final posterUrl = t['poster_url']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            posterUrl != null && posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black26,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.black26,
                    child: const Icon(
                      Icons.movie,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
