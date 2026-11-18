import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' hide LatLng;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../config/map_config.dart';
import '../models/ai_property_search.dart';
import 'ai_service.dart';

class AiPropertySearchUrlPatterns {
  AiPropertySearchUrlPatterns._();

  static const Map<String, String> domainsBySource = {
    'fincaraiz': 'fincaraiz.com.co',
    'metrocuadrado': 'metrocuadrado.com',
    'ciencuadras': 'ciencuadras.com',
  };

  static final RegExp fincaraizIndividual =
      RegExp(r'^/(?:[^/]+/)+\d{5,}/?$', caseSensitive: false);
  static final RegExp metrocuadradoIndividual = RegExp(
    r'^/inmueble/[^/]+/\d{4,}-[a-z]\d{5,}/?$',
    caseSensitive: false,
  );
  static final RegExp ciencuadrasIndividual = RegExp(
    r'^/inmueble/[^/]+-\d{5,}/?$',
    caseSensitive: false,
  );

  static const Set<String> indexRouteNames = {
    'buscar',
    'busqueda',
    'search',
    'resultados',
    'listado',
    'listados',
    'listings',
    'catalogo',
    'catalog',
    'proyectos',
    'venta',
    'arriendo',
  };

  static const Set<String> genericRouteNames = {
    'bogota',
    'colombia',
    'venta',
    'arriendo',
    'inmueble',
    'inmuebles',
    'apartamento',
    'apartamentos',
    'casa',
    'casas',
    'oficina',
    'oficinas',
  };

  static const Set<String> otherCitySlugs = {
    'armenia',
    'barranquilla',
    'bucaramanga',
    'cali',
    'cartagena',
    'cucuta',
    'ibague',
    'manizales',
    'medellin',
    'monteria',
    'neiva',
    'pasto',
    'pereira',
    'popayan',
    'riohacha',
    'santa-marta',
    'sincelejo',
    'tunja',
    'valledupar',
    'villavicencio',
  };
}

List<String> get aiPropertySearchAllowedDomains =>
    AiPropertySearchUrlPatterns.domainsBySource.values.toList(growable: false);

const String noAiPropertySearchResultsMessage =
    'No se encontraron resultados apropiados con estas especificaciones.\n'
    'Intenta hacer una petición distinta.';

const String _defaultSearchModelName = 'gemini-3.5-flash-lite';
const Duration _requestTimeout = Duration(seconds: 5);
const String _vertexRedirectHost = 'vertexaisearch.cloud.google.com';

const String _searchSystemInstruction = '''
Eres un asistente de búsqueda inmobiliaria para VivaCol, una app de Bogotá, Colombia.

TAREA
Interpreta la petición del usuario y usa la búsqueda web en esta misma respuesta para encontrar hasta 5 resultados inmobiliarios en Bogotá. Prioriza avisos individuales. Hazlo todo en una sola respuesta, sin hacer preguntas ni pedir confirmaciones.

REGLAS DE BÚSQUEDA
- Antes de redactar, busca avisos actuales con Google Search. No uses conocimiento previo ni inventes resultados.
- Incluye únicamente avisos encontrados en los resultados de búsqueda, con una URL exacta de la fuente. Si no puedes verificar avisos actuales, devuelve "resultados": [] y explícalo en "mensaje".
- Solo inmuebles ubicados en Bogotá, Colombia. Si la petición es de otra ciudad, devuelve "resultados": [] y explícalo en "mensaje".
- Solo avisos publicados en fincaraiz.com.co, metrocuadrado.com o ciencuadras.com.
- Interpreta el precio como MÁXIMO. Si el usuario no dice si es venta o arriendo, deduce por el monto (cientos de millones suelen ser venta; pocos millones suelen ser arriendo mensual) y registra la deducción en "supuestos".
- Si el usuario indica un barrio o una localidad, busca avisos ahí.

REGLAS DE ENLACE (MUY IMPORTANTES)
- Prioriza enlaces directos a páginas de detalle de avisos individuales.
- Si no encuentras avisos individuales suficientes en un portal, incluye como último recurso máximo una página de resultados/categoría de ese portal para intentar extraer un aviso individual.
- Ordena los avisos individuales antes que las páginas de resultados. Si solo encuentras páginas de resultados, incluye una por cada portal disponible, sin superar 5 resultados.
- No uses páginas principales. Una página de resultados nunca debe describirse como si fuera un aviso individual.
- Copia cada URL exactamente como la encontraste. Nunca la construyas ni la completes.

REGLAS DE DATOS
- Nunca inventes datos. Si un dato no aparece en la fuente, déjalo en null y agrega su nombre a "datosNoObtenidos".
- "direccion": la dirección exacta solo si el aviso la publica; si solo hay barrio o sector, déjala en null y llena "barrio".
- Precio en pesos colombianos como número entero, sin símbolos ni separadores. Área en m².

FORMATO DE SALIDA
Responde ÚNICAMENTE con un objeto JSON, sin texto antes ni después:
{
  "interpretacion": {"operacion": "venta|arriendo", "tipoInmueble": string, "precioMaximo": number|null, "zona": string|null, "supuestos": [string]},
  "resultados": [
    {"titulo": string, "tipoInmueble": string, "operacion": "venta|arriendo", "precioCOP": number|null, "areaM2": number|null, "habitaciones": number|null, "banos": number|null, "direccion": string|null, "barrio": string|null, "url": string, "fuente": "fincaraiz|metrocuadrado|ciencuadras", "datosNoObtenidos": [string]}
  ],
  "mensaje": string|null
}
''';

