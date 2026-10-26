import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_report.dart';
import '../models/property.dart';
import '../models/property_status.dart';
import 'reliability.dart';

/// Acceso a propiedades y reportes de la comunidad en Cloud Firestore.
///
/// Estructura:
///   properties/{propertyId}
///   properties/{propertyId}/reports/{reportId}
class PropertyRepository {
  PropertyRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _properties =>
      _db.collection('properties');

  CollectionReference<Map<String, dynamic>> _reportsOf(String propertyId) =>
      _properties.doc(propertyId).collection('reports');

  /// Lista de propiedades en tiempo real (sin reportes embebidos).
  Stream<List<Property>> watchProperties() {
    return _properties.orderBy('lastUpdated', descending: true).snapshots().map(
          (snap) =>
              snap.docs.map((d) => Property.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Una propiedad concreta en tiempo real (sin reportes embebidos).
  Stream<Property?> watchProperty(String id) {
    return _properties.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return Property.fromMap(doc.id, data);
    });
  }

  /// Reportes de una propiedad, del mas reciente al mas antiguo.
  Stream<List<CommunityReport>> watchReports(String propertyId) {
    return _reportsOf(propertyId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommunityReport.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Crea una nueva publicacion y devuelve su id generado.
  Future<String> addProperty(Property property) async {
    final ref = await _properties.add(property.toMap());
    return ref.id;
  }

  /// Registra un reporte de la comunidad y recalcula el estado semaforo.
  ///
  /// El documento usa el uid del autor como id ("un voto por usuario"): un nuevo
  /// reporte del mismo usuario sobrescribe el anterior.
  Future<void> addReport({
    required String propertyId,
    required CommunityReport report,
  }) async {
    final docId = report.authorId.isNotEmpty ? report.authorId : null;
    final reports = _reportsOf(propertyId);
    if (docId != null) {
      await reports.doc(docId).set(report.toMap());
    } else {
      await reports.add(report.toMap());
    }
    await _recomputeStatus(propertyId);
  }

  /// Vuelve a calcular el estado a partir de la evidencia acumulada de los
  /// reportes (deduplicados por usuario y sin el publicador). Guarda la
  /// evidencia agregada y la fecha de anclaje para el decaimiento en vivo.
  Future<void> _recomputeStatus(String propertyId) async {
    final propDoc = await _properties.doc(propertyId).get();
    final publisherId = (propDoc.data()?['publisherId'] ?? '') as String;

    final snap = await _reportsOf(propertyId).get();
    final rawReports =
        snap.docs.map((d) => CommunityReport.fromMap(d.id, d.data())).toList();
    final votes = dedupeReports(rawReports, publisherId: publisherId);

    final now = DateTime.now();
    final evidence = aggregateEvidence(votes, now);
    final status = statusFromConfidence(
      reliabilityFromEvidence(evidence.r, evidence.s),
    );
    await _properties.doc(propertyId).update({
      'status': status.name,
      'evidenceR': evidence.r,
      'evidenceS': evidence.s,
      'lastUpdated': now.toIso8601String(),
    });
  }

  /// Carga propiedades de ejemplo si la coleccion esta vacia.
  Future<void> seedIfEmpty(List<Property> seed) async {
    final existing = await _properties.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final p in seed) {
      batch.set(_properties.doc(), p.toMap());
    }
    await batch.commit();
  }
}

/// Estado del semaforo a partir de los reportes ya deduplicados, aplicando el
/// modelo de reputacion Beta con decaimiento temporal (ver reliability.dart).
PropertyStatus computeStatus(
  List<CommunityReport> reports, {
  DateTime? now,
}) {
  return statusFromConfidence(reliabilityFromReports(reports, now: now));
}
