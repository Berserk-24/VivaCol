class AiPropertySearchInterpretation {
  final String operation;
  final String propertyType;
  final int? maxPrice;
  final String? zone;
  final List<String> assumptions;

  const AiPropertySearchInterpretation({
    required this.operation,
    required this.propertyType,
    required this.maxPrice,
    required this.zone,
    required this.assumptions,
  });
}

class AiPropertySearchCandidate {
  final String title;
  final String propertyType;
  final String operation;
  final int? priceCop;
  final double? areaM2;
  final int? bedrooms;
  final int? bathrooms;
  final String? address;
  final String? neighborhood;
  final String? url;
  final String source;
  final List<String> missingData;

  const AiPropertySearchCandidate({
    required this.title,
    required this.propertyType,
    required this.operation,
    required this.priceCop,
    required this.areaM2,
    required this.bedrooms,
    required this.bathrooms,
    required this.address,
    required this.neighborhood,
    required this.url,
    required this.source,
    required this.missingData,
  });
}

class AiPropertySearchPayload {
  final AiPropertySearchInterpretation? interpretation;
  final List<AiPropertySearchCandidate> candidates;
  final String? message;

  const AiPropertySearchPayload({
    required this.interpretation,
    required this.candidates,
    required this.message,
  });
}

class AiPropertySearchListing {
  final String title;
  final String propertyType;
  final String operation;
  final int? priceCop;
  final double? areaM2;
  final int? bedrooms;
  final int? bathrooms;
  final String? address;
  final String? neighborhood;
  final Uri url;
  final String source;
  final List<String> missingData;
  final bool linkVerified;
  final bool approximateLocation;
  final double? latitude;
  final double? longitude;

  const AiPropertySearchListing({
    required this.title,
    required this.propertyType,
    required this.operation,
    required this.priceCop,
    required this.areaM2,
    required this.bedrooms,
    required this.bathrooms,
    required this.address,
    required this.neighborhood,
    required this.url,
    required this.source,
    required this.missingData,
    required this.linkVerified,
    required this.approximateLocation,
    required this.latitude,
    required this.longitude,
  });
}

class AiPropertySearchResponse {
  final List<AiPropertySearchListing> listings;
  final AiPropertySearchInterpretation? interpretation;
  final bool grounded;
  final String? searchEntryPointHtml;
  final String? message;
  final String? hint;

  const AiPropertySearchResponse({
    this.listings = const [],
    this.interpretation,
    this.grounded = false,
    this.searchEntryPointHtml,
    this.message,
    this.hint,
  });
}

class SavedAiPropertyListing {
  final String id;
  final String title;
  final String propertyType;
  final String operation;
  final int? priceCop;
  final double? areaM2;
  final int? bedrooms;
  final int? bathrooms;
  final String? address;
  final String? neighborhood;
  final Uri url;
  final String source;
  final List<String> missingData;
  final DateTime savedAt;

  const SavedAiPropertyListing({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.operation,
    required this.priceCop,
    required this.areaM2,
    required this.bedrooms,
    required this.bathrooms,
    required this.address,
    required this.neighborhood,
    required this.url,
    required this.source,
    required this.missingData,
    required this.savedAt,
  });

  factory SavedAiPropertyListing.fromMap(
    String id,
    Map<String, dynamic> map,
    DateTime savedAt,
  ) {
    return SavedAiPropertyListing(
      id: id,
      title: map['title'] as String? ?? '',
      propertyType: map['propertyType'] as String? ?? '',
      operation: map['operation'] as String? ?? '',
      priceCop: (map['priceCop'] as num?)?.toInt(),
      areaM2: (map['areaM2'] as num?)?.toDouble(),
      bedrooms: (map['bedrooms'] as num?)?.toInt(),
      bathrooms: (map['bathrooms'] as num?)?.toInt(),
      address: map['address'] as String?,
      neighborhood: map['neighborhood'] as String?,
      url: Uri.parse(map['url'] as String),
      source: map['source'] as String? ?? '',
      missingData: List<String>.from(map['missingData'] ?? const <String>[]),
      savedAt: savedAt,
    );
  }
}
