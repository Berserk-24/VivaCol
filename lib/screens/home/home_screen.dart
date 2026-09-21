import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../models/app_user.dart';
import '../../models/property.dart';
import '../../models/property_type.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Property> get _filtered {
    return MockData.properties.where((p) {
      final matchesQuery = _query.isEmpty ||
          p.title.toLowerCase().contains(_query.toLowerCase()) ||
          p.location.toLowerCase().contains(_query.toLowerCase());
      final matchesCity = _selectedCity == 'Todas' || p.city == _selectedCity;
      final matchesType = _selectedType == null || p.type == _selectedType;
      final matchesListing =
          _selectedListing == null || p.listingType == _selectedListing;
      return matchesQuery && matchesCity && matchesType && matchesListing;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = MockData.currentUser.role.canPublish;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.home_work_rounded, color: AppColors.primaryBlue),
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
            onQueryChanged: (value) => setState(() => _query = value),
            onCityChanged: (value) =>
                setState(() => _selectedCity = value ?? 'Todas'),
            onTypeChanged: (value) => setState(() => _selectedType = value),
            onListingChanged: (value) =>
                setState(() => _selectedListing = value),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final property = _filtered[index];
                      return PropertyCard(
                        property: property,
                        onTap: () => context.push('/property/${property.id}'),
                      );
                    },
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
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<PropertyType?> onTypeChanged;
  final ValueChanged<ListingType?> onListingChanged;

  const _SearchAndFilters({
    required this.controller,
    required this.selectedCity,
    required this.selectedType,
    required this.selectedListing,
    required this.onQueryChanged,
    required this.onCityChanged,
    required this.onTypeChanged,
    required this.onListingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar por titulo o ubicacion',
              prefixIcon: Icon(Icons.search),
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
          items: MockData.cities
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
  const _EmptyState();

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
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