String? aiSearchQueryFromText(String text) {
  final trimmed = text.trim();
  if (!trimmed.toLowerCase().startsWith('ia:')) return null;
  return trimmed.substring(3).trim();
}

AiPropertySearchInterpretation? _parseInterpretation(Object? value) {
  final map = _stringKeyedMap(value);
  if (map == null) return null;
  final operation = map['operacion'];
  final propertyType = map['tipoInmueble'];
  final maxPrice = _nullableInteger(map['precioMaximo']);
  final zone = map['zona'];
  final assumptions = _stringList(map['supuestos']);
  if ((operation != 'venta' && operation != 'arriendo') ||
      propertyType is! String ||
      (map['precioMaximo'] != null && maxPrice == null) ||
      (zone != null && zone is! String) ||
      assumptions == null) {
    return null;
  }
  return AiPropertySearchInterpretation(
    operation: operation,
    propertyType: propertyType,
    maxPrice: maxPrice,
    zone: zone as String?,
    assumptions: assumptions,
  );
}

List<AiPropertySearchCandidate> _parseCandidates(Object? value) {
  if (value is! List) return const [];
  final candidates = <AiPropertySearchCandidate>[];
  for (final item in value) {
    final map = _stringKeyedMap(item);
    if (map == null) continue;
    final title = map['titulo'];
    final propertyType = map['tipoInmueble'];
    final operation = map['operacion'];
    final price = _nullableInteger(map['precioCOP']);
    final area = _nullableDouble(map['areaM2']);
    final bedrooms = _nullableInteger(map['habitaciones']);
    final bathrooms = _nullableInteger(map['banos']);
    final address = map['direccion'];
    final neighborhood = map['barrio'];
    final url = map['url'];
    final source = map['fuente'];
    final missingData = _stringList(map['datosNoObtenidos']);

    if (title is! String ||
        title.trim().isEmpty ||
        propertyType is! String ||
        operation is! String ||
        (operation != 'venta' && operation != 'arriendo') ||
        (map['precioCOP'] != null && price == null) ||
        (map['areaM2'] != null && area == null) ||
        (map['habitaciones'] != null && bedrooms == null) ||
        (map['banos'] != null && bathrooms == null) ||
        (address != null && address is! String) ||
        (neighborhood != null && neighborhood is! String) ||
        (url != null && url is! String) ||
        source is! String ||
        !AiPropertySearchUrlPatterns.domainsBySource.containsKey(source) ||
        missingData == null) {
      continue;
    }

    candidates.add(
      AiPropertySearchCandidate(
        title: title.trim(),
        propertyType: propertyType,
        operation: operation,
        priceCop: price,
        areaM2: area,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        address: address as String?,
        neighborhood: neighborhood as String?,
        url: url as String?,
        source: source,
        missingData: missingData,
      ),
    );
  }
  return candidates;
}

