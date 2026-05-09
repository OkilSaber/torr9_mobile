import 'package:flutter/material.dart';
import '../torr9_api.dart';
import '../cache_service.dart';
import 'torrent_detail_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _torrents = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _error;
  
  int _page = 1;
  final int _limit = 25;
  String _query = '';
  
  String _selectedCategory = 'all';
  String _selectedSearchIn = 'all';
  String _selectedSortBy = 'created_at';
  String _selectedOrder = 'desc';

  final List<String> _categories = [
    'all', 'film', 'tv', 'audio', 'book', 'game', 'app', 'nulled', 'emulation', 'impressions-3d', 'vo', 'xxx'
  ];

  final Map<String, String> _searchInOptions = {
    'all': 'All',
    'title': 'Title',
    'description': 'Description',
    'tags': 'Tags'
  };

  final Map<String, String> _sortByOptions = {
    'created_at': 'Date Added',
    'times_completed': 'Completed',
    'seeders': 'Seeders',
    'leechers': 'Leechers',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _performSearch(); // Initial load (like a 'latest' feed)
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
  }

  Future<void> _performSearch({bool isRefresh = true}) async {
    if (isRefresh) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _torrents.clear();
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

      final apiQuery = _query.trim().isEmpty ? '%' : _query.trim();

      final res = await Torr9Api().searchTorrents(
        token.toString(),
        query: apiQuery,
        category: _selectedCategory,
        searchIn: _selectedSearchIn == 'all' ? null : _selectedSearchIn,
        sortBy: _selectedSortBy,
        order: _selectedOrder,
        limit: _limit,
        page: _page,
      );

      final newTorrents = res['torrents'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _torrents = newTorrents;
          } else {
            _torrents.addAll(newTorrents);
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
      // Temporarily increment page here to fetch the right one
      if (_torrents.isNotEmpty && _page == 1) {
         _page = 2; 
      }
      _performSearch(isRefresh: false);
    }
  }

  void _onSearchSubmit(String value) {
    _query = value;
    FocusScope.of(context).unfocus(); // hide keyboard
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildSearchHeader(),
          _buildFilters(),
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search torrents...',
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchSubmit('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (val) => setState(() {}), // Just to update suffix icon
          onSubmitted: _onSearchSubmit,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              // Category Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CATEGORY', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                      underline: const SizedBox(),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedCategory) {
                          setState(() => _selectedCategory = val);
                          _performSearch();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Search In Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SEARCH IN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSearchIn,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                      underline: const SizedBox(),
                      items: _searchInOptions.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedSearchIn) {
                          setState(() => _selectedSearchIn = val);
                          _performSearch();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Sort By & Order
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Sort By Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SORT BY', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSortBy,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                      underline: const SizedBox(),
                      items: _sortByOptions.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedSortBy) {
                          setState(() => _selectedSortBy = val);
                          _performSearch();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Order Toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('ORDER', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(
                      _selectedOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
                      color: Colors.white54,
                      size: 20,
                    ),
                    tooltip: _selectedOrder == 'desc' ? 'Descending' : 'Ascending',
                    onPressed: () {
                      setState(() {
                        _selectedOrder = _selectedOrder == 'desc' ? 'asc' : 'desc';
                      });
                      _performSearch();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    if (_error != null) {
      return Center(
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
                onPressed: () => _performSearch(),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }
    if (_torrents.isEmpty) {
      return const Center(
        child: Text('No torrents found.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120, top: 8),
      itemCount: _torrents.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _torrents.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }

        final t = _torrents[index];
        final title = t['title']?.toString() ?? 'Unknown';
        final seeders = t['seeders'];
        final size = t['file_size_bytes'];
        final age = t['age']?.toString() ?? 'Unknown age';

        // Calculate size in GB or MB
        String sizeStr = '';
        if (size != null) {
          final bytes = double.tryParse(size.toString()) ?? 0;
          if (bytes > 1024 * 1024 * 1024) {
            sizeStr = '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
          } else {
            sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, size: 14, color: Colors.greenAccent[400]),
                  const SizedBox(width: 4),
                  Text('$seeders', style: TextStyle(color: Colors.greenAccent[400], fontSize: 12)),
                  const SizedBox(width: 16),
                  const Icon(Icons.storage, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(sizeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(age, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TorrentDetailScreen(
                    torrentId: t['id'],
                    fallbackTitle: title,
                    fallbackPosterUrl: t['poster_url']?.toString(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
