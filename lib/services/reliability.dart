import 'dart:math';

import '../models/community_report.dart';
import '../models/property_status.dart';

/// Modelo de confiabilidad por acumulacion de evidencia.
///
/// Combina el Sistema de Reputacion Beta (Josang & Ismail, 2002) con un
/// decaimiento temporal exponencial (Koren, 2009): cada reporte aporta
/// evidencia a favor (r) o en contra (s) de que la publicacion sigue vigente,
/// y ese aporte pierde peso con el tiempo.
///
///   w = e^(-lambda * dias)        peso del reporte segun su antiguedad
///   r = suma de w * v             evidencia positiva
///   s = suma de w * (1 - v)       evidencia negativa
///   C = (r + 1) / (r + s + 2)     confianza [0,1]
///
/// Sin reportes C = 0.5 (incertidumbre). A medida que la evidencia envejece,
/// C tiende a 0.5, no a 0.

/// Vida media de la evidencia: cada [kConfidenceHalfLifeDays] dias el peso de
/// un reporte se reduce a la mitad.
const double kConfidenceHalfLifeDays = 30;

/// lambda del decaimiento, derivada de la vida media.
const double kConfidenceLambda = ln2 / kConfidenceHalfLifeDays;

/// Umbral de confianza para el estado "verificado" (verde).
///
/// Nota: con el modelo Beta un unico reporte reciente alcanza como maximo
/// C = 2/3 (0.667); por eso el verde se fija en 0.66 para que ese caso sea
/// verde. Subelo a 0.70 si prefieres exigir mas evidencia acumulada.
const double kConfidenceGreenMin = 0.66;

/// Umbral de confianza para el estado "alerta" (rojo).
const double kConfidenceRedMax = 0.40;

/// Evidencia v en [0,1] que aporta un reporte segun su tipo.
double evidenceValue(ReportType type) {
  switch (type) {
    case ReportType.disponible:
      return 1.0;
    case ReportType.cambioPrecio:
      return 0.5;
    case ReportType.noExiste:
      return 0.2;
  }
}

/// Dias (con decimales) entre dos fechas.
double daysBetween(DateTime from, DateTime to) =>
    to.difference(from).inMinutes /
    (Duration.minutesPerHour * Duration.hoursPerDay);

/// Peso de un reporte de [ageDays] dias de antiguedad: w = e^(-lambda * dias).
double reportWeight(double ageDays) {
  final t = ageDays < 0 ? 0.0 : ageDays;
  return exp(-kConfidenceLambda * t);
}

/// Evidencia agregada (r, s) de una lista de reportes evaluada en [reference].
///
/// Recibe reportes ya deduplicados (un voto por usuario, sin el publicador).
({double r, double s}) aggregateEvidence(
  List<CommunityReport> reports,
  DateTime reference,
) {
  var r = 0.0;
  var s = 0.0;
  for (final report in reports) {
    final w = reportWeight(daysBetween(report.date, reference));
    final v = evidenceValue(report.type);
    r += w * v;
    s += w * (1 - v);
  }
  return (r: r, s: s);
}

/// Confianza [0,1] a partir de la evidencia Beta: C = (r + 1) / (r + s + 2).
double reliabilityFromEvidence(double r, double s) => (r + 1) / (r + s + 2);

/// Confianza [0,1] a partir de los reportes ya deduplicados, evaluada en [now].
double reliabilityFromReports(
  List<CommunityReport> reports, {
  DateTime? now,
}) {
  final evidence = aggregateEvidence(reports, now ?? DateTime.now());
  return reliabilityFromEvidence(evidence.r, evidence.s);
}

/// Confianza [0,1] a partir de una evidencia agregada en [anchor], aplicando el
/// decaimiento transcurrido hasta [now]. Permite recalcular en vivo sin volver a
/// leer todos los reportes (tarjetas, mapa, perfil).
double reliabilityFromAnchoredEvidence({
  required double r,
  required double s,
  required DateTime anchor,
  DateTime? now,
}) {
  final decay = reportWeight(daysBetween(anchor, now ?? DateTime.now()));
  return reliabilityFromEvidence(r * decay, s * decay);
}

/// Traduce una confianza [0,1] al estado semaforo.
PropertyStatus statusFromConfidence(double confidence) {
  if (confidence >= kConfidenceGreenMin) return PropertyStatus.verificado;
  if (confidence <= kConfidenceRedMax) return PropertyStatus.alerta;
  return PropertyStatus.enRevision;
}

/// Deja un solo voto por usuario (el mas reciente) y descarta los reportes del
/// publicador de la propiedad. Los reportes sin [CommunityReport.authorId]
/// (datos antiguos) se tratan como votos independientes usando su id de documento.
List<CommunityReport> dedupeReports(
  List<CommunityReport> reports, {
  String publisherId = '',
}) {
  final latestByUser = <String, CommunityReport>{};
  for (final report in reports) {
    final author = report.authorId;
    if (author.isNotEmpty && author == publisherId) continue;
    final key = author.isNotEmpty ? author : 'anon:${report.id}';
    final current = latestByUser[key];
    if (current == null || report.date.isAfter(current.date)) {
      latestByUser[key] = report;
    }
  }
  return latestByUser.values.toList();
}
