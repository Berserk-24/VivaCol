import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/property.dart';
import '../../models/property_status.dart';

/// Muestra en el mapa la ubicacion registrada de una sola propiedad.
class PropertyLocationScreen extends StatelessWidget {
  final Property property;

  const PropertyLocationScreen({super.key, required this.property});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicacion')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (!property.hasLocation) {
      return const Center(child: Text('Esta propiedad no tiene ubicacion.'));
    }
    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'El mapa solo esta disponible en Android.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final target = LatLng(property.latitude!, property.longitude!);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: target, zoom: 16),
      myLocationButtonEnabled: false,
      markers: {
        Marker(
          markerId: MarkerId(property.id.isEmpty ? 'propiedad' : property.id),
          position: target,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _hueFor(property.liveStatus())),
          infoWindow: InfoWindow(
            title: property.title,
            snippet: property.address.isNotEmpty
                ? property.address
                : property.location,
          ),
        ),
      },
    );
  }
}
