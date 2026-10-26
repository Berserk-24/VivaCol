import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/bogota_localities.dart';
import '../../config/map_config.dart';
import '../../models/property.dart';
import '../../models/property_status.dart';
import '../../models/property_type.dart';
import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_service.dart';
import '../../services/property_repository.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';

/// Formulario para publicar una propiedad. Disponible solo para
/// agencias y propietarios. Persiste la publicacion en Cloud Firestore.
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
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  PropertyType _type = PropertyType.apartamento;
  ListingType _listingType = ListingType.venta;
  String? _locality;
  bool _parking = false;
  final List<XFile> _images = [];
  LatLng? _location;
  bool _geocoding = false;
  bool _submitting = false;
  bool _generatingDesc = false;
  bool _showIaHint = false;

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked));
  }

  /// Indica si los campos que alimentan a la IA ya estan diligenciados.
  /// Habitaciones y banos solo se exigen cuando el tipo los contempla.
  bool _fieldsReadyForAi() {
    final bedroomsOk =
        !_type.hasBedrooms || _bedroomsController.text.trim().isNotEmpty;
    final bathroomsOk =
        !_type.hasBathrooms || _bathroomsController.text.trim().isNotEmpty;
    return _titleController.text.trim().isNotEmpty &&
        parseGroupedNumber(_priceController.text) != null &&
        _locality != null &&
        bedroomsOk &&
        bathroomsOk &&
        _areaController.text.trim().isNotEmpty;
  }

  /// Genera una descripcion con IA a partir de los datos del formulario.
  /// El resultado queda en el campo para que el usuario lo edite.
  Future<void> _generateDescription() async {
    if (!_fieldsReadyForAi()) {
      setState(() => _showIaHint = true);
      return;
    }
    setState(() => _showIaHint = false);
    final ai = context.read<AiService>();
    FocusScope.of(context).unfocus();
    setState(() => _generatingDesc = true);
    try {
      final text = await ai.generateDescription(
        title: _titleController.text.trim(),
        type: _type,
        listingType: _listingType,
        price: parseGroupedNumber(_priceController.text) ?? 0,
        locality: _locality ?? 'Bogota',
        bedrooms: int.tryParse(_bedroomsController.text.trim()),
        bathrooms: int.tryParse(_bathroomsController.text.trim()),
        areaM2: double.tryParse(_areaController.text.trim()),
        parking: _parking,
      );
      if (!mounted) return;
      setState(() => _descController.text = text);
    } on AiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('No se pudo generar la descripcion. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _generatingDesc = false);
    }
  }

  /// Convierte la direccion escrita en coordenadas y mueve el marcador.
  Future<void> _geocodeAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una direccion primero.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _geocoding = true);
    try {
      final results =
          await geo.Geocoding().locationFromAddress('$query, Bogota, Colombia');
      if (!mounted) return;
      if (results.isEmpty) {
        _showError('No se encontro la direccion. Ajustala o toca el mapa.');
        return;
      }
      final point = LatLng(results.first.latitude, results.first.longitude);
      if (!MapConfig.isInsideBogota(point)) {
        _showError('La direccion esta fuera de Bogota.');
        return;
      }
      setState(() => _location = point);
    } catch (_) {
      if (!mounted) return;
      _showError('No se pudo ubicar la direccion. Toca el mapa manualmente.');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.statusAlert,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (_locality == null) {
      _showError('Selecciona la localidad.');
      return;
    }

    // En Android la ubicacion es obligatoria; en web (solo pruebas) se omite.
    if (!kIsWeb && _location == null) {
      _showError('Marca la ubicacion en el mapa.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final bedrooms = _type.hasBedrooms
        ? int.tryParse(_bedroomsController.text.trim()) ?? 0
        : 0;
    final bathrooms = _type.hasBathrooms
        ? int.tryParse(_bathroomsController.text.trim()) ?? 0
        : 0;
    final areaM2 = double.tryParse(_areaController.text.trim()) ?? 0;

    List<String> imageUrls = const [];
    try {
      if (_images.isNotEmpty) {
        imageUrls = await context.read<StorageService>().uploadPropertyImages(
              ownerId: user.id,
              images: _images,
            );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('No se pudieron subir las imagenes.');
      return;
    }

    final property = Property(
      id: '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      price: parseGroupedNumber(_priceController.text) ?? 0,
      city: 'Bogota',
      neighborhood: _locality!,
      address: _addressController.text.trim(),
      type: _type,
      listingType: _listingType,
      status: PropertyStatus.enRevision,
      imageUrls: imageUrls,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      areaM2: areaM2,
      parking: _type.hasParking ? _parking : false,
      latitude: _location?.latitude,
      longitude: _location?.longitude,
      publisherId: user.id,
      publisherName: user.name,
      lastUpdated: DateTime.now(),
    );

    try {
      await context.read<PropertyRepository>().addProperty(property);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Propiedad publicada.'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('No se pudo publicar. Intenta de nuevo.');
    }
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
            _ImagePicker(
              images: _images,
              onAdd: _pickImages,
              onRemove: (index) => setState(() => _images.removeAt(index)),
            ),
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
            if (context.watch<AiProvider>().enabled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _generatingDesc ? null : _generateDescription,
                      icon: _generatingDesc
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _generatingDesc ? 'Generando...' : 'Generar con IA',
                      ),
                    ),
                  ),
                  if (_showIaHint)
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Completa primero todos los campos para que la IA '
                            'genere una mejor descripcion.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixText: '\$ ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un precio';
                }
                if (parseGroupedNumber(value) == null) {
                  return 'Solo numeros';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _geocodeAddress(),
              decoration: InputDecoration(
                labelText: 'Direccion',
                hintText: 'Ej: Calle 85 #11-20',
                suffixIcon: _geocoding
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Ubicar en el mapa',
                        onPressed: _geocodeAddress,
                      ),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _locality,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Localidad'),
              items: BogotaLocalities.all
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (value) => setState(() => _locality = value),
              validator: (value) =>
                  value == null ? 'Selecciona la localidad' : null,
            ),
            const SizedBox(height: 20),
            Text('Ubicacion en el mapa', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Busca la direccion o toca el mapa para ajustar el punto.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            _LocationPicker(
              location: _location,
              onPicked: (value) => setState(() => _location = value),
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
            _FeatureFields(
              type: _type,
              bedrooms: _bedroomsController,
              bathrooms: _bathroomsController,
              area: _areaController,
            ),
            if (_type.hasParking)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _parking,
                onChanged: (value) => setState(() => _parking = value),
                secondary: const Icon(Icons.local_parking_outlined),
                title: const Text('Cuenta con parqueadero'),
              ),
            const SizedBox(height: 8),
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
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Publicando...' : 'Publicar'),
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

/// Campos de caracteristicas que varian segun el tipo de inmueble:
/// vivienda muestra habitaciones; lote no muestra banos; area siempre.
class _FeatureFields extends StatelessWidget {
  final PropertyType type;
  final TextEditingController bedrooms;
  final TextEditingController bathrooms;
  final TextEditingController area;

  const _FeatureFields({
    required this.type,
    required this.bedrooms,
    required this.bathrooms,
    required this.area,
  });

  String? _intField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatorio';
    if (int.tryParse(value.trim()) == null) return 'Solo numeros enteros';
    return null;
  }

  String? _areaField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatorio';
    if (double.tryParse(value.trim()) == null) return 'Solo numeros';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type.hasBedrooms) ...[
              Expanded(
                child: TextFormField(
                  controller: bedrooms,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Habitaciones',
                    prefixIcon: Icon(Icons.bed_outlined),
                  ),
                  validator: _intField,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (type.hasBathrooms)
              Expanded(
                child: TextFormField(
                  controller: bathrooms,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Banos',
                    prefixIcon: Icon(Icons.bathtub_outlined),
                  ),
                  validator: _intField,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: area,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Area (m2)',
            prefixIcon: Icon(Icons.square_foot),
          ),
          validator: _areaField,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Selector de ubicacion sobre un mapa limitado a Bogota.
/// En web (solo usado para pruebas rapidas) se muestra un aviso.
class _LocationPicker extends StatefulWidget {
  final LatLng? location;
  final ValueChanged<LatLng> onPicked;

  const _LocationPicker({required this.location, required this.onPicked});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant _LocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.location;
    if (target != null && target != oldWidget.location) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGray),
        ),
        child: const Text(
          'El mapa solo esta disponible en Android.\n'
          'Publica desde la app para fijar la ubicacion.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mediumGray),
        ),
      );
    }

    final location = widget.location;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: MapConfig.bogotaCenter,
            zoom: MapConfig.defaultZoom,
          ),
          cameraTargetBounds: MapConfig.cameraBounds,
          minMaxZoomPreference: MapConfig.zoomPreference,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) => _controller = controller,
          onTap: (point) {
            if (!MapConfig.isInsideBogota(point)) return;
            widget.onPicked(point);
          },
          markers: location == null
              ? const {}
              : {
                  Marker(
                    markerId: const MarkerId('seleccion'),
                    position: location,
                  ),
                },
        ),
      ),
    );
  }
}

/// Selector de imagenes con previsualizacion en miniatura.
class _ImagePicker extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImagePicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return GestureDetector(
        onTap: onAdd,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGray),
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

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == images.length) {
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.mediumGray),
              ),
            );
          }
          return _Thumbnail(
            file: images[index],
            onRemove: () => onRemove(index),
          );
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _Thumbnail({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 110,
                  height: 110,
                  child: ColoredBox(color: AppColors.lightGray),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              );
            },
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child:
                    const Icon(Icons.close, size: 16, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
