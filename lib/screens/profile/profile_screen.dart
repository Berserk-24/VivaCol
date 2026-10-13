import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/property_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/status_badge.dart';

/// Perfil del usuario. Si es agencia o propietario, muestra ademas
/// las propiedades que ha publicado.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
            _PublishedList(user: user),
          ] else
            Text(
              'Estas buscando vivienda. Explora el listado y reporta '
              'cambios para ayudar a la comunidad.',
              style: textTheme.bodyMedium,
            ),
          const SizedBox(height: 24),
          Card(
            child: SwitchListTile(
              value: context.watch<ThemeProvider>().isDark,
              onChanged: (_) => context.read<ThemeProvider>().toggle(),
              secondary: Icon(
                context.watch<ThemeProvider>().isDark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              title: const Text('Modo oscuro'),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Seguro que deseas cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}

/// Lista en tiempo real de las publicaciones del usuario.
class _PublishedList extends StatelessWidget {
  final AppUser user;

  const _PublishedList({required this.user});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PropertyRepository>();
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<Property>>(
      stream: repo.watchProperties(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final published =
            snapshot.data!.where((p) => p.publisherId == user.id).toList();
        if (published.isEmpty) {
          return Text('Aun no tienes publicaciones.',
              style: textTheme.bodySmall);
        }
        return Column(
          children: published
              .map(
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
              )
              .toList(),
        );
      },
    );
  }
}
