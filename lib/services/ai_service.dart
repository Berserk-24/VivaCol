import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/community_report.dart';
import '../models/property.dart';
import '../models/property_status.dart';
import '../models/property_type.dart';
import '../utils/format.dart';

/// Envoltura sobre Firebase AI Logic usando el backend del Gemini Developer
/// API (nivel gratuito). Centraliza las llamadas de IA de la app.
class AiService {
  /// Modelo a usar. Si falla por disponibilidad, cambialo por otro Flash
  /// disponible en tu proyecto (p. ej. 'gemini-2.5-flash' o 'gemini-flash-latest').
  static const _modelName = 'gemini-3.8-flash';

  GenerativeModel? _model;

  GenerativeModel get _gemini =>
      _model ??= FirebaseAI.googleAI().generativeModel(model: _modelName);

  /// Genera una descripcion comercial a partir de los datos del formulario.
  Future<String> generateDescription({
    required String title,
    required PropertyType type,
    required ListingType listingType,
    required double price,
    required String locality,
    int? bedrooms,
    int? bathrooms,
    double? areaM2,
    bool parking = false,
  }) async {
    final details = <String>[
      'Tipo: ${type.label}',
      'Operacion: ${listingType.label}',
      if (title.isNotEmpty) 'Titulo: $title',
      if (price > 0) 'Precio: ${formatPrice(price)}',
      'Localidad: $locality, Bogota',
      if (type.hasBedrooms && bedrooms != null) 'Habitaciones: $bedrooms',
      if (type.hasBathrooms && bathrooms != null) 'Banos: $bathrooms',
      if (areaM2 != null && areaM2 > 0) 'Area: ${areaM2.round()} m2',
      if (type.hasParking) 'Parqueadero: ${parking ? 'si' : 'no'}',
    ].join('\n');

    final prompt = '''
Eres un redactor inmobiliario en Colombia. Escribe una descripcion atractiva y
honesta para una publicacion de vivienda en Bogota, en espanol neutro, de 2 a 4
oraciones (maximo 90 palabras). No inventes datos que no aparecen, no uses
emojis ni listas, y no repitas el precio textual. Usa un tono cercano y
profesional. Devuelve solo la descripcion.

Datos de la propiedad:
$details
''';

    return _generate(prompt, 'descripcion');
  }

  /// Resume que tan confiable y vigente parece una publicacion segun los
  /// reportes de la comunidad.
  Future<String> generateReliabilitySummary(Property property) async {
    final reports = property.reports;
    final reportLines = reports
        .map((r) => '- ${r.type.label}'
            '${r.comment.trim().isEmpty ? '' : ': ${r.comment.trim()}'}')
        .join('\n');

    final prompt = '''
Eres un asistente que ayuda a la comunidad de VivaCol a evaluar que tan
confiable y vigente es una publicacion inmobiliaria en Bogota, segun los
reportes de otros usuarios. Escribe un resumen breve (2 a 3 oraciones, maximo
70 palabras), en espanol neutro, objetivo y prudente. Indica si la publicacion
parece seguir vigente, si hay senales de alerta (precio desactualizado, ya no
disponible) y una recomendacion corta para quien la consulta. No inventes datos.

Estado reportado actualmente: ${property.liveStatus().label}
Confianza estimada: ${(property.confidenceNow() * 100).round()}%
Numero de reportes: ${reports.length}
Reportes de la comunidad:
$reportLines
''';

    return _generate(prompt, 'resumen');
  }

  Future<String> _generate(String prompt, String label) async {
    try {
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        throw AiException('La IA no devolvio un $label.');
      }
      return text;
    } on AiException {
      rethrow;
    } catch (e) {
      // Marcadores para ubicar rapido el error real entre el ruido de consola.
      debugPrint(
          '\n==================== VIVACOL IA ERROR ====================');
      debugPrint('Operacion: $label');
      debugPrint('Modelo: $_modelName');
      debugPrint('Causa: $e');
      debugPrint(
          '==========================================================\n');
      final detail = e.toString().toLowerCase();
      if (detail.contains('429') ||
          detail.contains('quota') ||
          detail.contains('resource_exhausted') ||
          detail.contains('rate limit')) {
        throw const AiException(
          'Alcanzaste el limite gratuito de IA por ahora. '
          'Espera unos minutos e intenta de nuevo.',
        );
      }
      if (detail.contains('500') ||
          detail.contains('503') ||
          detail.contains('high demand') ||
          detail.contains('unavailable')) {
        throw const AiException(
          'El servicio de IA esta saturado en este momento. '
          'Intenta de nuevo en unos segundos.',
        );
      }
      throw AiException('No se pudo generar el $label. Intenta de nuevo.');
    }
  }
}

/// Error controlado de las operaciones de IA.
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}
