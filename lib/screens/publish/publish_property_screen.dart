import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/property_type.dart';
import '../../theme/app_colors.dart';

/// Formulario para publicar una propiedad. Disponible solo para
/// agencias y propietarios. En el prototipo no persiste datos reales.
class PublishPropertyScreen extends StatefulWidget {
  const PublishPropertyScreen({super.key});

  @override
  State<PublishPropertyScreen> createState() => _PublishPropertyScreenState();
}

class _PublishPropertyScreenState extends State<PublishPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  PropertyType _type = PropertyType.apartamento;
  ListingType _listingType = ListingType.venta;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Propiedad publicada (simulado).'),
        backgroundColor: AppColors.accentGreen,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar propiedad')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePlaceholder(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titulo'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripcion'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixText: '\$ ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un precio';
                }
                if (double.tryParse(value) == null) {
                  return 'Solo numeros';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration:
                  const InputDecoration(labelText: 'Ciudad y ubicacion'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            Text('Tipo de inmueble', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<PropertyType>(
              initialValue: _type,
              items: PropertyType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 16),
            Text('Operacion', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ListingType>(
              segments: ListingType.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                  .toList(),
              selected: {_listingType},
              onSelectionChanged: (value) =>
                  setState(() => _listingType = value.first),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carga de imagenes (simulado).')),
        );
      },
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.lightGray,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 40, color: AppColors.mediumGray),
            SizedBox(height: 8),
            Text('Agregar fotos',
                style: TextStyle(color: AppColors.mediumGray)),
          ],
        ),
      ),
    );
  }
}
