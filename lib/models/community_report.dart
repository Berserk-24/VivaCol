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
}
