import 'package:flutter_test/flutter_test.dart';
import 'package:vivacol/models/community_report.dart';
import 'package:vivacol/models/property_status.dart';
import 'package:vivacol/services/reliability.dart';

// Momento fijo de referencia para que las pruebas sean deterministas.
final _now = DateTime(2026, 1, 1, 12);

CommunityReport _report(
  ReportType type, {
  String authorId = 'u1',
  int ageDays = 0,
}) =>
    CommunityReport(
      id: authorId,
      propertyId: 'p1',
      type: type,
      authorId: authorId,
      authorName: authorId,
      comment: '',
      date: _now.subtract(Duration(days: ageDays)),
    );

void main() {
  group('confianza (reputacion Beta con decaimiento)', () {
    test('sin reportes => C = 0.5 (en revision)', () {
      final c = reliabilityFromReports(const [], now: _now);
      expect(c, closeTo(0.5, 1e-9));
      expect(statusFromConfidence(c), PropertyStatus.enRevision);
    });

    test('un reporte reciente "disponible" => verde', () {
      final reports = [_report(ReportType.disponible)];
      final c = reliabilityFromReports(reports, now: _now);
      expect(c, closeTo(2 / 3, 1e-6));
      expect(statusFromConfidence(c), PropertyStatus.verificado);
    });

    test('un reporte viejo "disponible" tiende a 0.5 (en revision)', () {
      final reports = [_report(ReportType.disponible, ageDays: 180)];
      final c = reliabilityFromReports(reports, now: _now);
      expect(c, lessThan(kConfidenceGreenMin));
      expect(c, greaterThan(kConfidenceRedMax));
      expect(statusFromConfidence(c), PropertyStatus.enRevision);
    });

    test('un reporte reciente "ya no existe" => rojo', () {
      final reports = [_report(ReportType.noExiste)];
      final c = reliabilityFromReports(reports, now: _now);
      expect(c, closeTo(0.40, 1e-6));
      expect(statusFromConfidence(c), PropertyStatus.alerta);
    });

    test('un cambio de precio reciente => en revision', () {
      final reports = [_report(ReportType.cambioPrecio)];
      expect(
        statusFromConfidence(reliabilityFromReports(reports, now: _now)),
        PropertyStatus.enRevision,
      );
    });
  });

  group('deduplicacion (un voto por usuario, sin publicador)', () {
    test('el mismo usuario reportando dos veces cuenta una vez', () {
      final raw = [
        _report(ReportType.noExiste, authorId: 'u1', ageDays: 2),
        _report(ReportType.disponible, authorId: 'u1', ageDays: 0),
      ];
      final votes = dedupeReports(raw);
      expect(votes.length, 1);
      // Se conserva el mas reciente ("disponible").
      expect(votes.single.type, ReportType.disponible);
    });

    test('el reporte del publicador se ignora', () {
      final raw = [
        _report(ReportType.disponible, authorId: 'dueno'),
        _report(ReportType.disponible, authorId: 'u2'),
      ];
      final votes = dedupeReports(raw, publisherId: 'dueno');
      expect(votes.length, 1);
      expect(votes.single.authorId, 'u2');
    });

    test('reportes antiguos sin authorId cuentan como votos independientes',
        () {
      final raw = [
        CommunityReport(
          id: 'a',
          propertyId: 'p1',
          type: ReportType.disponible,
          authorName: 'anon',
          comment: '',
          date: _now,
        ),
        CommunityReport(
          id: 'b',
          propertyId: 'p1',
          type: ReportType.noExiste,
          authorName: 'anon',
          comment: '',
          date: _now,
        ),
      ];
      expect(dedupeReports(raw).length, 2);
    });
  });

  group('ejemplo de acumulacion de evidencia', () {
    test('tres usuarios distintos => C ~ 0.61 (en revision)', () {
      final reports = [
        _report(ReportType.disponible, authorId: 'u1', ageDays: 0),
        _report(ReportType.noExiste, authorId: 'u2', ageDays: 10),
        _report(ReportType.disponible, authorId: 'u3', ageDays: 40),
      ];
      final votes = dedupeReports(reports);
      final c = reliabilityFromReports(votes, now: _now);
      expect(c, closeTo(0.61, 0.01));
      expect(statusFromConfidence(c), PropertyStatus.enRevision);
    });
  });
}
