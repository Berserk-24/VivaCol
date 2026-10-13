import 'package:flutter_test/flutter_test.dart';
import 'package:vivacol/models/community_report.dart';
import 'package:vivacol/models/property_status.dart';
import 'package:vivacol/services/property_repository.dart';
import 'package:vivacol/services/reliability.dart';

CommunityReport _report(ReportType type, {DateTime? date}) => CommunityReport(
      id: '',
      propertyId: 'p1',
      type: type,
      authorName: 'Test',
      comment: '',
      date: date ?? DateTime(2026),
    );

void main() {
  // Momento fijo de referencia para que las pruebas sean deterministas.
  final now = DateTime(2026, 1, 1);

  group('computeStatus (semaforo con decaimiento)', () {
    test('sin reportes => verificado', () {
      expect(
        computeStatus(const [], publishedAt: now, now: now),
        PropertyStatus.verificado,
      );
    });

    test('reporte reciente "sigue disponible" => verificado', () {
      final reports = [_report(ReportType.disponible, date: now)];
      expect(
        computeStatus(reports, now: now),
        PropertyStatus.verificado,
      );
    });

    test('cambio de precio reciente => en revision', () {
      final reports = [_report(ReportType.cambioPrecio, date: now)];
      expect(
        computeStatus(reports, now: now),
        PropertyStatus.enRevision,
      );
    });

    test('"ya no existe" reciente => alerta', () {
      final reports = [_report(ReportType.noExiste, date: now)];
      expect(
        computeStatus(reports, now: now),
        PropertyStatus.alerta,
      );
    });

    test('el reporte mas reciente refresca la confianza', () {
      final reports = [
        _report(ReportType.noExiste,
            date: now.subtract(const Duration(days: 5))),
        _report(ReportType.disponible, date: now),
      ];
      expect(
        computeStatus(reports, now: now),
        PropertyStatus.verificado,
      );
    });
  });

  group('decaimiento de la confianza', () {
    test('C(0) = C0 (sin tiempo transcurrido)', () {
      expect(decayConfidence(1.0, 0), closeTo(1.0, 1e-9));
    });

    test('tras una vida media la confianza cae a la mitad', () {
      expect(
        decayConfidence(1.0, kConfidenceHalfLifeDays),
        closeTo(0.5, 1e-6),
      );
    });

    test('sin refrescar, un reporte "disponible" baja de estado con el tiempo',
        () {
      final reports = [_report(ReportType.disponible, date: now)];
      final later = now.add(const Duration(days: 60));
      expect(
        computeStatus(reports, now: now),
        PropertyStatus.verificado,
      );
      expect(
        computeStatus(reports, now: later),
        PropertyStatus.alerta,
      );
    });
  });
}
