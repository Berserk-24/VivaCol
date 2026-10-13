import 'package:flutter_test/flutter_test.dart';
import 'package:vivacol/models/community_report.dart';
import 'package:vivacol/models/property_status.dart';
import 'package:vivacol/services/property_repository.dart';

CommunityReport _report(ReportType type) => CommunityReport(
      id: '',
      propertyId: 'p1',
      type: type,
      authorName: 'Test',
      comment: '',
      date: DateTime(2026),
    );

void main() {
  group('computeStatus (semaforo de la comunidad)', () {
    test('sin reportes => verificado', () {
      expect(computeStatus(const []), PropertyStatus.verificado);
    });

    test('solo reportes "sigue disponible" => verificado', () {
      final reports = [
        _report(ReportType.disponible),
        _report(ReportType.disponible),
      ];
      expect(computeStatus(reports), PropertyStatus.verificado);
    });

    test('un cambio de precio => en revision', () {
      final reports = [
        _report(ReportType.disponible),
        _report(ReportType.cambioPrecio),
      ];
      expect(computeStatus(reports), PropertyStatus.enRevision);
    });

    test('un "ya no existe" => en revision', () {
      expect(
        computeStatus([_report(ReportType.noExiste)]),
        PropertyStatus.enRevision,
      );
    });

    test('dos o mas "ya no existe" => alerta', () {
      final reports = [
        _report(ReportType.noExiste),
        _report(ReportType.noExiste),
      ];
      expect(computeStatus(reports), PropertyStatus.alerta);
    });
  });
}
