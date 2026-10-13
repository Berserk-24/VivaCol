import 'package:flutter/material.dart';

import '../utils/format.dart';

/// Rango de precio seleccionado. Valores nulos significan sin limite.
class PriceRange {
  final double? min;
  final double? max;

  const PriceRange(this.min, this.max);

  bool get isEmpty => min == null && max == null;
}

/// Muestra un dialogo para elegir precio minimo y maximo.
/// Devuelve null si se cancela; un [PriceRange] vacio si se limpia.
Future<PriceRange?> showPriceRangeDialog(
  BuildContext context, {
  double? min,
  double? max,
}) {
  final minController =
      TextEditingController(text: min != null ? formatThousands(min) : '');
  final maxController =
      TextEditingController(text: max != null ? formatThousands(max) : '');

  return showDialog<PriceRange>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Rango de precio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Precio minimo',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Precio maximo',
                prefixText: '\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, const PriceRange(null, null)),
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final minVal = parseGroupedNumber(minController.text);
              final maxVal = parseGroupedNumber(maxController.text);
              Navigator.pop(dialogContext, PriceRange(minVal, maxVal));
            },
            child: const Text('Aplicar'),
          ),
        ],
      );
    },
  );
}
