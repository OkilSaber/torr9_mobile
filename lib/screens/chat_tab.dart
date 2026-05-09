import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../cache_service.dart';
import '../torr9_api.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSubscription;
  Timer? _reconnectTimer;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _disposed = false; // set before super.dispose() to guard async callbacks
  String _currentChannelSlug = 'general';
  List<dynamic> _availableChannels = [];
  Map<String, String> _emojiMap = {};
  String? _token;
  ChatMessage? _replyingTo; // message currently being replied to
  bool _showEmojiPicker = false;
  List<Map<String, String>> _filteredEmojis = [];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _initializeChat();
  }

  @override
  void dispose() {
    _disposed = true; // must be first so async callbacks bail out
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel(); // stop WebSocket callbacks before sink.close
    _channel?.sink.close();
    _inputFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;

    if (!selection.isCollapsed || selection.baseOffset <= 0) {
      if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
      return;
    }

    final pos = selection.baseOffset;

    // Look backwards from cursor for the nearest ':'
    int colonPos = -1;
    for (int i = pos - 1; i >= 0; i--) {
      if (text[i] == ':') {
        colonPos = i;
        break;
      }
      // Stop if we hit a space - an emoji query cannot contain spaces
      if (text[i] == ' ') break;
    }

    if (colonPos != -1) {
      final query = text.substring(colonPos + 1, pos).toLowerCase();
      final allMatches = _emojiMap.entries
          .where((e) => e.key.contains(query))
          .toList();

      // Sort matches:
      // 1. Prioritize those that start with the query
      // 2. Then sort alphabetically
      allMatches.sort((a, b) {
        final aStarts = a.key.startsWith(query);
        final bStarts = b.key.startsWith(query);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return a.key.compareTo(b.key);
      });

      final filtered = allMatches
          .map((e) => {'name': e.key, 'file': e.value})
          .toList();

      if (mounted) {
        setState(() {
          _filteredEmojis = filtered;
          _showEmojiPicker = filtered.isNotEmpty;
        });
      }
    } else {
      if (_showEmojiPicker && mounted) {
        setState(() => _showEmojiPicker = false);
      }
    }
  }

  void _insertEmoji(String emojiName) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final pos = selection.baseOffset;

    // Find the starting colon again to replace the exact range
    int colonPos = -1;
    for (int i = pos - 1; i >= 0; i--) {
      if (text[i] == ':') {
        colonPos = i;
        break;
      }
      if (text[i] == ' ') break;
    }

    if (colonPos != -1) {
      final newText = text.replaceRange(colonPos, pos, ':$emojiName: ');

      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: colonPos + emojiName.length + 3,
        ),
      );
    }

    if (mounted) {
      setState(() => _showEmojiPicker = false);
    }
    _inputFocusNode.requestFocus();
  }

  Widget _buildEmojiPicker() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredEmojis.length,
        itemBuilder: (context, index) {
          final emoji = _filteredEmojis[index];
          return ListTile(
            dense: true,
            leading: CachedNetworkImage(
              imageUrl: 'https://torr9.net/emochat/${emoji['file']}',
              width: 24,
              height: 24,
              placeholder: (_, __) => const SizedBox(width: 24, height: 24),
            ),
            title: Text(
              ':${emoji['name']}:',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            onTap: () => _insertEmoji(emoji['name']!),
          );
        },
      ),
    );
  }

  Future<void> _initializeChat() async {
    _token = (await CacheService().getCacheEntry('auth_token'))?.toString();
    if (_token == null) return;

    await Future.wait([_loadChannels(), _loadEmojis()]);

    _connect();
    _loadHistory(_currentChannelSlug);
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await Torr9Api().getChatChannels(_token!);
      if (!_disposed && mounted) {
        setState(() {
          _availableChannels = channels;
          if (channels.isNotEmpty) {
            _currentChannelSlug = channels[0]['slug'];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEmojis() async {
    try {
      final emojis = await Torr9Api().getEmojis(_token!);
      final Map<String, String> map = {};
      for (var e in emojis) {
        final fileName = e.toString();
        final name =
            (fileName.contains('.')
                    ? fileName.substring(0, fileName.lastIndexOf('.'))
                    : fileName)
                .toLowerCase()
                .trim();
        map[name] = fileName;
      }
      if (!_disposed && mounted) {
        setState(() => _emojiMap = map);
      }
    } catch (_) {}
  }

  Future<void> _loadHistory(String slug) async {
    try {
      final history = await Torr9Api().getChatHistory(_token!, slug);
      final List<dynamic> msgs = history['messages'] ?? [];
      if (!_disposed && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            msgs.map((m) => ChatMessage.fromJson(m)).toList().reversed,
          );
        });
      }
      Torr9Api().markChatAsRead(_token!, slug);
    } catch (_) {}
  }

  void _connect() {
    if (_token == null || !mounted) return;

    try {
      final uri = Uri.parse(
        'wss://torr9.net/socket.io/?EIO=4&transport=websocket',
      );
      _channel = WebSocketChannel.connect(uri);

      _wsSubscription = _channel!.stream.listen(
        (data) {
          if (!_disposed) _handleIncomingData(data.toString());
        },
        onDone: () {
          if (!_disposed && mounted) {
            setState(() => _isConnected = false);
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(const Duration(seconds: 5), () {
              if (!_disposed && mounted) _connect();
            });
          }
        },
        onError: (err) {
          if (!_disposed && mounted) {
            setState(() => _isConnected = false);
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(const Duration(seconds: 5), () {
              if (!_disposed && mounted) _connect();
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!_disposed && mounted) {
        setState(() => _isConnected = false);
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 5), () {
          if (!_disposed && mounted) _connect();
        });
      }
    }
  }

  void _handleIncomingData(String data) {
    if (data.startsWith('0')) {
      _channel?.sink.add('40');
    } else if (data.startsWith('40')) {
      _channel?.sink.add('42["authenticate","$_token"]');
    } else if (data.startsWith('42')) {
      final eventData = jsonDecode(data.substring(2));
      if (eventData is List && eventData.isNotEmpty) {
        final eventName = eventData[0];
        if (eventName == 'authenticated') {
          if (!_disposed && mounted) {
            setState(() => _isConnected = true);
          }
          _joinChannel(_currentChannelSlug);
        } else if (eventName == 'chat:channel:message') {
          final msg = ChatMessage.fromJson(eventData[1]);
          if (msg.channelId == _getCurrentChannelId()) {
            _addMessage(msg);
          }
        }
      }
    } else if (data == '2') {
      _channel?.sink.add('3');
    }
  }

  int? _getCurrentChannelId() {
    for (var c in _availableChannels) {
      if (c['slug'] == _currentChannelSlug) return c['id'];
    }
    return null;
  }

  void _joinChannel(String slug) {
    final msg = '42["chat:channel:join","$slug"]';
    _channel?.sink.add(msg);
  }

  void _leaveChannel(String slug) {
    final msg = '42["chat:channel:leave","$slug"]';
    _channel?.sink.add(msg);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && _isConnected) {
      final payload = <String, dynamic>{
        'channel': _currentChannelSlug,
        'content': text,
        if (_replyingTo != null) 'reply_to_id': _replyingTo!.id,
      };
      _channel?.sink.add('42["chat:channel:message",${jsonEncode(payload)}]');
      _messageController.clear();
      if (mounted) setState(() => _replyingTo = null);
    }
  }

  void _addMessage(ChatMessage msg) {
    if (mounted) {
      setState(() => _messages.insert(0, msg));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            if (_currentChannelSlug != 'annonces') _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          _isConnected
              ? const Icon(Icons.bolt, color: Colors.greenAccent, size: 16)
              : const Icon(Icons.bolt, color: Colors.redAccent, size: 16),
          const SizedBox(width: 12),
          if (_availableChannels.isNotEmpty)
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentChannelSlug,
                  dropdownColor: const Color(0xFF1E293B),
                  isDense: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white38,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  items: _availableChannels.map((c) {
                    return DropdownMenuItem(
                      value: c['slug'].toString(),
                      child: Text('# ${c['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _currentChannelSlug) {
                      _leaveChannel(_currentChannelSlug);
                      if (mounted) {
                        setState(() => _currentChannelSlug = val);
                      }
                      _joinChannel(val);
                      _loadHistory(val);
                    }
                  },
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white38, size: 20),
            onPressed: () {
              _channel?.sink.close();
              _connect();
              _loadHistory(_currentChannelSlug);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty && _isConnected) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(color: Colors.white24)),
      );
    }
    if (_messages.isEmpty && !_isConnected) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final bool isReplyingToThis = _replyingTo?.id == msg.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () {
            if (mounted) {
              setState(() => _replyingTo = msg);
              _inputFocusNode.requestFocus();
            }
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.blueAccent.withValues(alpha: 0.1),
          highlightColor: Colors.blueAccent.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isReplyingToThis
                  ? Colors.blueAccent.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isReplyingToThis
                    ? Colors.blueAccent.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white10,
                  backgroundImage:
                      (msg.avatarUrl != null && msg.avatarUrl != 'default.jpg')
                      ? CachedNetworkImageProvider(
                          'https://api.torr9.net/avatars/${msg.avatarUrl}',
                        )
                      : null,
                  child:
                      (msg.avatarUrl == null || msg.avatarUrl == 'default.jpg')
                      ? const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white54,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.replyTo != null) _buildReplyPreview(msg.replyTo!),
                      Row(
                        children: [
                          Text(
                            msg.username,
                            style: TextStyle(
                              color: _getRoleColor(msg.role),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(msg.timestamp),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      _buildMessageContent(msg.content),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: const Border(left: BorderSide(color: Colors.white24, width: 2)),
      ),
      child: Text(
        'Replying to @${reply['username']}: ${reply['content']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildMessageContent(String content) {
    // Build a quick username → role lookup from all visible messages so we can
    // color @mentions the same as the mentioned user's name.
    final Map<String, String?> usernameRoles = {
      for (final m in _messages) m.username.toLowerCase(): m.role,
    };

    final List<InlineSpan> spans = [];

    final imgRegex = RegExp(r'\[img\](.*?)\[/img\]', caseSensitive: false);
    // Single combined regex: group 1 = emoji name, group 2 = mention username
    final tokenRegex = RegExp(r':([a-zA-Z0-9_-]+):|@([a-zA-Z0-9_]+)');

    // Replace [img] tags with indexed placeholders first.
    final List<String> imgUrls = [];
    final String currentText = content.splitMapJoin(
      imgRegex,
      onMatch: (m) {
        imgUrls.add(m.group(1)!);
        return 'IMG_PLACEHOLDER_${imgUrls.length - 1}_';
      },
      onNonMatch: (n) => n,
    );

    int lastMatchEnd = 0;
    for (final Match match in tokenRegex.allMatches(currentText)) {
      // Flush plain text before this token.
      if (match.start > lastMatchEnd) {
        _addTextWithImages(
          currentText.substring(lastMatchEnd, match.start),
          spans,
          imgUrls,
        );
      }

      if (match.group(1) != null) {
        // ─── :emoji: ───
        final emojiName = match.group(1)!;
        final emojiKey = emojiName.toLowerCase();
        if (_emojiMap.containsKey(emojiKey)) {
          final emojiFile = _emojiMap[emojiKey]!;
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: CachedNetworkImage(
                width: 20,
                height: 20,
                imageUrl: 'https://torr9.net/emochat/$emojiFile',
                errorWidget: (_, _, _) => Text(':$emojiName:'),
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: ':$emojiName:'));
        }
      } else if (match.group(2) != null) {
        // ─── @mention ───
        final username = match.group(2)!;
        final role = usernameRoles[username.toLowerCase()];
        spans.add(
          TextSpan(
            text: '@$username',
            style: TextStyle(
              color: _getRoleColor(role),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    // Flush any remaining text after the last token.
    if (lastMatchEnd < currentText.length) {
      _addTextWithImages(currentText.substring(lastMatchEnd), spans, imgUrls);
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        children: spans,
      ),
    );
  }

  void _addTextWithImages(
    String text,
    List<InlineSpan> spans,
    List<String> imgUrls,
  ) {
    final parts = text.split(RegExp(r'IMG_PLACEHOLDER_(\d+)_'));
    final matches = RegExp(r'IMG_PLACEHOLDER_(\d+)_').allMatches(text).toList();

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        String decoded = parts[i]
            .replaceAll('&#39;', "'")
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>');
        spans.add(TextSpan(text: decoded));
      }
      if (i < matches.length) {
        final index = int.parse(matches[i].group(1)!);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 100,
                  width: 140,
                  child: CachedNetworkImage(
                    imageUrl: imgUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Colors.redAccent;
      case 'modérateur':
        return Colors.greenAccent;
      case 'uploader':
        return Colors.orangeAccent;
      case 'releaser':
        return Colors.purpleAccent;
      case 'userplus':
        return Colors.blueAccent;
      default:
        return Colors.white70;
    }
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Emoji Autocomplete ────────────────────────────────────
          if (_showEmojiPicker && _filteredEmojis.isNotEmpty)
            _buildEmojiPicker(),

          // ── Reply banner ──────────────────────────────────────────
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                border: Border(
                  top: BorderSide(
                    color: Colors.blueAccent.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to @${_replyingTo!.username}: ${_replyingTo!.content}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          // ── Text input row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      focusNode: _inputFocusNode,
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final int id;
  final int? channelId;
  final String username;
  final String content;
  final String? avatarUrl;
  final String? role;
  final DateTime timestamp;
  final Map<String, dynamic>? replyTo;

  ChatMessage({
    required this.id,
    this.channelId,
    required this.username,
    required this.content,
    this.avatarUrl,
    this.role,
    required this.timestamp,
    this.replyTo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      channelId: json['channel_id'],
      username: json['username'] ?? 'Unknown',
      content: json['content'] ?? '',
      avatarUrl: json['avatar_url'],
      role: json['role'],
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      replyTo: json['reply_to'],
    );
  }
}
