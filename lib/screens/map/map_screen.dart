import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/map_config.dart';
import '../../models/property.dart';
import '../../models/property_status.dart';
import '../../services/property_repository.dart';
import '../../theme/app_colors.dart';

/// Mapa de Bogota con las propiedades publicadas. Cada marcador usa el
/// color del semaforo segun el estado de verificacion de la comunidad.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de propiedades')),
      body: kIsWeb ? const _WebNotice() : const _PropertiesMap(),
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

class _PropertiesMap extends StatelessWidget {
  const _PropertiesMap();

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

  Set<Marker> _buildMarkers(BuildContext context, List<Property> properties) {
    return properties.where((p) => p.hasLocation).map((p) {
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.latitude!, p.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(p.status)),
        infoWindow: InfoWindow(
          title: p.title,
          snippet: '${p.status.label} · ${p.location}',
          onTap: () => context.push('/property/${p.id}'),
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PropertyRepository>();
    return StreamBuilder<List<Property>>(
      stream: repo.watchProperties(),
      builder: (context, snapshot) {
        final properties = snapshot.data ?? const <Property>[];
        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: MapConfig.bogotaCenter,
            zoom: MapConfig.defaultZoom,
          ),
          cameraTargetBounds: MapConfig.cameraBounds,
          minMaxZoomPreference: MapConfig.zoomPreference,
          myLocationButtonEnabled: false,
          markers: _buildMarkers(context, properties),
        );
      },
    );
  }
}
