import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/status_badge.dart';

/// Perfil del usuario. Si es agencia o propietario, muestra ademas
/// las propiedades que ha publicado.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;
    final textTheme = Theme.of(context).textTheme;

    final published =
        MockData.properties.where((p) => p.publisherName == user.name).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.primaryBlue,
                child: Icon(Icons.person, size: 36, color: AppColors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: textTheme.titleLarge),
                    Text(user.email, style: textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.role.label,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (user.role.canPublish) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mis publicaciones', style: textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () => context.push('/publish'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (published.isEmpty)
              Text('Aun no tienes publicaciones.', style: textTheme.bodySmall)
            else
              ...published.map(
                (p) => Card(
                  child: ListTile(
                    onTap: () => context.push('/property/${p.id}'),
                    leading: const Icon(Icons.home_outlined,
                        color: AppColors.primaryBlue),
                    title: Text(p.title),
                    subtitle: Text(formatPrice(p.price)),
                    trailing: StatusBadge(status: p.status, compact: true),
                  ),
                ),
              ),
          ] else
            Text(
              'Estas buscando vivienda. Explora el listado y reporta '
              'cambios para ayudar a la comunidad.',
              style: textTheme.bodyMedium,
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}
