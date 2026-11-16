import 'package:flutter_test/flutter_test.dart';
import 'package:vivacol/models/ai_property_search.dart';
import 'package:vivacol/services/ai_property_search_cache.dart';
import 'package:vivacol/services/ai_property_search_service.dart';
import 'package:vivacol/services/ai_service.dart';

const _validJson = '''
{
  "interpretacion": {
    "operacion": "venta",
    "tipoInmueble": "apartamento",
    "precioMaximo": 500000000,
    "zona": "Fontibón",
    "supuestos": ["Se asumió venta por el monto"]
  },
  "resultados": [
    {
      "titulo": "Apartamento en venta",
      "tipoInmueble": "apartamento",
      "operacion": "venta",
      "precioCOP": 420000000,
      "areaM2": 72.5,
      "habitaciones": 3,
      "banos": 2,
      "direccion": null,
      "barrio": "Fontibón",
      "url": "https://www.fincaraiz.com.co/apartamento-en-venta/bogota/10733573",
      "fuente": "fincaraiz",
      "datosNoObtenidos": ["direccion"]
    }
  ],
  "mensaje": null
}
''';

void main() {
  group('parser de respuesta de búsqueda IA', () {
    test('acepta JSON limpio y valida sus campos', () {
      final parsed = parseAiPropertySearchJson(_validJson);

      expect(parsed, isNotNull);
      expect(parsed!.interpretation?.zone, 'Fontibón');
      expect(parsed.candidates, hasLength(1));
      expect(parsed.candidates.single.priceCop, 420000000);
      expect(parsed.candidates.single.missingData, ['direccion']);
    });

    test('acepta JSON dentro de un bloque markdown', () {
      final parsed = parseAiPropertySearchJson('```json\n$_validJson```');
      expect(parsed?.candidates, hasLength(1));
    });

    test('extrae un objeto rodeado de texto', () {
      final parsed = parseAiPropertySearchJson('Respuesta:\n$_validJson\nFin');
      expect(parsed?.candidates, hasLength(1));
    });

    test('descarta items inválidos y devuelve null ante texto mal formado', () {
      const invalidItemResponse = '''
{"resultados":[
  {"titulo": 12},
  {"titulo":"Aviso válido","tipoInmueble":"casa","operacion":"venta","precioCOP":null,"areaM2":null,"habitaciones":null,"banos":null,"direccion":null,"barrio":"Chapinero","url":"https://www.fincaraiz.com.co/casa-en-venta/bogota/1234567","fuente":"fincaraiz","datosNoObtenidos":[]}
],"mensaje":null}
''';
      expect(
        parseAiPropertySearchJson(invalidItemResponse)?.candidates,
        hasLength(1),
      );
      expect(parseAiPropertySearchJson('esto no es { json }'), isNull);
    });
  });

  group('detección y normalización del prefijo', () {
    test('detecta ia: sin distinguir mayúsculas y quita espacios exteriores',
        () {
      expect(aiSearchQueryFromText('  IA:  casas en Fontibón  '),
          'casas en Fontibón');
      expect(aiSearchQueryFromText('ia:'), isEmpty);
      expect(aiSearchQueryFromText('casas en Fontibón'), isNull);
    });

    test('normaliza mayúsculas y espacios repetidos para el caché', () {
      expect(
        normalizeAiPropertySearchQuery('  Casas   en FONTIBÓN '),
        'casas en fontibón',
      );
    });
  });

  group('caché temporal', () {
    test('conserva respuesta e imagen y expira a los diez minutos', () {
      var now = DateTime(2026, 11, 16, 12);
      final cache = AiPropertySearchCache(clock: () => now);
      const response = AiPropertySearchResponse(message: 'resultado');
      final listingUrl = Uri.parse(
        'https://www.fincaraiz.com.co/apartamento-en-venta/bogota/10733573',
      );

      cache.storeResponse('IA: apartamentos fontibon', response);
      cache.storeImage(
        'ia: apartamentos fontibon',
        listingUrl,
        'https://images.example.com/listing.jpg',
      );
      expect(
          cache.responseFor(' ia: APARTAMENTOS   fontibon '), same(response));
      expect(
          cache.hasImageFor('ia: apartamentos fontibon', listingUrl), isTrue);
      expect(
        cache.imageFor('ia: apartamentos fontibon', listingUrl),
        'https://images.example.com/listing.jpg',
      );

      now = now.add(const Duration(minutes: 10));
      expect(cache.responseFor('ia: apartamentos fontibon'), isNull);
      expect(
          cache.hasImageFor('ia: apartamentos fontibon', listingUrl), isFalse);
      expect(cache.length, 0);
    });

    test('clear elimina todas las entradas en memoria', () {
      final cache = AiPropertySearchCache();
      cache.storeResponse(
        'ia: apartamento',
        const AiPropertySearchResponse(message: 'resultado'),
      );

      cache.clear();

      expect(cache.length, 0);
    });
  });

  group('errores de IA existentes', () {
    test('mantiene mensaje de cuota para 429', () {
      final error = AiException.fromGenerationError(
        Exception('429 quota exceeded'),
        operation: 'búsqueda web',
      );
      expect(error.message, contains('limite gratuito'));
    });

    test('mantiene mensaje de saturación para 503', () {
      final error = AiException.fromGenerationError(
        Exception('503 unavailable'),
        operation: 'búsqueda web',
      );
      expect(error.message, contains('saturado'));
    });
  });
}
