/// Tipo de operacion sobre una propiedad.
enum ListingType { venta, arriendo }

extension ListingTypeX on ListingType {
  String get label {
    switch (this) {
      case ListingType.venta:
        return 'Venta';
      case ListingType.arriendo:
        return 'Arriendo';
    }
  }
}

/// Categoria del inmueble.
enum PropertyType { apartamento, casa, oficina, local, lote }

extension PropertyTypeX on PropertyType {
  String get label {
    switch (this) {
      case PropertyType.apartamento:
        return 'Apartamento';
      case PropertyType.casa:
        return 'Casa';
      case PropertyType.oficina:
        return 'Oficina';
      case PropertyType.local:
        return 'Local';
      case PropertyType.lote:
        return 'Lote';
    }
  }

  /// Vivienda (apartamento/casa) reporta habitaciones; el resto no.
  bool get hasBedrooms =>
      this == PropertyType.apartamento || this == PropertyType.casa;

  /// Los lotes no tienen banos; el resto si.
  bool get hasBathrooms => this != PropertyType.lote;
}
