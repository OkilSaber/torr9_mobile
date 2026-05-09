import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../torr9_api.dart';
import '../cache_service.dart';
import 'torrent_detail_screen.dart';

class ExclusivityDetailScreen extends StatefulWidget {
  final int tmdbId;
  final String categoryName;
  final String fallbackTitle;
  final String? fallbackPosterUrl;

  const ExclusivityDetailScreen({
    super.key,
    required this.tmdbId,
    required this.categoryName,
    required this.fallbackTitle,
    this.fallbackPosterUrl,
  });

  @override
  State<ExclusivityDetailScreen> createState() => _ExclusivityDetailScreenState();
}

class _ExclusivityDetailScreenState extends State<ExclusivityDetailScreen> {
  Map<String, dynamic>? _mediaInfo;
  List<dynamic> _torrents = [];
  bool _isLoading = true;
  String? _error;

  // Grouped torrents: Map<SeasonString, Map<QualityString, List<Torrent>>>
  // If it's a movie, it will just use a default season key like 'Movie'.
  final Map<String, Map<String, List<dynamic>>> _groupedTorrents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _apiCategory {
    final cat = widget.categoryName.toLowerCase();
    if (cat.contains('série') || cat.contains('tv')) {
      return 'tv';
    }
    return 'movie';
  }

  Future<void> _loadData() async {
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      if (token == null) throw Exception("Not logged in");

      // 1. Fetch Media Info
      final mediaRes = await Torr9Api().searchMedia(
        token.toString(),
        query: 'tmdb:${widget.tmdbId}',
        category: _apiCategory,
      );

      if (mediaRes['results'] != null && (mediaRes['results'] as List).isNotEmpty) {
        _mediaInfo = mediaRes['results'][0];
      }

      // 2. Fetch Torrents for this TMDB ID
      final torrentsRes = await Torr9Api().searchTorrents(
        token.toString(),
        tmdbId: widget.tmdbId,
        category: _apiCategory,
        limit: 100,
      );

      _torrents = torrentsRes['torrents'] ?? [];
      _groupTorrents();

      if (mounted) {
        setState(() {
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

  void _groupTorrents() {
    _groupedTorrents.clear();

    for (var t in _torrents) {
      final List<dynamic> tags = t['tags'] ?? [];
      final tagsLower = tags.map((e) => e.toString().toLowerCase()).toList();

      // Find Season (e.g., "s01", "s01e02")
      String seasonKey = 'Movie';
      final seasonTagRegExp = RegExp(r'[sS]\d{2}');
      
      // Check tags first
      for (var tag in tagsLower) {
        final match = seasonTagRegExp.firstMatch(tag);
        if (match != null) {
          seasonKey = match.group(0)!.toUpperCase(); // "S01"
          break;
        }
      }

      // If not found in tags, check the title!
      if (seasonKey == 'Movie') {
        final title = t['title']?.toString() ?? '';
        final match = seasonTagRegExp.firstMatch(title);
        if (match != null) {
          seasonKey = match.group(0)!.toUpperCase();
        }
      }

      // If no season tag found but category strongly indicates TV
      if (seasonKey == 'Movie' && _apiCategory == 'tv') {
        seasonKey = 'Unknown Season';
      }

      // Find Quality (e.g., 720p, 1080p, 2160p, 4k)
      String qualityKey = 'SD';
      if (tagsLower.contains('2160p') || tagsLower.contains('4k')) {
        qualityKey = '4K / 2160p';
      } else if (tagsLower.contains('1080p')) {
        qualityKey = '1080p';
      } else if (tagsLower.contains('720p')) {
        qualityKey = '720p';
      }

      // Initialize map structure
      if (!_groupedTorrents.containsKey(seasonKey)) {
        _groupedTorrents[seasonKey] = {};
      }
      if (!_groupedTorrents[seasonKey]!.containsKey(qualityKey)) {
        _groupedTorrents[seasonKey]![qualityKey] = [];
      }

      _groupedTorrents[seasonKey]![qualityKey]!.add(t);
    }

    // Sort seasons
    final sortedKeys = _groupedTorrents.keys.toList()..sort();
    final sortedMap = <String, Map<String, List<dynamic>>>{};
    for (var k in sortedKeys) {
      sortedMap[k] = _groupedTorrents[k]!;
    }
    _groupedTorrents.clear();
    _groupedTorrents.addAll(sortedMap);
  }

  @override
  Widget build(BuildContext context) {
    final title = _mediaInfo?['title']?.toString() ?? widget.fallbackTitle;
    final posterUrl = _mediaInfo?['poster_url']?.toString() ?? widget.fallbackPosterUrl;
    final rating = _mediaInfo?['rating']?.toString();
    final desc = _mediaInfo?['description']?.toString() ?? 'No description available.';
    final year = _mediaInfo?['year']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _loadData();
                          },
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 300,
                      pinned: true,
                      backgroundColor: const Color(0xFF0F172A),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (posterUrl != null)
                              CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    Container(color: Colors.black26),
                              ),
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Color(0xFF0F172A)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (rating != null) ...[
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating,
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (year != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                year,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              desc,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Available Torrents',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_groupedTorrents.isEmpty)
                              const Text(
                                'No torrents found.',
                                style: TextStyle(color: Colors.white54),
                              )
                            else
                              _buildSeasonsAccordion(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSeasonsAccordion() {
    // If it's a movie, skip the outer "Season" accordion
    if (_groupedTorrents.length == 1 && _groupedTorrents.containsKey('Movie')) {
      return Column(
        children: _buildQualitiesList(_groupedTorrents['Movie']!, isNested: false),
      );
    }

    return Column(
      children: _groupedTorrents.entries.map((seasonEntry) {
        final seasonName = seasonEntry.key;
        final qualitiesMap = seasonEntry.value;

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ExpansionTile(
              collapsedIconColor: Colors.white54,
              iconColor: Colors.blueAccent,
              title: Text(
                seasonName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              children: _buildQualitiesList(qualitiesMap, isNested: true),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildQualitiesList(Map<String, List<dynamic>> qualitiesMap, {bool isNested = false}) {
    return qualitiesMap.entries.map((qualityEntry) {
      final qualityName = qualityEntry.key;
      final torrentsList = qualityEntry.value;

      return Container(
        margin: EdgeInsets.only(
          left: isNested ? 16 : 0,
          right: isNested ? 16 : 0,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedIconColor: Colors.white54,
            iconColor: Colors.greenAccent,
            title: Text(
              qualityName,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: torrentsList.map((t) {
              return ListTile(
                title: Text(
                  t['title']?.toString() ?? 'Unknown Torrent',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${t['age']} • ${t['seeders']} Seeders',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TorrentDetailScreen(
                        torrentId: t['id'],
                        fallbackTitle: t['title']?.toString() ?? 'Unknown',
                        fallbackPosterUrl: _mediaInfo?['poster_url']?.toString(),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }
}
