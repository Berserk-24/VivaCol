import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../models/community_report.dart';
import '../../models/property.dart';
import '../../theme/app_colors.dart';

/// Formulario donde un usuario reporta un cambio sobre una propiedad:
/// sigue disponible, cambio de precio o ya no existe.
class ReportChangeScreen extends StatefulWidget {
  final String propertyId;

  const ReportChangeScreen({super.key, required this.propertyId});

  @override
  State<ReportChangeScreen> createState() => _ReportChangeScreenState();
}

class _ReportChangeScreenState extends State<ReportChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();

  ReportType _selectedType = ReportType.disponible;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Property get _property => MockData.properties.firstWhere(
        (p) => p.id == widget.propertyId,
        orElse: () => MockData.properties.first,
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    // Simulacion de envio: en el prototipo no hay backend real.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias, tu reporte ayuda a la comunidad.'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar cambio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: Row(
                children: [
                  const Icon(Icons.home_outlined, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_property.title, style: textTheme.titleMedium),
                        Text(_property.location, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Que quieres reportar?', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<ReportType>(
              groupValue: _selectedType,
              onChanged: (value) =>
                  setState(() => _selectedType = value ?? _selectedType),
              child: Column(
                children: ReportType.values
                    .map(
                      (type) => RadioListTile<ReportType>(
                        value: type,
                        title: Text(type.label),
                        activeColor: AppColors.primaryBlue,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Comentario', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Cuentanos que observaste (opcional para disponible)',
              ),
              validator: (value) {
                if (_selectedType != ReportType.disponible &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Agrega un comentario para este tipo de reporte';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Enviando...' : 'Enviar reporte'),
            ),
          ],
        ),
      ),
    );
  }
}
