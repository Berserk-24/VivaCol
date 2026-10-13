import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/map_config.dart';
import '../../models/property.dart';
import '../../models/property_status.dart';
import '../../models/property_type.dart';
import '../../services/property_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/price_range_dialog.dart';

/// Radio (en metros) para considerar una propiedad "cercana".
const double _radiusMeters = 2000;

/// Mapa de Bogota con las propiedades publicadas. Detecta la ubicacion
/// del usuario y muestra por defecto las propiedades a ~2 km, con filtros.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Propiedades cerca de ti')),
      body: kIsWeb ? const _WebNotice() : const _NearbyMap(),
    );
  }
}

class _WebNotice extends StatelessWidget {
  const _WebNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined,
                size: 64, color: AppColors.mediumGray),
            const SizedBox(height: 12),
            Text(
              'El mapa solo esta disponible en Android.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyMap extends StatefulWidget {
  const _NearbyMap();

  @override
  State<_NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<_NearbyMap> {
  GoogleMapController? _controller;
  Position? _userPos;
  bool _locating = true;
  String? _locMessage;

  bool _onlyNearby = true;
  PropertyType? _type;
  ListingType? _listing;
  double? _minPrice;
  double? _maxPrice;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationUnavailable(
          'Activa la ubicacion para ver propiedades cercanas.',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setLocationUnavailable('Permiso de ubicacion denegado.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      if (!MapConfig.isInsideBogota(point)) {
        _setLocationUnavailable(
          'Estas fuera de Bogota. Mostrando todas las propiedades.',
        );
        return;
      }
      setState(() {
        _userPos = pos;
        _locating = false;
      });
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(point, 14));
    } catch (_) {
      _setLocationUnavailable('No se pudo obtener tu ubicacion.');
    }
  }

  void _setLocationUnavailable(String message) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _onlyNearby = false;
      _locMessage = message;
    });
  }

  Future<void> _editPrice() async {
    final result = await showPriceRangeDialog(
      context,
      min: _minPrice,
      max: _maxPrice,
    );
    if (result == null) return;
    setState(() {
      _minPrice = result.min;
      _maxPrice = result.max;
    });
  }

  List<Property> _filtered(List<Property> all) {
    return all.where((p) {
      if (!p.hasLocation) return false;
      if (_type != null && p.type != _type) return false;
      if (_listing != null && p.listingType != _listing) return false;
      if (_minPrice != null && p.price < _minPrice!) return false;
      if (_maxPrice != null && p.price > _maxPrice!) return false;
      if (_onlyNearby && _userPos != null) {
        final distance = Geolocator.distanceBetween(
          _userPos!.latitude,
          _userPos!.longitude,
          p.latitude!,
          p.longitude!,
        );
        if (distance > _radiusMeters) return false;
      }
      return true;
    }).toList();
  }

  double _hueFor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.verificado:
        return BitmapDescriptor.hueGreen;
      case PropertyStatus.enRevision:
        return BitmapDescriptor.hueYellow;
      case PropertyStatus.alerta:
        return BitmapDescriptor.hueRed;
    }
  }

  Set<Marker> _buildMarkers(List<Property> properties) {
    return properties.map((p) {
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.latitude!, p.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(p.liveStatus())),
        infoWindow: InfoWindow(
          title: p.title,
          snippet: '${p.liveStatus().label} · ${p.location}',
          onTap: () => context.push('/property/${p.id}'),
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PropertyRepository>();
    return Column(
      children: [
        _MapFilters(
          onlyNearby: _onlyNearby,
          nearbyEnabled: _userPos != null,
          selectedType: _type,
          selectedListing: _listing,
          priceActive: _minPrice != null || _maxPrice != null,
          onNearbyChanged: (value) => setState(() => _onlyNearby = value),
          onTypeChanged: (value) => setState(() => _type = value),
          onListingChanged: (value) => setState(() => _listing = value),
          onPriceTap: _editPrice,
        ),
        if (_locMessage != null)
          Container(
            width: double.infinity,
            color: AppColors.statusReviewBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _locMessage!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.darkGray),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Property>>(
            stream: repo.watchProperties(),
            builder: (context, snapshot) {
              final filtered = _filtered(snapshot.data ?? const <Property>[]);
              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _userPos != null
                          ? LatLng(_userPos!.latitude, _userPos!.longitude)
                          : MapConfig.bogotaCenter,
                      zoom: _userPos != null ? 14 : MapConfig.defaultZoom,
                    ),
                    cameraTargetBounds: MapConfig.cameraBounds,
                    minMaxZoomPreference: MapConfig.zoomPreference,
                    myLocationEnabled: _userPos != null,
                    myLocationButtonEnabled: _userPos != null,
                    onMapCreated: (controller) {
                      _controller = controller;
                      final pos = _userPos;
                      if (pos != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(pos.latitude, pos.longitude),
                            14,
                          ),
                        );
                      }
                    },
                    circles: (_onlyNearby && _userPos != null)
                        ? {
                            Circle(
                              circleId: const CircleId('radio'),
                              center: LatLng(
                                _userPos!.latitude,
                                _userPos!.longitude,
                              ),
                              radius: _radiusMeters,
                              fillColor:
                                  AppColors.primaryBlue.withValues(alpha: 0.08),
                              strokeColor:
                                  AppColors.primaryBlue.withValues(alpha: 0.4),
                              strokeWidth: 1,
                            ),
                          }
                        : const <Circle>{},
                    markers: _buildMarkers(filtered),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _CountChip(
                      count: filtered.length,
                      nearby: _onlyNearby && _userPos != null,
                    ),
                  ),
                  if (_locating)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black12,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Barra de filtros del mapa: cercania, tipo, operacion y precio.
class _MapFilters extends StatelessWidget {
  final bool onlyNearby;
  final bool nearbyEnabled;
  final PropertyType? selectedType;
  final ListingType? selectedListing;
  final bool priceActive;
  final ValueChanged<bool> onNearbyChanged;
  final ValueChanged<PropertyType?> onTypeChanged;
  final ValueChanged<ListingType?> onListingChanged;
  final VoidCallback onPriceTap;

  const _MapFilters({
    required this.onlyNearby,
    required this.nearbyEnabled,
    required this.selectedType,
    required this.selectedListing,
    required this.priceActive,
    required this.onNearbyChanged,
    required this.onTypeChanged,
    required this.onListingChanged,
    required this.onPriceTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Cerca (2 km)'),
            avatar: const Icon(Icons.my_location, size: 18),
            selected: onlyNearby,
            onSelected: nearbyEnabled ? onNearbyChanged : null,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<PropertyType?>(
            onSelected: onTypeChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Todos los tipos')),
              ...PropertyType.values.map(
                (t) => PopupMenuItem(value: t, child: Text(t.label)),
              ),
            ],
            child: _MapChip(
              label: selectedType?.label ?? 'Tipo',
              active: selectedType != null,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<ListingType?>(
            onSelected: onListingChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Venta y arriendo')),
              ...ListingType.values.map(
                (t) => PopupMenuItem(value: t, child: Text(t.label)),
              ),
            ],
            child: _MapChip(
              label: selectedListing?.label ?? 'Operacion',
              active: selectedListing != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onPriceTap,
            child: _MapChip(label: 'Precio', active: priceActive),
          ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final String label;
  final bool active;

  const _MapChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppColors.primaryBlue : Theme.of(context).colorScheme.surface;
    final textColor = active ? AppColors.white : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: active ? AppColors.primaryBlue : AppColors.lightGray,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: textColor)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 18, color: textColor),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final bool nearby;

  const _CountChip({required this.count, required this.nearby});

  @override
  Widget build(BuildContext context) {
    final text = nearby
        ? '$count cerca de ti'
        : '$count ${count == 1 ? 'propiedad' : 'propiedades'}';
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
