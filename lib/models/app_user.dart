/// Perfil de usuario segun el rol dentro de la plataforma.
enum UserRole {
  buscador, // busca vivienda para comprar o arrendar
  propietario, // tiene una propiedad
  agencia, // agencia o corredor independiente (cliente principal)
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.buscador:
        return 'Busco vivienda';
      case UserRole.propietario:
        return 'Tengo una propiedad';
      case UserRole.agencia:
        return 'Agencia inmobiliaria';
    }
  }

  /// Indica si el rol puede publicar y gestionar propiedades.
  bool get canPublish =>
      this == UserRole.agencia || this == UserRole.propietario;
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}
