import 'community_report.dart';
import 'property_status.dart';
import 'property_type.dart';

/// Modelo principal de una publicacion inmobiliaria.
class Property {
  final String id;
  final String title;
  final String description;
  final double price;
  final String city;
  final String neighborhood;
  final String address;
  final PropertyType type;
  final ListingType listingType;
  final PropertyStatus status;
  final List<String> imageUrls;
  final int bedrooms;
  final int bathrooms;
  final double areaM2;
  final double? latitude;
  final double? longitude;
  final String publisherId;
  final String publisherName;
  final DateTime lastUpdated;
  final List<CommunityReport> reports;

  const Property({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.city,
    required this.neighborhood,
    this.address = '',
    required this.type,
    required this.listingType,
    required this.status,
    required this.imageUrls,
    required this.bedrooms,
    required this.bathrooms,
    required this.areaM2,
    this.latitude,
    this.longitude,
    this.publisherId = '',
    required this.publisherName,
    required this.lastUpdated,
    this.reports = const [],
  });

  String get location => '$neighborhood, $city';

  /// Indica si la propiedad tiene coordenadas para ubicarla en el mapa.
  bool get hasLocation => latitude != null && longitude != null;

  /// Crea una propiedad a partir de un documento de Firestore.
  /// Los reportes viven en una subcoleccion y se cargan por separado.
  factory Property.fromMap(
    String id,
    Map<String, dynamic> map, {
    List<CommunityReport> reports = const [],
  }) {
    final rawDate = map['lastUpdated'];
    return Property(
      id: id,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      price: (map['price'] ?? 0).toDouble() as double,
      city: (map['city'] ?? '') as String,
      neighborhood: (map['neighborhood'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      type: PropertyType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => PropertyType.apartamento,
      ),
      listingType: ListingType.values.firstWhere(
        (t) => t.name == map['listingType'],
        orElse: () => ListingType.venta,
      ),
      status: PropertyStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PropertyStatus.enRevision,
      ),
      imageUrls: List<String>.from(map['imageUrls'] ?? const <String>[]),
      bedrooms: (map['bedrooms'] ?? 0) as int,
      bathrooms: (map['bathrooms'] ?? 0) as int,
      areaM2: (map['areaM2'] ?? 0).toDouble() as double,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      publisherId: (map['publisherId'] ?? '') as String,
      publisherName: (map['publisherName'] ?? '') as String,
      lastUpdated: _parseDate(rawDate),
      reports: reports,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'city': city,
      'neighborhood': neighborhood,
      'address': address,
      'type': type.name,
      'listingType': listingType.name,
      'status': status.name,
      'imageUrls': imageUrls,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'areaM2': areaM2,
      'latitude': latitude,
      'longitude': longitude,
      'publisherId': publisherId,
      'publisherName': publisherName,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  Property copyWith({
    PropertyStatus? status,
    List<CommunityReport>? reports,
  }) {
    return Property(
      id: id,
      title: title,
      description: description,
      price: price,
      city: city,
      neighborhood: neighborhood,
      address: address,
      type: type,
      listingType: listingType,
      status: status ?? this.status,
      imageUrls: imageUrls,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      areaM2: areaM2,
      latitude: latitude,
      longitude: longitude,
      publisherId: publisherId,
      publisherName: publisherName,
      lastUpdated: lastUpdated,
      reports: reports ?? this.reports,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    try {
      return raw.toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
