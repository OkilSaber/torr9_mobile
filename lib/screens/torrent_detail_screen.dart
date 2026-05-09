import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../torr9_api.dart';
import '../cache_service.dart';

class TorrentDetailScreen extends StatefulWidget {
  final int torrentId;
  final String fallbackTitle;
  final String? fallbackPosterUrl;

  const TorrentDetailScreen({
    super.key,
    required this.torrentId,
    required this.fallbackTitle,
    this.fallbackPosterUrl,
  });

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen> {
  Map<String, dynamic>? _details;
  List<dynamic>? _comments;
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final token = await CacheService().getCacheEntry('auth_token');
      if (token == null) throw Exception("Not logged in");

      final detailsResult = await Torr9Api().getTorrentDetails(
        token.toString(),
        widget.torrentId,
      );
      final commentsResult = await Torr9Api().getTorrentComments(
        token.toString(),
        widget.torrentId,
      );

      if (mounted) {
        setState(() {
          _details = detailsResult;
          _comments = commentsResult['comments'] as List<dynamic>? ?? [];
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

  Future<void> _downloadTorrent() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final token = await CacheService().getCacheEntry('auth_token');
      if (token == null) throw Exception("Not logged in");

      final bytes = await Torr9Api().downloadTorrent(
        token.toString(),
        widget.torrentId,
      );

      final title =
          _details!['title']?.toString().replaceAll(
            RegExp(r'[\\/:*?"<>|]'),
            '_',
          ) ??
          'torrent';
      final fileName = '$title.torrent';

      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }

        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        if (status.isGranted) {
          final directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(bytes);
        } else {
          throw Exception(
            "Storage permission denied. Please grant 'All files access' in App Settings.",
          );
        }
      } else {
        await FileSaver.instance.saveFile(
          name: title,
          bytes: bytes,
          fileExtension: 'torrent',
          mimeType: MimeType.other,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Saved to your downloads folder',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 0,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
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

  String _stripBbCode(String text) {
    // Basic regex to strip most BBCode tags
    return text.replaceAll(
      RegExp(
        r'\[\/?(?:b|i|u|s|url|img|quote|code|size|color|center|left|right)[^\]]*\]',
        caseSensitive: false,
      ),
      '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: _details != null
          ? FloatingActionButton.extended(
              onPressed: _isDownloading ? null : _downloadTorrent,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isDownloading ? 'Downloading...' : 'Download Torrent',
              ),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            )
          : null,
      appBar: AppBar(
        title: Text(
          widget.fallbackTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
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
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final title = _details!['title']?.toString() ?? widget.fallbackTitle;
    final size = _details!['file_size_bytes'] ?? 0;
    final seeders = _details!['seeders'] ?? 0;
    final leechers = _details!['leechers'] ?? 0;
    final views = _details!['views'] ?? 0;
    final completed = _details!['times_completed'] ?? 0;
    final uploaderName = _details!['uploader_name']?.toString() ?? 'Unknown';
    final rawDescription = _details!['description']?.toString() ?? '';
    final description = _stripBbCode(rawDescription).trim();

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
        bottom: 32,
        left: 24,
        right: 24,
      ),
      children: [
        if (widget.fallbackPosterUrl != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: widget.fallbackPosterUrl!,
                height: 300,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildStatsGrid(seeders, leechers, size, views, completed),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Uploaded by $uploaderName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildDescriptionWithImages(description),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_comments!.isEmpty)
          const Text(
            'No comments yet.',
            style: TextStyle(color: Colors.white54),
          )
        else
          ..._comments!.map(
            (c) => _buildCommentCard(c as Map<String, dynamic>),
          ),
      ],
    );
  }

  Widget _buildStatsGrid(
    dynamic seeders,
    dynamic leechers,
    dynamic size,
    dynamic views,
    dynamic completed,
  ) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatItem(
          Icons.arrow_upward,
          Colors.greenAccent,
          'Seeders',
          '$seeders',
        ),
        _buildStatItem(
          Icons.arrow_downward,
          Colors.redAccent,
          'Leechers',
          '$leechers',
        ),
        _buildStatItem(
          Icons.sd_storage,
          Colors.blueAccent,
          'Size',
          _formatBytes(size),
        ),
        _buildStatItem(
          Icons.remove_red_eye,
          Colors.orangeAccent,
          'Views',
          '$views',
        ),
        _buildStatItem(
          Icons.check_circle,
          Colors.purpleAccent,
          'Completed',
          '$completed',
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> c) {
    final username = c['username']?.toString() ?? 'Unknown';
    final content = c['content']?.toString() ?? '';
    final avatarUrl = c['avatar_url']?.toString();
    final role = c['role']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            backgroundImage:
                (avatarUrl != null &&
                    avatarUrl.isNotEmpty &&
                    avatarUrl != 'default.jpg')
                ? CachedNetworkImageProvider(
                    'https://api.torr9.net/avatars/$avatarUrl',
                  )
                : null,
            child:
                (avatarUrl == null ||
                    avatarUrl.isEmpty ||
                    avatarUrl == 'default.jpg')
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (role.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionWithImages(String description) {
    if (description.isEmpty) return const SizedBox.shrink();

    final RegExp imageRegex = RegExp(
      r'https?://[^\s]+?\.(?:jpg|jpeg|gif|png|webp|bmp)(?:\?[^\s]*)?',
      caseSensitive: false,
    );

    final List<Widget> children = [];
    int lastMatchEnd = 0;

    final Iterable<Match> matches = imageRegex.allMatches(description);

    if (matches.isEmpty) {
      return Text(
        description,
        style: const TextStyle(color: Colors.white70, height: 1.5),
      );
    }

    for (final Match match in matches) {
      // Add text before the image
      if (match.start > lastMatchEnd) {
        final textPart = description
            .substring(lastMatchEnd, match.start)
            .trim();
        if (textPart.isNotEmpty) {
          children.add(
            Text(
              textPart,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          );
        }
      }

      // Add the image
      final String imageUrl = match.group(0)!;
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < description.length) {
      final textPart = description.substring(lastMatchEnd).trim();
      if (textPart.isNotEmpty) {
        children.add(
          Text(
            textPart,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
