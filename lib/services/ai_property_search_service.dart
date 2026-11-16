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

const String _searchModelName = 'gemini-3.8-flash';
const Duration _requestTimeout = Duration(seconds: 5);
const String _vertexRedirectHost = 'vertexaisearch.cloud.google.com';

const String _searchSystemInstruction = '''
Eres un asistente de búsqueda inmobiliaria para VivaCol, una app de Bogotá, Colombia.

TAREA
Interpreta la petición del usuario y usa la búsqueda web en esta misma respuesta para encontrar hasta 5 avisos REALES de inmuebles en Bogotá. Hazlo todo en una sola respuesta, sin hacer preguntas ni pedir confirmaciones.

REGLAS DE BÚSQUEDA
- Solo inmuebles ubicados en Bogotá, Colombia. Si la petición es de otra ciudad, devuelve "resultados": [] y explícalo en "mensaje".
- Solo avisos publicados en fincaraiz.com.co, metrocuadrado.com o ciencuadras.com.
- Interpreta el precio como MÁXIMO. Si el usuario no dice si es venta o arriendo, deduce por el monto (cientos de millones suelen ser venta; pocos millones suelen ser arriendo mensual) y registra la deducción en "supuestos".
- Si el usuario indica un barrio o una localidad, busca avisos ahí.

REGLAS DE ENLACE (MUY IMPORTANTES)
- "url" debe ser el enlace directo a la página de detalle de ESE aviso. No uses la página principal, un buscador, un listado ni una categoría.
- Copia la URL exactamente como la encontraste. Nunca la construyas ni la completes. Si no encontraste el enlace directo del aviso, no incluyas ese aviso.

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
  if (segments.isEmpty ||
      segments.any(AiPropertySearchUrlPatterns.indexRouteNames.contains)) {
    return null;
  }
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
    );
  }

  if (!_passesConservativeHeuristic(segments)) return null;
  return AiPropertySearchUrlClassification(
    uri: uri,
    source: source,
    matchesIndividualPattern: false,
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

  const AiPropertySearchUrlClassification({
    required this.uri,
    required this.source,
    required this.matchesIndividualPattern,
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

  const _ResolvedLink(this.uri, this.verified);
}

class AiPropertySearchService {
  AiPropertySearchService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  GenerativeModel? _model;

  GenerativeModel get _searchModel =>
      _model ??= FirebaseAI.googleAI().generativeModel(
        model: _searchModelName,
        tools: [Tool.googleSearch()],
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
      if (metadata == null || metadata.webSearchQueries.isEmpty) {
        return const AiPropertySearchResponse(
          message: noAiPropertySearchResultsMessage,
        );
      }

      final otherCity = _unsupportedCity(query);
      if (otherCity != null) {
        return AiPropertySearchResponse(
          grounded: true,
          searchEntryPointHtml: metadata.searchEntryPoint?.renderedContent,
          message:
              'Por ahora la búsqueda inmobiliaria con IA solo admite Bogotá. '
              'La solicitud menciona $otherCity.',
        );
      }

      final parsed = parseAiPropertySearchJson(response.text ?? '');
      if (parsed == null) {
        return AiPropertySearchResponse(
          grounded: true,
          searchEntryPointHtml: metadata.searchEntryPoint?.renderedContent,
          message: noAiPropertySearchResultsMessage,
        );
      }

      final listings = <AiPropertySearchListing>[];
      final seenUrls = <String>{};
      for (final item in parsed.candidates) {
        final link = await _resolveListingLink(item, metadata.groundingChunks);
        if (link == null || !seenUrls.add(link.uri.toString())) continue;
        final location = await _geocode(item);
        listings.add(
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
            source: _sourceForHost(link.uri.host)!,
            missingData: item.missingData,
            linkVerified: link.verified,
            approximateLocation: location.approximate,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
        if (listings.length == 5) break;
      }

      final message =
          listings.isEmpty ? noAiPropertySearchResultsMessage : parsed.message;
      return AiPropertySearchResponse(
        listings: listings,
        interpretation: parsed.interpretation,
        grounded: true,
        searchEntryPointHtml: metadata.searchEntryPoint?.renderedContent,
        message: message,
      );
    } catch (error) {
      debugPrint('VivaCol búsqueda IA: $error');
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
      if (kIsWeb) return _ResolvedLink(directClassification.uri, false);
      return _checkLink(directClassification.uri, keepOnTimeout: true);
    }

    if (kIsWeb) return null;
    final redirectUri = _matchingGroundingRedirect(candidate, chunks);
    if (redirectUri == null) return null;
    final resolved = await _checkLink(redirectUri, keepOnTimeout: false);
    if (resolved == null ||
        classifyAiPropertySearchUrl(resolved.uri.toString()) == null) {
      return null;
    }
    return resolved;
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
  }) async {
    try {
      var currentUri = uri;
      for (var redirects = 0; redirects <= 5; redirects++) {
        final request = http.Request('GET', currentUri)
          ..followRedirects = false
          ..headers['Range'] = 'bytes=0-0';
        final response = await _client.send(request).timeout(_requestTimeout);
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
          return _ResolvedLink(currentUri, false);
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _ResolvedLink(
              currentUri, classification.matchesIndividualPattern);
        }
        return null;
      }
      return null;
    } on TimeoutException {
      if (keepOnTimeout &&
          classifyAiPropertySearchUrl(uri.toString()) != null) {
        return _ResolvedLink(uri, false);
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
