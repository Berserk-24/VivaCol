import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_property_search.dart';
import '../services/ai_property_search_service.dart';
import '../services/ai_property_search_cache.dart';
import '../services/ai_service.dart';

class AiPropertySearchProvider extends ChangeNotifier {
  AiPropertySearchProvider(this._service)
      : _lastUserId = FirebaseAuth.instance.currentUser?.uid {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  final AiPropertySearchService _service;
  final AiPropertySearchCache _cache = AiPropertySearchCache();
  late final StreamSubscription<User?> _authSubscription;
  String? _lastUserId;
  String _input = '';
  AiPropertySearchResponse? _response;
  String? _error;
  bool _loading = false;
  int _requestId = 0;

  bool get isActive => aiSearchQueryFromText(_input) != null;
  String get request => aiSearchQueryFromText(_input) ?? '';
  AiPropertySearchResponse? get response => _response;
  String? get error => _error;
  bool get loading => _loading;

  Future<String?> fetchImageFor(AiPropertySearchListing listing) async {
    final query = request;
    if (query.isEmpty) return _service.fetchListingImage(listing.url);
    if (_cache.hasImageFor(query, listing.url)) {
      return _cache.imageFor(query, listing.url);
    }
    final imageUrl = await _service.fetchListingImage(listing.url);
    _cache.storeImage(query, listing.url, imageUrl);
    return imageUrl;
  }

  void updateInput(String value) {
    final oldRequest = request;
    final wasActive = isActive;
    _input = value;
    if (!isActive || request != oldRequest || wasActive != isActive) {
      _requestId++;
      _response = null;
      _error = null;
      _loading = false;
    }
    if (isActive && request.isEmpty) {
      _response = const AiPropertySearchResponse(
        hint: 'Escribe qué inmueble buscas después de ia:',
      );
    }
    notifyListeners();
  }

  Future<void> submit(String value) async {
    updateInput(value);
    if (!isActive) return;

    final currentRequest = request;
    if (currentRequest.isEmpty) {
      _response = const AiPropertySearchResponse(
        hint: 'Escribe qué inmueble buscas después de ia:',
      );
      notifyListeners();
      return;
    }

    final cachedResponse = _cache.responseFor(currentRequest);
    if (cachedResponse != null) {
      _response = cachedResponse;
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }

    final requestId = ++_requestId;
    _loading = true;
    _response = null;
    _error = null;
    notifyListeners();

    try {
      final response = await _service.search(currentRequest);
      if (requestId != _requestId) return;
      _cache.storeResponse(currentRequest, response);
      _response = response;
    } on AiException catch (error) {
      if (requestId != _requestId) return;
      _error = error.message;
    } catch (_) {
      if (requestId != _requestId) return;
      _error = 'No se pudo realizar la búsqueda. Intenta de nuevo.';
    } finally {
      if (requestId == _requestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _requestId++;
    _input = '';
    _response = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void _onAuthChanged(User? user) {
    if (_lastUserId == user?.uid) return;
    _lastUserId = user?.uid;
    _cache.clear();
    _requestId++;
    _input = '';
    _response = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
