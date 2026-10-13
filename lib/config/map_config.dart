import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Parametros del mapa. VivaCol solo cubre Bogota y su area metropolitana
/// (aprox. desde Soacha hasta Chia), por lo que el mapa se limita a esa zona.
class MapConfig {
  MapConfig._();

  /// Centro aproximado de Bogota.
  static const LatLng bogotaCenter = LatLng(4.6533, -74.0836);

  /// Limites del area cubierta: suroeste (Soacha) a noreste (Chia).
  static final LatLngBounds bogotaBounds = LatLngBounds(
    southwest: const LatLng(4.49, -74.25),
    northeast: const LatLng(4.87, -74.00),
  );

  static const double defaultZoom = 11;
  static const double minZoom = 10;
  static const double maxZoom = 18;

  /// Restringe el desplazamiento de la camara al area de Bogota.
  static CameraTargetBounds get cameraBounds =>
      CameraTargetBounds(bogotaBounds);

  static const MinMaxZoomPreference zoomPreference =
      MinMaxZoomPreference(minZoom, maxZoom);

  /// Verifica si una coordenada cae dentro del area cubierta.
  static bool isInsideBogota(LatLng point) => bogotaBounds.contains(point);
}
