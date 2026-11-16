import '../models/ai_property_search.dart';

const Duration aiPropertySearchCacheTtl = Duration(minutes: 10);

String normalizeAiPropertySearchQuery(String query) =>
    query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class AiPropertySearchCache {
  AiPropertySearchCache({
    DateTime Function()? clock,
    this.ttl = aiPropertySearchCacheTtl,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration ttl;
  final Map<String, _CacheEntry> _entries = {};

  int get length => _entries.length;

  AiPropertySearchResponse? responseFor(String query) {
    final entry = _entryFor(normalizeAiPropertySearchQuery(query));
    return entry?.response;
  }

  void storeResponse(String query, AiPropertySearchResponse response) {
    final key = normalizeAiPropertySearchQuery(query);
    if (key.isEmpty) return;
    _entries[key] = _CacheEntry(response: response, storedAt: _clock());
  }

  bool hasImageFor(String query, Uri listingUrl) {
    final entry = _entryFor(normalizeAiPropertySearchQuery(query));
    return entry?.imageUrls.containsKey(listingUrl.toString()) ?? false;
  }

  String? imageFor(String query, Uri listingUrl) {
    final entry = _entryFor(normalizeAiPropertySearchQuery(query));
    return entry?.imageUrls[listingUrl.toString()];
  }

  void storeImage(String query, Uri listingUrl, String? imageUrl) {
    final entry = _entryFor(normalizeAiPropertySearchQuery(query));
    entry?.imageUrls[listingUrl.toString()] = imageUrl;
  }

  void clear() => _entries.clear();

  _CacheEntry? _entryFor(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (_clock().difference(entry.storedAt) >= ttl) {
      _entries.remove(key);
      return null;
    }
    return entry;
  }
}

class _CacheEntry {
  final AiPropertySearchResponse response;
  final DateTime storedAt;
  final Map<String, String?> imageUrls = {};

  _CacheEntry({required this.response, required this.storedAt});
}
