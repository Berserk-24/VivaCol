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

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.buscador,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
    };
  }

  AppUser copyWith({String? name, String? email, UserRole? role}) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}
