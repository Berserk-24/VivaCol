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
  final PropertyType type;
  final ListingType listingType;
  final PropertyStatus status;
  final List<String> imageUrls;
  final int bedrooms;
  final int bathrooms;
  final double areaM2;
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
    required this.type,
    required this.listingType,
    required this.status,
    required this.imageUrls,
    required this.bedrooms,
    required this.bathrooms,
    required this.areaM2,
    required this.publisherName,
    required this.lastUpdated,
    this.reports = const [],
  });

  String get location => '$neighborhood, $city';
}