AiPropertySearchPayload? parseAiPropertySearchJson(String response) {
  final trimmed = response.trim();
  if (trimmed.isEmpty) return null;

  var jsonText = trimmed;
  final fenced =
      RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$', caseSensitive: false)
          .firstMatch(trimmed);
  if (fenced != null) {
    jsonText = fenced.group(1) ?? '';
  } else {
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) return null;
    jsonText = trimmed.substring(firstBrace, lastBrace + 1);
  }

  try {
    final root = _stringKeyedMap(jsonDecode(jsonText));
    if (root == null || root['resultados'] is! List) return null;
    final message = root['mensaje'];
    if (message != null && message is! String) return null;
    return AiPropertySearchPayload(
      interpretation: _parseInterpretation(root['interpretacion']),
      candidates: _parseCandidates(root['resultados']),
      message: message as String?,
    );
  } on FormatException {
    return null;
  }
}

Map<String, dynamic>? _stringKeyedMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) return null;
  return Map<String, dynamic>.from(value);
}

int? _nullableInteger(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value % 1 != 0) return null;
  return value.toInt();
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite) return null;
  return value.toDouble();
}

List<String>? _stringList(Object? value) {
  if (value is! List || value.any((item) => item is! String)) return null;
  return value.cast<String>();
}

String? _domainForSource(String source) =>
    AiPropertySearchUrlPatterns.domainsBySource[source];

String? _sourceForHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  for (final source in AiPropertySearchUrlPatterns.domainsBySource.keys) {
    final domain = _domainForSource(source)!;
    if (normalized == domain || normalized.endsWith('.$domain')) return source;
  }
  return null;
}

AiPropertySearchUrlClassification? classifyAiPropertySearchUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
  final source = _sourceForHost(uri.host);
  if (source == null) return null;
  if (uri.userInfo.isNotEmpty || (uri.hasPort && uri.port != 443)) return null;

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .map(_normalizePathSegment)
      .toList();
  if (segments.isEmpty) return null;
  if (_pathNamesOtherCity(segments)) return null;

  final individualPattern = switch (source) {
    'fincaraiz' =>
      AiPropertySearchUrlPatterns.fincaraizIndividual.hasMatch(uri.path),
    'metrocuadrado' =>
      AiPropertySearchUrlPatterns.metrocuadradoIndividual.hasMatch(uri.path),
    'ciencuadras' =>
      AiPropertySearchUrlPatterns.ciencuadrasIndividual.hasMatch(uri.path),
    _ => false,
  };
  if (individualPattern) {
    return AiPropertySearchUrlClassification(
      uri: uri,
      source: source,
      matchesIndividualPattern: true,
      isListingPage: false,
    );
  }

  if (_matchesPortalListingPage(segments)) {
    return AiPropertySearchUrlClassification(
      uri: uri,
      source: source,
      matchesIndividualPattern: false,
      isListingPage: true,
    );
  }

  if (!_passesConservativeHeuristic(segments)) return null;
  return AiPropertySearchUrlClassification(
    uri: uri,
    source: source,
    matchesIndividualPattern: false,
    isListingPage: false,
  );
}

