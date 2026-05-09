import 'package:flutter/material.dart';
import '../torr9_api.dart';
import '../cache_service.dart';
import 'torrent_detail_screen.dart';

class UserStatsScreen extends StatefulWidget {
  final int userId;

  const UserStatsScreen({super.key, required this.userId});

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  Map<String, dynamic>? _aggregateStats;
  List<dynamic> _torrentStats = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _error;

  int _page = 1;
  final int _limit = 20;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchStats({bool isRefresh = true}) async {
    if (isRefresh) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _torrentStats.clear();
      });
    } else {
      if (_isFetchingMore || !_hasMore) return;
      if (!mounted) return;
      setState(() {
        _isFetchingMore = true;
      });
    }

    try {
      final token = await CacheService().getCacheEntry('auth_token');
      if (token == null) throw Exception("Not logged in");

      final res = await Torr9Api().getUserStats(
        token.toString(),
        widget.userId,
        page: _page,
        limit: _limit,
      );

      final newTorrents = res['torrent_stats'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _aggregateStats = res;
            _torrentStats = newTorrents;
          } else {
            _torrentStats.addAll(newTorrents);
          }

          _hasMore = newTorrents.length == _limit;
          if (!isRefresh) _page++;

          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  void _fetchNextPage() {
    if (!_isLoading && !_isFetchingMore && _hasMore) {
      if (_torrentStats.isNotEmpty && _page == 1) {
        _page = 2;
      }
      _fetchStats(isRefresh: false);
    }
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    final double b = double.tryParse(bytes.toString()) ?? 0;
    if (b > 1024 * 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
    }
    if (b > 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (b > 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
    if (b > 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
    return '${b.toInt()} B';
  }

  String _formatDuration(dynamic secondsStr) {
    if (secondsStr == null) return '0s';
    final int sec = int.tryParse(secondsStr.toString()) ?? 0;
    if (sec < 60) return '${sec}s';
    if (sec < 3600) return '${(sec / 60).floor()}m';
    if (sec < 86400) return '${(sec / 3600).floor()}h';
    return '${(sec / 86400).floor()}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Transfer Statistics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          color: const Color(0xFF0F172A).withValues(alpha: 0.9),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchStats(),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (_aggregateStats != null)
          SliverToBoxAdapter(
            child: _buildAggregateHeader(),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _torrentStats.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Colors.blueAccent)),
                  );
                }

                final t = _torrentStats[index];
                return _buildTorrentStatCard(t);
              },
              childCount: _torrentStats.length + (_hasMore ? 1 : 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAggregateHeader() {
    final up = _aggregateStats!['total_uploaded'];
    final down = _aggregateStats!['total_downloaded'];
    final ratio = _aggregateStats!['ratio'];
    final rank = _aggregateStats!['statistics']?['rank_position'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(
                  'Uploaded', _formatBytes(up), Icons.arrow_upward, Colors.greenAccent),
              _buildMetricColumn(
                  'Downloaded', _formatBytes(down), Icons.arrow_downward, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(
                  'Ratio',
                  (ratio is double) ? ratio.toStringAsFixed(2) : ratio.toString(),
                  Icons.pie_chart,
                  ratio is num && ratio >= 1.0 ? Colors.greenAccent : Colors.orangeAccent),
              if (rank != null)
                _buildMetricColumn(
                    'Rank', '#$rank', Icons.leaderboard, Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTorrentStatCard(Map<String, dynamic> t) {
    final title = t['torrent_title']?.toString() ?? 'Unknown';
    final up = t['total_uploaded'];
    final down = t['total_downloaded'];
    final isSeeding = t['is_seeding'] == true;
    final isCompleted = t['is_completed'] == true;
    final seedTime = t['seedtime_seconds'];
    final torrentId = t['torrent_id'];

    return GestureDetector(
      onTap: () {
        if (torrentId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TorrentDetailScreen(
                torrentId: torrentId,
                fallbackTitle: title,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 14, color: Colors.greenAccent[400]),
                      const SizedBox(width: 4),
                      Text(_formatBytes(up),
                          style: TextStyle(
                              color: Colors.greenAccent[400], fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_downward, size: 14, color: Colors.redAccent[400]),
                      const SizedBox(width: 4),
                      Text(_formatBytes(down),
                          style: TextStyle(
                              color: Colors.redAccent[400], fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      if (isSeeding)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Text('SEEDING',
                              style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isCompleted && !isSeeding)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Text('COMPLETED',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.timer, size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(_formatDuration(seedTime),
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
