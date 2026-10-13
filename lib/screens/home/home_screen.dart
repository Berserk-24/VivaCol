import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/bogota_localities.dart';
import '../../models/app_user.dart';
import '../../models/property.dart';
import '../../models/property_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/property_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/property_card.dart';

/// Pantalla principal con buscador, filtros basicos y listado de propiedades.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedCity = 'Todas';
  PropertyType? _selectedType;
  ListingType? _selectedListing;
  String _sort = 'recientes';

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _selectedCity != 'Todas' ||
      _selectedType != null ||
      _selectedListing != null;

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _selectedCity = 'Todas';
      _selectedType = null;
      _selectedListing = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Property> _applyFilters(List<Property> all) {
    final result = all.where((p) {
      final matchesQuery = _query.isEmpty ||
          p.title.toLowerCase().contains(_query.toLowerCase()) ||
          p.location.toLowerCase().contains(_query.toLowerCase());
      final matchesCity =
          _selectedCity == 'Todas' || p.neighborhood == _selectedCity;
      final matchesType = _selectedType == null || p.type == _selectedType;
      final matchesListing =
          _selectedListing == null || p.listingType == _selectedListing;
      return matchesQuery && matchesCity && matchesType && matchesListing;
    }).toList();
    switch (_sort) {
      case 'precio_asc':
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'precio_desc':
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      default:
        result.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final canPublish =
        context.watch<AuthProvider>().user?.role.canPublish ?? false;
    final repo = context.read<PropertyRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/icon/logo.png', height: 28),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Viva',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: 'Col',
                    style: TextStyle(
                      color: AppColors.accentGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Cambiar tema',
            onPressed: () => context.read<ThemeProvider>().toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Ver mapa',
            onPressed: () => context.push('/map'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/publish'),
              backgroundColor: AppColors.accentGreen,
              icon: const Icon(Icons.add, color: AppColors.white),
              label: const Text(
                'Publicar',
                style: TextStyle(color: AppColors.white),
              ),
            )
          : null,
      body: Column(
        children: [
          _SearchAndFilters(
            controller: _searchController,
            selectedCity: _selectedCity,
            selectedType: _selectedType,
            selectedListing: _selectedListing,
            selectedSort: _sort,
            onQueryChanged: (value) => setState(() => _query = value),
            onCityChanged: (value) =>
                setState(() => _selectedCity = value ?? 'Todas'),
            onTypeChanged: (value) => setState(() => _selectedType = value),
            onListingChanged: (value) =>
                setState(() => _selectedListing = value),
            onSortChanged: (value) => setState(() => _sort = value),
          ),
          Expanded(
            child: Container(
              color: isDark ? AppColors.white : null,
              child: StreamBuilder<List<Property>>(
                stream: repo.watchProperties(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const _ErrorState();
                  }
                  final filtered = _applyFilters(snapshot.data ?? const []);
                  if (filtered.isEmpty) {
                    return _EmptyState(
                      onClear: _hasActiveFilters ? _clearFilters : null,
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} '
                              '${filtered.length == 1 ? 'resultado' : 'resultados'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.mediumGray),
                            ),
                            const Spacer(),
                            if (_hasActiveFilters)
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon:
                                    const Icon(Icons.filter_alt_off, size: 16),
                                label: const Text('Limpiar filtros'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final property = filtered[index];
                            return PropertyCard(
                              property: property,
                              onTap: () =>
                                  context.push('/property/${property.id}'),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCity;
  final PropertyType? selectedType;
  final ListingType? selectedListing;
  final String selectedSort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<PropertyType?> onTypeChanged;
  final ValueChanged<ListingType?> onListingChanged;
  final ValueChanged<String> onSortChanged;

  const _SearchAndFilters({
    required this.controller,
    required this.selectedCity,
    required this.selectedType,
    required this.selectedListing,
    required this.selectedSort,
    required this.onQueryChanged,
    required this.onCityChanged,
    required this.onTypeChanged,
    required this.onListingChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.accentGreen : AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Buscar por titulo o ubicacion',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpiar busqueda',
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CityDropdown(
                  selectedCity: selectedCity,
                  onChanged: onCityChanged,
                ),
                const SizedBox(width: 8),
                _TypeFilter(
                  selectedType: selectedType,
                  onChanged: onTypeChanged,
                ),
                const SizedBox(width: 8),
                _ListingFilter(
                  selectedListing: selectedListing,
                  onChanged: onListingChanged,
                ),
                const SizedBox(width: 8),
                _SortFilter(
                  selectedSort: selectedSort,
                  onChanged: onSortChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  final String selectedCity;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({required this.selectedCity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightGray),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCity,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          borderRadius: BorderRadius.circular(12),
          items: BogotaLocalities.withAll
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  final PropertyType? selectedType;
  final ValueChanged<PropertyType?> onChanged;

  const _TypeFilter({required this.selectedType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PropertyType?>(
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Todos los tipos')),
        ...PropertyType.values.map(
          (t) => PopupMenuItem(value: t, child: Text(t.label)),
        ),
      ],
      child: _FilterChipBox(
        label: selectedType?.label ?? 'Tipo',
        active: selectedType != null,
      ),
    );
  }
}

class _ListingFilter extends StatelessWidget {
  final ListingType? selectedListing;
  final ValueChanged<ListingType?> onChanged;

  const _ListingFilter({
    required this.selectedListing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ListingType?>(
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Venta y arriendo')),
        ...ListingType.values.map(
          (t) => PopupMenuItem(value: t, child: Text(t.label)),
        ),
      ],
      child: _FilterChipBox(
        label: selectedListing?.label ?? 'Operacion',
        active: selectedListing != null,
      ),
    );
  }
}

class _SortFilter extends StatelessWidget {
  final String selectedSort;
  final ValueChanged<String> onChanged;

  const _SortFilter({required this.selectedSort, required this.onChanged});

  static String _label(String sort) {
    switch (sort) {
      case 'precio_asc':
        return 'Menor precio';
      case 'precio_desc':
        return 'Mayor precio';
      default:
        return 'Recientes';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'recientes', child: Text('Mas recientes')),
        PopupMenuItem(value: 'precio_asc', child: Text('Menor precio')),
        PopupMenuItem(value: 'precio_desc', child: Text('Mayor precio')),
      ],
      child: _FilterChipBox(
        label: _label(selectedSort),
        active: selectedSort != 'recientes',
      ),
    );
  }
}

class _FilterChipBox extends StatelessWidget {
  final String label;
  final bool active;

  const _FilterChipBox({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryBlue : AppColors.white,
        border: Border.all(
          color: active ? AppColors.primaryBlue : AppColors.lightGray,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? AppColors.white : AppColors.darkGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: active ? AppColors.white : AppColors.darkGray,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onClear;

  const _EmptyState({this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.mediumGray),
          const SizedBox(height: 12),
          Text(
            'No hay propiedades con estos filtros',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.darkGray),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Limpiar filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.mediumGray),
          const SizedBox(height: 12),
          Text(
            'No se pudieron cargar las propiedades',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.darkGray),
          ),
        ],
      ),
    );
  }
}
