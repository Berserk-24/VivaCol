import 'dart:math';

import '../models/community_report.dart';
import '../models/property_status.dart';

/// Modelo de confiabilidad con decaimiento exponencial.
///
/// La confianza de un dato inmobiliario se comporta como un fenomeno fisico
/// que pierde intensidad con el tiempo: un reporte reciente aporta toda su
/// confianza y, si nadie la refresca, decae sola segun
///
///   C(t) = C0 * e^(-lambda * t)
///
/// donde C0 es la confianza del ultimo reporte, t los dias transcurridos y
/// lambda la velocidad de decaimiento.

/// Vida media de la confianza: cada [kConfidenceHalfLifeDays] dias la
/// confianza se reduce a la mitad.
const double kConfidenceHalfLifeDays = 30;

/// lambda de la formula, derivada de la vida media.
const double kConfidenceLambda = ln2 / kConfidenceHalfLifeDays;

/// Umbral minimo de confianza para el estado "verificado".
const double kConfidenceVerifiedMin = 0.66;

/// Umbral minimo de confianza para el estado "en revision".
const double kConfidenceReviewMin = 0.33;

/// Confianza base C0 que aporta un reporte segun su tipo al momento de emitirse.
double baseConfidence(ReportType type) {
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

/// Aplica el decaimiento exponencial sobre una confianza [base] tras [days] dias.
double decayConfidence(double base, double days) {
  final t = days < 0 ? 0.0 : days;
  return (base * exp(-kConfidenceLambda * t)).clamp(0.0, 1.0);
}

/// Confianza actual [0,1] de una propiedad a partir de sus reportes.
///
/// El reporte mas reciente fija C0 y la fecha de referencia. Sin reportes se
/// asume recien publicada (confianza plena que tambien decae desde
/// [publishedAt]).
double confidenceFromReports(
  List<CommunityReport> reports, {
  required DateTime publishedAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  double base;
  DateTime since;
  if (reports.isEmpty) {
    base = 1.0;
    since = publishedAt;
  } else {
    final latest = reports.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    base = baseConfidence(latest.type);
    since = latest.date;
  }
  return decayConfidence(base, daysBetween(since, current));
}

/// Traduce una confianza [0,1] al estado semaforo.
PropertyStatus statusFromConfidence(double confidence) {
  if (confidence >= kConfidenceVerifiedMin) return PropertyStatus.verificado;
  if (confidence >= kConfidenceReviewMin) return PropertyStatus.enRevision;
  return PropertyStatus.alerta;
}
