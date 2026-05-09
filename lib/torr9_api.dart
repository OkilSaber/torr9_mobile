import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class Torr9Api {
  // Singleton pattern for the API wrapper
  static final Torr9Api _instance = Torr9Api._internal();
  factory Torr9Api() => _instance;
  Torr9Api._internal();

  static const String _baseUrl = 'https://api.torr9.net/api/v1';

  // We use the exact headers from your curl command to maximize the chance of
  // bypassing any WAF (like Cloudflare) that Torr9 might be using.
  Map<String, String> get _defaultHeaders => {
    // 'accept': '*/*',
    // 'accept-language': 'fr-FR,fr;q=0.7',
    'content-type': 'application/json',
    // 'origin': 'https://torr9.net',
    // 'referer': 'https://torr9.net/',
    // 'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36',
    // 'sec-ch-ua': '"Chromium";v="148", "Brave";v="148", "Not/A)Brand";v="99"',
    // 'sec-ch-ua-mobile': '?0',
    // 'sec-ch-ua-platform': '"Windows"',
    // 'sec-fetch-dest': 'empty',
    // 'sec-fetch-mode': 'cors',
    // 'sec-fetch-site': 'same-site',
    // 'sec-gpc': '1',
  };

  /// Performs a login request to the Torr9 API.
  /// Returns the parsed JSON response or throws an exception on error.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');

    final body = jsonEncode({
      'username': username,
      'password': password,
      'remember_me': true,
    });

    try {
      final response = await http.post(
        url,
        headers: _defaultHeaders,
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            throw Exception(errorData['error']);
          }
        } catch (_) {}
        throw Exception('Identifiant ou mot de passe invalide');
      } else {
        throw Exception(
          'Login failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches the current user's profile information.
  Future<Map<String, dynamic>> getMe(String token) async {
    final url = Uri.parse('$_baseUrl/users/me');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch user profile (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches exclusivities from the last N days
  Future<Map<String, dynamic>> getExclusivities(
    String token, {
    int days = 7,
  }) async {
    final url = Uri.parse('$_baseUrl/torrents/exclus?days=$days');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch exclusivities (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches featured movies
  Future<Map<String, dynamic>> getFeaturedMovies(String token) async {
    final url = Uri.parse('$_baseUrl/featured/movies');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch featured movies (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches featured series
  Future<Map<String, dynamic>> getFeaturedSeries(String token) async {
    final url = Uri.parse('$_baseUrl/featured/series');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch featured series (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches details for a specific torrent
  Future<Map<String, dynamic>> getTorrentDetails(String token, int id) async {
    final url = Uri.parse('$_baseUrl/torrents/$id');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch torrent details (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches comments for a specific torrent
  Future<Map<String, dynamic>> getTorrentComments(String token, int id) async {
    final url = Uri.parse('$_baseUrl/torrents/$id/comments');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch torrent comments (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Downloads a torrent file
  Future<Uint8List> downloadTorrent(String token, int id) async {
    final url = Uri.parse('$_baseUrl/torrents/$id/download');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      } else {
        throw Exception(
          'Failed to download torrent (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Searches for media metadata from TMDB
  Future<Map<String, dynamic>> searchMedia(
    String token, {
    required String query,
    required String category,
  }) async {
    final url = Uri.parse('$_baseUrl/torrents/search-media');

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    final body = jsonEncode({'query': query, 'category': category});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch media info (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Searches for torrents with complex filters
  Future<Map<String, dynamic>> searchTorrents(
    String token, {
    String query = '%',
    int? tmdbId,
    String? category,
    String? searchIn,
    String? sortBy,
    String? order,
    int limit = 100,
    int page = 1,
  }) async {
    String urlStr =
        '$_baseUrl/torrents/search?q=${Uri.encodeComponent(query)}&page=$page&limit=$limit';
    if (tmdbId != null) {
      urlStr += '&tmdb_id=$tmdbId';
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      urlStr += '&category=$category';
    }
    if (searchIn != null && searchIn.isNotEmpty) {
      urlStr += '&search_in=$searchIn';
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      urlStr += '&sort_by=$sortBy';
    }
    if (order != null && order.isNotEmpty) {
      urlStr += '&order=$order';
    }

    final url = Uri.parse(urlStr);

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to search torrents (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches detailed user statistics including torrent history
  Future<Map<String, dynamic>> getUserStats(
    String token,
    int userId, {
    int page = 1,
    int limit = 20,
    String sort = 'first_activity',
    String order = 'DESC',
  }) async {
    final url = Uri.parse(
      '$_baseUrl/users/$userId/stats?page=$page&limit=$limit&sort=$sort&order=$order',
    );

    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch user stats (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches the list of chat channels
  Future<List<dynamic>> getChatChannels(String token) async {
    final url = Uri.parse('$_baseUrl/chat/channels');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        throw Exception(
          'Failed to fetch chat channels (${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Fetches history for a specific chat channel
  Future<Map<String, dynamic>> getChatHistory(
    String token,
    String channelSlug,
  ) async {
    final url = Uri.parse('$_baseUrl/chat/channels/$channelSlug/messages');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to fetch chat history (${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Marks a chat channel as read
  Future<void> markChatAsRead(String token, String channelSlug) async {
    final url = Uri.parse('$_baseUrl/chat/channels/$channelSlug/read');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {}
    } catch (_) {}
  }

  /// Fetches available emojis
  Future<List<dynamic>> getEmojis(String token) async {
    final url = Uri.parse('https://torr9.net/api/emojis');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data.containsKey('emojis')) {
          return data['emojis'] as List<dynamic>;
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Updates the user's avatar
  Future<void> updateAvatar(String token, int userId, File imageFile) async {
    final url = Uri.parse('$_baseUrl/users/$userId/avatar');
    final request = http.MultipartRequest('POST', url);
    request.headers['authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar', // Common field name for avatars
        imageFile.path,
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to upload avatar (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Updates the user's adult content preference
  Future<void> updateWantPorn(String token, int userId, bool wantPorn) async {
    final url = Uri.parse('$_baseUrl/users/$userId/want-porn');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';
    headers['content-type'] = 'application/json';

    final body = jsonEncode({'want_porn': wantPorn});

    try {
      final response = await http.patch(url, headers: headers, body: body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to update adult content preference (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Updates the user's ratio visibility preference
  Future<void> updateHideRatio(String token, int userId, bool hideRatio) async {
    final url = Uri.parse('$_baseUrl/users/$userId/hide-ratio');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';
    headers['content-type'] = 'application/json';

    final body = jsonEncode({'hide_ratio': hideRatio});

    try {
      final response = await http.patch(url, headers: headers, body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to update ratio visibility (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Updates the user's citation
  Future<void> updateCitation(String token, int userId, String citation) async {
    final url = Uri.parse('$_baseUrl/users/$userId/citation');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';
    headers['content-type'] = 'application/json';

    final body = jsonEncode({'citation': citation});

    try {
      final response = await http.patch(url, headers: headers, body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to update citation (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Updates the user's email
  Future<void> updateEmail(String token, int userId, String email) async {
    final url = Uri.parse('$_baseUrl/users/$userId/email');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';
    headers['content-type'] = 'application/json';

    final body = jsonEncode({'email': email});

    try {
      final response = await http.patch(url, headers: headers, body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to update email (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Changes the user's password
  Future<void> changePassword(
    String token,
    int userId,
    String currentPassword,
    String newPassword,
  ) async {
    final url = Uri.parse('$_baseUrl/users/$userId/password');
    final headers = Map<String, String>.from(_defaultHeaders);
    headers['authorization'] = 'Bearer $token';
    headers['content-type'] = 'application/json';

    final body = jsonEncode({
      'current_password': currentPassword,
      'new_password': newPassword,
    });

    try {
      final response = await http.patch(url, headers: headers, body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to change password (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
