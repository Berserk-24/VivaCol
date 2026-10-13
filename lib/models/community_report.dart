/// Tipo de reporte que puede enviar la comunidad sobre una publicacion.
enum ReportType {
  disponible,
  cambioPrecio,
  noExiste,
}

extension ReportTypeX on ReportType {
  String get label {
    switch (this) {
      case ReportType.disponible:
        return 'Sigue disponible';
      case ReportType.cambioPrecio:
        return 'Cambio de precio';
      case ReportType.noExiste:
        return 'Ya no existe / no disponible';
    }
  }
}

/// Reporte individual generado por un usuario de la comunidad.
class CommunityReport {
  final String id;
  final String propertyId;
  final ReportType type;
  final String authorName;
  final String comment;
  final DateTime date;

  const CommunityReport({
    required this.id,
    required this.propertyId,
    required this.type,
    required this.authorName,
    required this.comment,
    required this.date,
  });

  factory CommunityReport.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['date'];
    return CommunityReport(
      id: id,
      propertyId: (map['propertyId'] ?? '') as String,
      type: ReportType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ReportType.disponible,
      ),
      authorName: (map['authorName'] ?? '') as String,
      comment: (map['comment'] ?? '') as String,
      date: _parseDate(rawDate),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'type': type.name,
      'authorName': authorName,
      'comment': comment,
      'date': date.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    // Firestore Timestamp expone toDate() via duck typing.
    try {
      return raw.toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
