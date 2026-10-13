/// Localidades de Bogota y municipios vecinos cubiertos por VivaCol
/// (area metropolitana: de Soacha a Chia). Se usan en el filtro del home
/// y en el selector de ubicacion al publicar.
class BogotaLocalities {
  BogotaLocalities._();

  static const List<String> all = [
    'Usaquen',
    'Chapinero',
    'Santa Fe',
    'San Cristobal',
    'Usme',
    'Tunjuelito',
    'Bosa',
    'Kennedy',
    'Fontibon',
    'Engativa',
    'Suba',
    'Barrios Unidos',
    'Teusaquillo',
    'Los Martires',
    'Antonio Narino',
    'Puente Aranda',
    'La Candelaria',
    'Rafael Uribe Uribe',
    'Ciudad Bolivar',
    'Sumapaz',
    'Soacha',
    'Chia',
  ];

  /// Lista con la opcion "Todas" al inicio para el filtro del home.
  static const List<String> withAll = ['Todas', ...all];
}
