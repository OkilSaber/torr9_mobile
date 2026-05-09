import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  static const String _mapCacheKey = 'app_cache_map';

  /// Initializes the SharedPreferences instance. Should be called before using the service.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Gets the entire persistent map from cache
  Future<Map<String, dynamic>> getCacheMap() async {
    if (_prefs == null) await init();
    final String? jsonString = _prefs!.getString(_mapCacheKey);
    if (jsonString != null) {
      try {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  /// Sets the entire map to cache
  Future<bool> setCacheMap(Map<String, dynamic> map) async {
    if (_prefs == null) await init();
    final String jsonString = jsonEncode(map);
    return await _prefs!.setString(_mapCacheKey, jsonString);
  }

  /// Updates a single key-value pair in the persistent map
  Future<bool> updateCacheEntry(String key, dynamic value) async {
    final map = await getCacheMap();
    map[key] = value;
    return await setCacheMap(map);
  }

  /// Gets a single value from the persistent map
  Future<dynamic> getCacheEntry(String key) async {
    final map = await getCacheMap();
    return map[key];
  }
  
  /// Removes a key from the persistent map
  Future<bool> removeCacheEntry(String key) async {
    final map = await getCacheMap();
    map.remove(key);
    return await setCacheMap(map);
  }
  
  /// Clears the entire persistent map
  Future<bool> clearCacheMap() async {
    if (_prefs == null) await init();
    return await _prefs!.remove(_mapCacheKey);
  }
}
