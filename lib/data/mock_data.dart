import '../models/app_user.dart';
import '../models/community_report.dart';
import '../models/property.dart';
import '../models/property_status.dart';
import '../models/property_type.dart';

/// Datos de ejemplo para el prototipo. No hay backend real todavia.
class MockData {
  MockData._();

  static const AppUser currentUser = AppUser(
    id: 'u1',
    name: 'Inmobiliaria Andina',
    email: 'contacto@andina.co',
    role: UserRole.agencia,
  );

  static final List<Property> properties = [
    Property(
      id: 'p1',
      title: 'Apartamento luminoso con vista',
      description: 'Apartamento remodelado con excelente iluminacion natural, '
          'cocina integral y balcon. Cerca de transporte y comercio.',
      price: 320000000,
      city: 'Bogota',
      neighborhood: 'Chapinero',
      type: PropertyType.apartamento,
      listingType: ListingType.venta,
      status: PropertyStatus.verificado,
      imageUrls: const [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267',
        'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688',
      ],
      bedrooms: 3,
      bathrooms: 2,
      areaM2: 78,
      publisherName: 'Inmobiliaria Andina',
      lastUpdated: DateTime(2026, 9, 18),
      reports: [
        CommunityReport(
          id: 'r1',
          propertyId: 'p1',
          type: ReportType.disponible,
          authorName: 'Carlos M.',
          comment: 'Llame y sigue disponible, atienden rapido.',
          date: DateTime(2026, 9, 17),
        ),
        CommunityReport(
          id: 'r2',
          propertyId: 'p1',
          type: ReportType.disponible,
          authorName: 'Laura P.',
          comment: 'Visite el inmueble, todo coincide con la publicacion.',
          date: DateTime(2026, 9, 15),
        ),
      ],
    ),
    Property(
      id: 'p2',
      title: 'Casa amplia para familia',
      description: 'Casa de dos pisos con patio, garaje para dos vehiculos y '
          'zona de ropas. Barrio residencial tranquilo.',
      price: 2500000,
      city: 'Medellin',
      neighborhood: 'Laureles',
      type: PropertyType.casa,
      listingType: ListingType.arriendo,
      status: PropertyStatus.enRevision,
      imageUrls: const [
        'https://images.unsplash.com/photo-1568605114967-8130f3a36994',
        'https://images.unsplash.com/photo-1570129477492-45c003edd2be',
      ],
      bedrooms: 4,
      bathrooms: 3,
      areaM2: 160,
      publisherName: 'Corredor Juan Ríos',
      lastUpdated: DateTime(2026, 9, 10),
      reports: [
        CommunityReport(
          id: 'r3',
          propertyId: 'p2',
          type: ReportType.cambioPrecio,
          authorName: 'Andrea G.',
          comment: 'Me dijeron que el canon subio, verificar precio.',
          date: DateTime(2026, 9, 12),
        ),
      ],
    ),
    Property(
      id: 'p3',
      title: 'Oficina en zona empresarial',
      description: 'Oficina en piso alto con recepcion, sala de juntas y '
          'excelente conectividad. Ideal para pymes.',
      price: 4200000,
      city: 'Bogota',
      neighborhood: 'Salitre',
      type: PropertyType.oficina,
      listingType: ListingType.arriendo,
      status: PropertyStatus.alerta,
      imageUrls: const [
        'https://images.unsplash.com/photo-1497366216548-37526070297c',
      ],
      bedrooms: 0,
      bathrooms: 2,
      areaM2: 95,
      publisherName: 'Inmobiliaria Andina',
      lastUpdated: DateTime(2026, 8, 30),
      reports: [
        CommunityReport(
          id: 'r4',
          propertyId: 'p3',
          type: ReportType.noExiste,
          authorName: 'Pedro L.',
          comment: 'El numero ya no funciona, creo que se arrendo.',
          date: DateTime(2026, 9, 5),
        ),
        CommunityReport(
          id: 'r5',
          propertyId: 'p3',
          type: ReportType.noExiste,
          authorName: 'Sofia R.',
          comment: 'Fui a la direccion y esta ocupada.',
          date: DateTime(2026, 9, 8),
        ),
      ],
    ),
    Property(
      id: 'p4',
      title: 'Apartaestudio economico',
      description:
          'Apartaestudio ideal para estudiantes, incluye administracion '
          'y esta cerca de la universidad.',
      price: 1200000,
      city: 'Cali',
      neighborhood: 'San Fernando',
      type: PropertyType.apartamento,
      listingType: ListingType.arriendo,
      status: PropertyStatus.verificado,
      imageUrls: const [
        'https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6',
      ],
      bedrooms: 1,
      bathrooms: 1,
      areaM2: 32,
      publisherName: 'Corredor Juan Ríos',
      lastUpdated: DateTime(2026, 9, 19),
      reports: const [],
    ),
  ];

  static const List<String> cities = [
    'Todas',
    'Bogota',
    'Medellin',
    'Cali',
  ];
}