String _normalizePathSegment(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ñ', 'n');

bool _pathNamesOtherCity(List<String> segments) {
  for (final segment in segments) {
    final words = segment.split(RegExp(r'[^a-z0-9]+'));
    if (AiPropertySearchUrlPatterns.otherCitySlugs.any(words.contains) ||
        AiPropertySearchUrlPatterns.otherCitySlugs.contains(segment)) {
      return true;
    }
  }
  return false;
}

bool _matchesPortalListingPage(List<String> segments) {
  if (segments.length < 3) return false;
  final finalSegment = segments.last;
  final finalWords = finalSegment.split('-').where((word) => word.isNotEmpty);
  if (RegExp(r'\d{5,}').hasMatch(finalSegment) ||
      (finalSegment.length >= 28 && finalWords.length >= 5)) {
    return false;
  }
  final tokens = segments
      .expand((segment) => segment.split(RegExp(r'[^a-z0-9]+')))
      .where((token) => token.isNotEmpty)
      .toSet();
  const operations = {'arriendo', 'venta'};
  const propertyTypes = {
    'apartamento',
    'apartamentos',
    'casa',
    'casas',
    'finca',
    'fincas',
    'inmueble',
    'inmuebles',
    'local',
    'locales',
    'oficina',
    'oficinas',
  };
  return tokens.contains('bogota') &&
      tokens.any(operations.contains) &&
      tokens.any(propertyTypes.contains);
}

bool _passesConservativeHeuristic(List<String> segments) {
  if (segments.length < 2 ||
      segments.any(AiPropertySearchUrlPatterns.indexRouteNames.contains) ||
      AiPropertySearchUrlPatterns.genericRouteNames.contains(segments.last)) {
    return false;
  }

  if (RegExp(r'\d{5,}').hasMatch(segments.last)) return true;
  return segments.any((segment) {
    final words = segment.split('-').where((word) => word.isNotEmpty).toList();
    return segment.length >= 28 &&
        words.length >= 5 &&
        words.any(
          (word) =>
              !AiPropertySearchUrlPatterns.genericRouteNames.contains(word) &&
              !AiPropertySearchUrlPatterns.otherCitySlugs.contains(word),
        );
  });
}

class AiPropertySearchUrlClassification {
  final Uri uri;
  final String source;
  final bool matchesIndividualPattern;
  final bool isListingPage;

  const AiPropertySearchUrlClassification({
    required this.uri,
    required this.source,
    required this.matchesIndividualPattern,
    required this.isListingPage,
  });
}

String? _unsupportedCity(String query) {
  final normalized = _normalizePathSegment(query).replaceAll('-', ' ');
  for (final city in AiPropertySearchUrlPatterns.otherCitySlugs) {
    final phrase = city.replaceAll('-', ' ');
    if (RegExp('(?<![a-z])${RegExp.escape(phrase)}(?![a-z])')
        .hasMatch(normalized)) {
      return phrase;
    }
  }
  return null;
}

class _ResolvedLink {
  final Uri uri;
  final bool verified;
  final bool isListingPage;

  const _ResolvedLink(
    this.uri,
    this.verified, {
    this.isListingPage = false,
  });
}

class AiPropertySearchService {
  AiPropertySearchService({
    http.Client? client,
    String modelName = _defaultSearchModelName,
    bool useGoogleSearch = true,
    bool logDiagnosticDetails = false,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _modelName = modelName,
        _useGoogleSearch = useGoogleSearch,
        _logDiagnosticDetails = logDiagnosticDetails;

  final http.Client _client;
  final bool _ownsClient;
  final String _modelName;
  final bool _useGoogleSearch;
  final bool _logDiagnosticDetails;
  GenerativeModel? _model;

  GenerativeModel get _searchModel => _model ??= FirebaseAI.googleAI(
        useLimitedUseAppCheckTokens: !kIsWeb,
      ).generativeModel(
        model: _modelName,
        tools: _useGoogleSearch ? [Tool.googleSearch()] : const [],
        systemInstruction: Content.text(_searchSystemInstruction),
      );

  Future<AiPropertySearchResponse> search(String naturalLanguageRequest) async {
    final query = naturalLanguageRequest.trim();
    if (query.isEmpty) {
      return const AiPropertySearchResponse(
        hint: 'Escribe qué inmueble buscas después de ia:',
      );
    }

    try {
      final response = await _searchModel.generateContent([
        Content.text(query),
      ]);
      final candidate =
          response.candidates.isEmpty ? null : response.candidates.first;
      final metadata = candidate?.groundingMetadata;
      if (_logDiagnosticDetails) {
        debugPrint('VivaCol búsqueda IA: modelo: $_modelName');
        debugPrint(
          'VivaCol búsqueda IA: Google Search: '
          '${_useGoogleSearch ? 'activado' : 'desactivado'}',
        );
        debugPrint('VivaCol búsqueda IA: respuesta: ${response.text}');
        debugPrint(
          'VivaCol búsqueda IA: grounding metadata: ${metadata != null}',
        );
      }
      final grounded = metadata != null && metadata.webSearchQueries.isNotEmpty;

      final otherCity = _unsupportedCity(query);
      if (otherCity != null) {
        return AiPropertySearchResponse(
          grounded: grounded,
          searchEntryPointHtml: metadata?.searchEntryPoint?.renderedContent,
          message:
              'Por ahora la búsqueda inmobiliaria con IA solo admite Bogotá. '
              'La solicitud menciona $otherCity.',
        );
      }

      final parsed = parseAiPropertySearchJson(response.text ?? '');
      if (parsed == null) {
        return AiPropertySearchResponse(
          grounded: grounded,
          searchEntryPointHtml: metadata?.searchEntryPoint?.renderedContent,
          message: noAiPropertySearchResultsMessage,
        );
      }

      final individualListings = <AiPropertySearchListing>[];
      final listPageFallbacks = <String, AiPropertySearchListing>{};
      final individualSources = <String>{};
      final seenUrls = <String>{};
      for (final item in parsed.candidates) {
        final link = await _resolveListingLink(
          item,
          metadata?.groundingChunks ?? const <GroundingChunk>[],
        );
        if (link == null) continue;
        final source = _sourceForHost(link.uri.host);
        if (source == null) continue;

        if (link.isListingPage) {
          final extracted = await _extractIndividualListingLink(
            link.uri,
            source,
          );
          if (extracted != null) {
            individualSources.add(source);
            if (seenUrls.add(extracted.uri.toString())) {
              individualListings.add(
                AiPropertySearchListing(
                  title: extracted.title.isEmpty
                      ? 'Aviso individual en Bogotá'
                      : extracted.title,
                  propertyType: item.propertyType,
                  operation: item.operation,
                  priceCop: null,
                  areaM2: null,
                  bedrooms: null,
                  bathrooms: null,
                  address: null,
                  neighborhood: null,
                  url: extracted.uri,
                  source: source,
                  missingData: const [
                    'precioCOP',
                    'areaM2',
                    'habitaciones',
                    'banos',
                    'direccion',
                    'barrio',
                  ],
                  linkVerified: extracted.verified,
                  approximateLocation: false,
                  latitude: null,
                  longitude: null,
                ),
              );
            }
          } else {
            listPageFallbacks.putIfAbsent(
              source,
              () => _createListPageFallback(item, link, source),
            );
          }
          continue;
        }

        if (!seenUrls.add(link.uri.toString())) continue;
        final location = await _geocode(item);
        individualSources.add(source);
        individualListings.add(
          AiPropertySearchListing(
            title: item.title,
            propertyType: item.propertyType,
            operation: item.operation,
            priceCop: item.priceCop,
            areaM2: item.areaM2,
            bedrooms: item.bedrooms,
            bathrooms: item.bathrooms,
            address: item.address,
            neighborhood: item.neighborhood,
            url: link.uri,
            source: source,
            missingData: item.missingData,
            linkVerified: link.verified,
            approximateLocation: location.approximate,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }

      final listings = <AiPropertySearchListing>[
        ...individualListings,
        ...listPageFallbacks.entries
            .where((entry) => !individualSources.contains(entry.key))
            .map((entry) => entry.value),
      ].take(5).toList(growable: false);
      final message = listings.isEmpty
          ? noAiPropertySearchResultsMessage
          : grounded
              ? parsed.message
              : 'No se recibió metadata de Google Search. '
                  'Verifica la información en cada enlace.';
      return AiPropertySearchResponse(
        listings: listings,
        interpretation: parsed.interpretation,
        grounded: grounded,
        searchEntryPointHtml: metadata?.searchEntryPoint?.renderedContent,
        message: message,
      );
    } catch (error) {
      debugPrint('VivaCol búsqueda IA: error completo: $error');
      debugPrint('VivaCol búsqueda IA: modelo: $_modelName');
      debugPrint(
        'VivaCol búsqueda IA: Google Search: '
        '${_useGoogleSearch ? 'activado' : 'desactivado'}',
      );
      throw AiException.fromGenerationError(error, operation: 'búsqueda web');
    }
  }

  Future<_ResolvedLink?> _resolveListingLink(
    AiPropertySearchCandidate candidate,
    List<GroundingChunk> chunks,
  ) async {
    final directUrl = candidate.url;
    final directClassification =
        directUrl == null ? null : classifyAiPropertySearchUrl(directUrl);
    if (directClassification != null) {
      if (directClassification.source != candidate.source) return null;
      if (kIsWeb) {
        return _ResolvedLink(
          directClassification.uri,
          false,
          isListingPage: directClassification.isListingPage,
        );
      }
      return _checkLink(directClassification.uri, keepOnTimeout: true);
    }

    if (kIsWeb) return null;
    final redirectUri = _matchingGroundingRedirect(candidate, chunks) ??
        _candidateGroundingRedirect(directUrl);
    if (redirectUri == null) return null;
    final resolved = await _checkLink(redirectUri, keepOnTimeout: false);
    final resolvedClassification = resolved == null
        ? null
        : classifyAiPropertySearchUrl(resolved.uri.toString());
    if (resolved == null ||
        resolvedClassification == null ||
        resolvedClassification.source != candidate.source) {
      return null;
    }
    return resolved;
  }

  AiPropertySearchListing _createListPageFallback(
    AiPropertySearchCandidate candidate,
    _ResolvedLink link,
    String source,
  ) {
    return AiPropertySearchListing(
      title: 'Resultados de ${candidate.operation} de '
          '${candidate.propertyType.toLowerCase()} en Bogotá',
      propertyType: candidate.propertyType,
      operation: candidate.operation,
      priceCop: null,
      areaM2: null,
      bedrooms: null,
      bathrooms: null,
      address: null,
      neighborhood: null,
      url: link.uri,
      source: source,
      missingData: const [],
      linkVerified: link.verified,
      approximateLocation: false,
      latitude: null,
      longitude: null,
      isListingPage: true,
    );
  }

  Future<({Uri uri, String title, bool verified})?>
      _extractIndividualListingLink(Uri listingPage, String source) async {
    if (kIsWeb) return null;
    try {
      final request = http.Request('GET', listingPage)
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await _client.send(request).timeout(_requestTimeout);
      final pageUri = response.request?.url ?? listingPage;
      final pageClassification =
          classifyAiPropertySearchUrl(pageUri.toString());
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          pageClassification == null ||
          !pageClassification.isListingPage ||
          pageClassification.source != source) {
        await response.stream.listen((_) {}).cancel();
        return null;
      }

      const maxHtmlBytes = 2 * 1024 * 1024;
      final pageBytes = <int>[];
      await for (final chunk in response.stream.timeout(_requestTimeout)) {
        final remaining = maxHtmlBytes - pageBytes.length;
        if (remaining <= 0) break;
        pageBytes.addAll(chunk.take(remaining));
        if (chunk.length >= remaining) break;
      }
      final document = html_parser.parse(
        utf8.decode(pageBytes, allowMalformed: true),
      );
      final visited = <String>{};
      var checkedLinks = 0;
      for (final anchor in document.querySelectorAll('a[href]')) {
        if (checkedLinks >= 2) break;
        final href = anchor.attributes['href']?.trim();
        if (href == null || href.isEmpty) continue;
        final target = pageUri.resolve(href);
        final classification = classifyAiPropertySearchUrl(target.toString());
        if (classification == null ||
            classification.isListingPage ||
            classification.source != source ||
            !visited.add(classification.uri.toString())) {
          continue;
        }

        checkedLinks++;
        final verified = await _checkLink(
          classification.uri,
          keepOnTimeout: true,
          timeout: const Duration(seconds: 2),
        );
        if (verified == null ||
            verified.isListingPage ||
            _sourceForHost(verified.uri.host) != source) {
          continue;
        }
        final title = anchor.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return (
          uri: verified.uri,
          title: title,
          verified: verified.verified,
        );
      }
      return null;
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  Uri? _candidateGroundingRedirect(String? rawUri) {
    if (rawUri == null) return null;
    final uri = Uri.tryParse(rawUri);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != _vertexRedirectHost) {
      return null;
    }
    return uri;
  }

  Uri? _matchingGroundingRedirect(
    AiPropertySearchCandidate candidate,
    List<GroundingChunk> chunks,
  ) {
    final expectedDomain = _domainForSource(candidate.source);
    if (expectedDomain == null) return null;
    final titleWords = _titleWords(candidate.title);

    for (final chunk in chunks) {
      final web = chunk.web;
      final rawUri = web?.uri;
      final title = web?.title;
      if (rawUri == null || title == null) continue;
      final redirect = Uri.tryParse(rawUri);
      if (redirect == null ||
          redirect.scheme != 'https' ||
          redirect.host != _vertexRedirectHost) {
        continue;
      }

      final domainText = '${web?.domain ?? ''} $title $rawUri'.toLowerCase();
      if (!domainText.contains(expectedDomain) &&
          !_titleWords(title).any(titleWords.contains)) {
        continue;
      }
      return redirect;
    }
    return null;
  }

  Set<String> _titleWords(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.length > 3)
      .toSet();

  Future<_ResolvedLink?> _checkLink(
    Uri uri, {
    required bool keepOnTimeout,
    Duration timeout = _requestTimeout,
  }) async {
    try {
      var currentUri = uri;
      for (var redirects = 0; redirects <= 5; redirects++) {
        final request = http.Request('GET', currentUri)
          ..followRedirects = false
          ..headers['Range'] = 'bytes=0-0';
        final response = await _client.send(request).timeout(timeout);
        final location = response.headers['location'];
        await response.stream.listen((_) {}).cancel();

        if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
          if (redirects == 5 || location == null) return null;
          currentUri = currentUri.resolve(location);
          if (currentUri.scheme != 'https') return null;
          continue;
        }

        final classification = classifyAiPropertySearchUrl(
          currentUri.toString(),
        );
        if (classification == null) return null;
        if (response.statusCode == 404 || response.statusCode == 410) {
          return null;
        }
        if (response.statusCode == 403 || response.statusCode == 429) {
          return _ResolvedLink(
            currentUri,
            false,
            isListingPage: classification.isListingPage,
          );
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _ResolvedLink(
            currentUri,
            classification.matchesIndividualPattern ||
                classification.isListingPage,
            isListingPage: classification.isListingPage,
          );
        }
        return null;
      }
      return null;
    } on TimeoutException {
      final classification = classifyAiPropertySearchUrl(uri.toString());
      if (keepOnTimeout && classification != null) {
        return _ResolvedLink(
          uri,
          false,
          isListingPage: classification.isListingPage,
        );
      }
      return null;
    } on http.ClientException {
      return null;
    }
  }

  Future<({double? latitude, double? longitude, bool approximate})> _geocode(
    AiPropertySearchCandidate candidate,
  ) async {
    if (kIsWeb) return (latitude: null, longitude: null, approximate: false);

    final address = candidate.address?.trim() ?? '';
    if (address.isNotEmpty) {
      final exact = await _geocodeAddress('$address, Bogotá, Colombia');
      if (exact != null) {
        return (
          latitude: exact.latitude,
          longitude: exact.longitude,
          approximate: false,
        );
      }
    }

    final neighborhood = candidate.neighborhood?.trim() ?? '';
    if (neighborhood.isNotEmpty) {
      final approximate = await _geocodeAddress('$neighborhood, Bogotá');
      if (approximate != null) {
        return (
          latitude: approximate.latitude,
          longitude: approximate.longitude,
          approximate: true,
        );
      }
    }
    return (latitude: null, longitude: null, approximate: false);
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final locations =
          await geocoding.Geocoding().locationFromAddress(address).timeout(
                _requestTimeout,
              );
      if (locations.isEmpty) return null;
      final first = locations.first;
      final point = LatLng(first.latitude, first.longitude);
      return MapConfig.isInsideBogota(point) ? point : null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> fetchListingImage(Uri listingUrl) async {
    if (kIsWeb || _sourceForHost(listingUrl.host) == null) return null;

    try {
      final stopwatch = Stopwatch()..start();
      final request = http.Request('GET', listingUrl)
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await _client.send(request).timeout(_requestTimeout);
      final finalUrl = response.request?.url ?? listingUrl;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          _sourceForHost(finalUrl.host) != _sourceForHost(listingUrl.host)) {
        await response.stream.listen((_) {}).cancel();
        return null;
      }

      final remaining = _requestTimeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        await response.stream.listen((_) {}).cancel();
        return null;
      }
      final page = await response.stream
          .transform(utf8.decoder)
          .join()
          .timeout(remaining);
      final document = html_parser.parse(page);
      final imageContent = document
              .querySelector('meta[property="og:image"]')
              ?.attributes['content'] ??
          document
              .querySelector('meta[name="og:image"]')
              ?.attributes['content'] ??
          document
              .querySelector('meta[name="twitter:image"]')
              ?.attributes['content'] ??
          document
              .querySelector('meta[property="twitter:image"]')
              ?.attributes['content'];
      final value = imageContent?.trim();
      if (value == null || value.isEmpty) return null;

      final imageUrl = finalUrl.resolve(value);
      if ((imageUrl.scheme != 'https' && imageUrl.scheme != 'http') ||
          imageUrl.host.isEmpty) {
        return null;
      }
      return imageUrl.toString();
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
