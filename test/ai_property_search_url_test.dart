import 'package:flutter_test/flutter_test.dart';
import 'package:vivacol/services/ai_property_search_service.dart';

void main() {
  group('clasificacion de enlaces inmobiliarios', () {
    test('acepta los avisos individuales observados por portal', () {
      const acceptedUrls = [
        'https://www.fincaraiz.com.co/apartamento-en-arriendo-en-fontibon-bogota/192954611',
        'https://www.fincaraiz.com.co/apartamento-en-venta/bogota/10733573',
        'https://www.fincaraiz.com.co/casa-en-venta/bogota-bogota/7946457',
        'https://www.metrocuadrado.com/inmueble/arriendo-apartamento-bogota-fontibon-3-habitaciones-2-banos/11813-M6895271',
        'https://www.ciencuadras.com/inmueble/apartamento-en-arriendo-en-ciudad-salitre-occidental-bogota-3580386',
      ];

      for (final url in acceptedUrls) {
        final classification = classifyAiPropertySearchUrl(url);
        expect(classification, isNotNull, reason: url);
        expect(classification!.matchesIndividualPattern, isTrue, reason: url);
      }
    });

    test('acepta paginas de resultados solo para portales y Bogota', () {
      const listingUrls = [
        'https://www.fincaraiz.com.co/venta/inmuebles/bogota',
        'https://www.fincaraiz.com.co/arriendo/apartamentos/puente-grande/zona-occidental/bogota',
        'https://www.metrocuadrado.com/arriendo/apartamentos/bogota',
        'https://www.ciencuadras.com/arriendo/bogota/fontibon/cjr-ibiza-iii-y-iv/apartamento',
      ];

      for (final url in listingUrls) {
        final classification = classifyAiPropertySearchUrl(url);
        expect(classification, isNotNull, reason: url);
        expect(classification!.isListingPage, isTrue, reason: url);
        expect(classification.matchesIndividualPattern, isFalse, reason: url);
      }
    });

    test('rechaza rutas genericas sin ciudad o sin criterios inmobiliarios',
        () {
      const rejectedUrls = [
        'https://www.fincaraiz.com.co/venta/apartamentos',
        'https://www.fincaraiz.com.co/buscar/apartamento/bogota',
      ];

      for (final url in rejectedUrls) {
        expect(classifyAiPropertySearchUrl(url), isNull, reason: url);
      }
    });

    test('rechaza una ruta que nombra otra ciudad', () {
      const url =
          'https://www.fincaraiz.com.co/apartamento-en-venta-en-medellin/194019330';
      expect(classifyAiPropertySearchUrl(url), isNull);
    });

    test('acepta www y subdominios de un dominio permitido', () {
      const urls = [
        'https://www.fincaraiz.com.co/apartamento-en-venta/bogota/10733573',
        'https://listados.metrocuadrado.com/inmueble/arriendo-apartamento-bogota/11813-M6895271',
      ];

      for (final url in urls) {
        expect(classifyAiPropertySearchUrl(url), isNotNull, reason: url);
      }
    });

    test('marca como heuristico un aviso plausible sin patron conocido', () {
      const url =
          'https://www.fincaraiz.com.co/propiedad/apartamento-amplio-con-terraza-y-vista-bogota-1234567';
      final classification = classifyAiPropertySearchUrl(url);

      expect(classification, isNotNull);
      expect(classification!.matchesIndividualPattern, isFalse);
      expect(classification.isListingPage, isFalse);
    });

    test('rechaza esquemas no seguros y hosts de redireccion de grounding', () {
      const urls = [
        'http://www.fincaraiz.com.co/apartamento-en-venta/bogota/10733573',
        'https://vertexaisearch.cloud.google.com/grounding-api-redirect/abc',
        'https://fincaraiz.com.co.evil.example/apartamento-en-venta/bogota/10733573',
      ];

      for (final url in urls) {
        expect(classifyAiPropertySearchUrl(url), isNull, reason: url);
      }
    });
  });
}
