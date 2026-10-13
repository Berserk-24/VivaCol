import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_report.dart';
import '../models/property.dart';
import '../models/property_status.dart';

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
  Future<void> addReport({
    required String propertyId,
    required CommunityReport report,
  }) async {
    await _reportsOf(propertyId).add(report.toMap());
    await _recomputeStatus(propertyId);
  }

  /// Vuelve a calcular el estado de una propiedad a partir de sus reportes.
  Future<void> _recomputeStatus(String propertyId) async {
    final snap = await _reportsOf(propertyId).get();
    final reports =
        snap.docs.map((d) => CommunityReport.fromMap(d.id, d.data())).toList();
    final status = computeStatus(reports);
    await _properties.doc(propertyId).update({
      'status': status.name,
      'lastUpdated': DateTime.now().toIso8601String(),
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

/// Heuristica del semaforo basada en los reportes de la comunidad.
/// - 2 o mas reportes "ya no existe" => alerta
/// - al menos un reporte de cambio de precio o "no existe" => en revision
/// - de lo contrario => verificado
PropertyStatus computeStatus(List<CommunityReport> reports) {
  if (reports.isEmpty) return PropertyStatus.verificado;
  final noExiste = reports.where((r) => r.type == ReportType.noExiste).length;
  if (noExiste >= 2) return PropertyStatus.alerta;
  final hayCambios = reports.any(
    (r) => r.type == ReportType.cambioPrecio || r.type == ReportType.noExiste,
  );
  if (hayCambios) return PropertyStatus.enRevision;
  return PropertyStatus.verificado;
}
