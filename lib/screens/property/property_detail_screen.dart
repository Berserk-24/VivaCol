import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/community_report.dart';
import '../../models/property.dart';
import '../../models/property_status.dart';
import '../../models/property_type.dart';
import '../../providers/ai_provider.dart';
import '../../services/ai_service.dart';
import '../../services/property_repository.dart';
import '../../services/reliability.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/status_badge.dart';
import '../map/property_location_screen.dart';

/// Pantalla de detalle de una propiedad con galeria, informacion,
/// estado de verificacion e historial de reportes de la comunidad.
class PropertyDetailScreen extends StatelessWidget {
  final String propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PropertyRepository>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: StreamBuilder<Property?>(
        stream: repo.watchProperty(propertyId),
        builder: (context, propSnap) {
          if (propSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final base = propSnap.data;
          if (base == null) {
            return const Center(
              child: Text('La propiedad no esta disponible.'),
            );
          }
          return StreamBuilder<List<CommunityReport>>(
            stream: repo.watchReports(propertyId),
            builder: (context, reportSnap) {
              // Un voto por usuario y sin el publicador para conteo, IA e historial.
              final votes = dedupeReports(
                reportSnap.data ?? const [],
                publisherId: base.publisherId,
              )..sort((a, b) => b.date.compareTo(a.date));
              final property = base.copyWith(reports: votes);
              return _DetailContent(property: property, textTheme: textTheme);
            },
          );
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final Property property;
  final TextTheme textTheme;

  const _DetailContent({required this.property, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _ContactBar(property: property),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              _Gallery(images: property.imageUrls),
              if (property.hasLocation)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _MapPinButton(property: property),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge(status: property.liveStatus()),
                    Text(
                      property.listingType.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  formatPrice(property.price),
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(property.title, style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.mediumGray),
                    const SizedBox(width: 4),
                    Text(property.location, style: textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                _FeatureRow(property: property),
                if (property.type.hasParking) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        property.parking
                            ? Icons.local_parking
                            : Icons.do_not_disturb_on_outlined,
                        size: 18,
                        color: property.parking
                            ? AppColors.accentGreen
                            : AppColors.mediumGray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        property.parking
                            ? 'Cuenta con parqueadero'
                            : 'Sin parqueadero',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                const Divider(height: 32),
                Text('Descripcion', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(property.description, style: textTheme.bodyMedium),
                const Divider(height: 32),
                _StatusInfo(property: property),
                if (property.reports.isNotEmpty &&
                    context.watch<AiProvider>().enabled) ...[
                  const Divider(height: 32),
                  _ReliabilitySummary(property: property),
                ],
                const Divider(height: 32),
                _ReportHistory(reports: property.reports),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  final List<String> images;

  const _Gallery({required this.images});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: images.isEmpty
          ? const ColoredBox(
              color: AppColors.lightGray,
              child: Center(
                child: Icon(Icons.home_outlined,
                    size: 48, color: AppColors.mediumGray),
              ),
            )
          : PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const ColoredBox(
                      color: AppColors.lightGray,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                    color: AppColors.lightGray,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppColors.mediumGray),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MapPinButton extends StatelessWidget {
  final Property property;

  const _MapPinButton({required this.property});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PropertyLocationScreen(property: property),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.location_on, color: AppColors.statusAlert),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final Property property;

  const _FeatureRow({required this.property});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (property.type.hasBedrooms)
          _FeatureItem(
            icon: Icons.bed_outlined,
            label: 'Habitaciones',
            value: '${property.bedrooms}',
          ),
        if (property.type.hasBathrooms)
          _FeatureItem(
            icon: Icons.bathtub_outlined,
            label: 'Banos',
            value: '${property.bathrooms}',
          ),
        _FeatureItem(
          icon: Icons.square_foot,
          label: 'Area',
          value: '${property.areaM2.round()} m2',
        ),
        _FeatureItem(
          icon: Icons.home_outlined,
          label: 'Tipo',
          value: property.type.label,
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryBlue),
        const SizedBox(height: 4),
        Text(value, style: textTheme.titleMedium),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final Property property;

  const _StatusInfo({required this.property});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = property.liveStatus();
    final confidence = (property.confidenceNow() * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(status.icon, color: status.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado: ${status.label}',
                  style: textTheme.titleMedium?.copyWith(color: status.color),
                ),
                const SizedBox(height: 2),
                Text(
                  'Confianza $confidence%. '
                  '${property.reports.length} reporte(s) recibidos.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportHistory extends StatelessWidget {
  final List<CommunityReport> reports;

  const _ReportHistory({required this.reports});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de reportes', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          Text(
            'Aun no hay reportes de la comunidad para esta propiedad.',
            style: textTheme.bodySmall,
          )
        else
          ...reports.map((r) => _ReportTile(report: r)),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  final CommunityReport report;

  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.offWhite,
            child: Icon(Icons.person_outline, color: AppColors.mediumGray),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(report.authorName, style: textTheme.titleMedium),
                    Text(
                      '${report.date.day}/${report.date.month}/${report.date.year}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
                Text(
                  report.type.label,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 2),
                Text(report.comment, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de confiabilidad generado con IA. Solo se muestra cuando hay
/// reportes y el usuario pulsa el boton para generarlo.
class _ReliabilitySummary extends StatefulWidget {
  final Property property;

  const _ReliabilitySummary({required this.property});

  @override
  State<_ReliabilitySummary> createState() => _ReliabilitySummaryState();
}

class _ReliabilitySummaryState extends State<_ReliabilitySummary> {
  bool _loading = false;
  String? _summary;
  String? _error;

  Future<void> _generate() async {
    final ai = context.read<AiService>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = await ai.generateReliabilitySummary(widget.property);
      if (!mounted) return;
      setState(() => _summary = text);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo generar el resumen.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome,
                size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 6),
            Text('Resumen de confiabilidad (IA)', style: textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        if (_summary != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_summary!, style: textTheme.bodyMedium),
          )
        else
          Text(
            'Genera un resumen con IA a partir de los reportes de la '
            'comunidad para esta publicacion.',
            style: textTheme.bodySmall,
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: textTheme.bodySmall?.copyWith(color: AppColors.statusAlert),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _loading
                  ? 'Generando...'
                  : _summary == null
                      ? 'Generar resumen'
                      : 'Regenerar',
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactBar extends StatelessWidget {
  final Property property;

  const _ContactBar({required this.property});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/report/${property.id}'),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Reportar cambio'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showContact(context, property),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contactar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContact(BuildContext context, Property property) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contactar publicante',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business, color: AppColors.primaryBlue),
              title: Text(property.publisherName),
              subtitle: const Text('Publicante verificado'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.call),
                label: const Text('Llamar ahora'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
