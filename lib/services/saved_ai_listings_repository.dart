import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../models/ai_property_search.dart';

class SavedAiListingsRepository {
  SavedAiListingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collectionFor(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_ai_listings');

  String documentIdFor(Uri url) =>
      sha256.convert(utf8.encode(url.toString())).toString();

  Future<bool> contains(String userId, Uri url) async {
    final snapshot = await _collectionFor(userId).doc(documentIdFor(url)).get();
    return snapshot.exists;
  }

  Future<void> save(String userId, AiPropertySearchListing listing) {
    return _collectionFor(userId).doc(documentIdFor(listing.url)).set({
      'title': listing.title,
      'propertyType': listing.propertyType,
      'operation': listing.operation,
      'priceCop': listing.priceCop,
      'areaM2': listing.areaM2,
      'bedrooms': listing.bedrooms,
      'bathrooms': listing.bathrooms,
      'address': listing.address,
      'neighborhood': listing.neighborhood,
      'url': listing.url.toString(),
      'source': listing.source,
      'missingData': listing.missingData,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String userId, Uri url) =>
      _collectionFor(userId).doc(documentIdFor(url)).delete();

  Stream<List<SavedAiPropertyListing>> watchForUser(String userId) {
    return _collectionFor(userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              final data = document.data();
              final savedAt = data['savedAt'];
              return SavedAiPropertyListing.fromMap(
                document.id,
                data,
                savedAt is Timestamp ? savedAt.toDate() : DateTime.now(),
              );
            }).toList());
  }
}
