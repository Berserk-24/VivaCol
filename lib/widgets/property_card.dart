import 'package:flutter/material.dart';

import '../models/property.dart';
import '../models/property_type.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'status_badge.dart';

/// Tarjeta que resume una propiedad en el listado principal.
class PropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;

  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _CoverImage(
                  url: property.imageUrls.isNotEmpty
                      ? property.imageUrls.first
                      : null,
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: StatusBadge(status: property.liveStatus()),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      property.listingType.label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPrice(property.price),
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: AppColors.mediumGray),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (property.type.hasBedrooms)
                        _Feature(
                          icon: Icons.bed_outlined,
                          value: '${property.bedrooms}',
                        ),
                      if (property.type.hasBathrooms)
                        _Feature(
                          icon: Icons.bathtub_outlined,
                          value: '${property.bathrooms}',
                        ),
                      _Feature(
                        icon: Icons.square_foot,
                        value: '${property.areaM2.round()} m2',
                      ),
                      if (property.parking)
                        const _Feature(
                          icon: Icons.local_parking,
                          value: 'Si',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String? url;

  const _CoverImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) {
      return const SizedBox(
        height: 170,
        width: double.infinity,
        child: ColoredBox(
          color: AppColors.lightGray,
          child: Center(
            child: Icon(Icons.home_outlined,
                size: 40, color: AppColors.mediumGray),
          ),
        ),
      );
    }
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Image.network(
        source,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: AppColors.lightGray,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: AppColors.lightGray,
          child: Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: AppColors.mediumGray),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Feature({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mediumGray),
          const SizedBox(width: 4),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
