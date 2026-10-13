import 'package:flutter/services.dart';

/// Agrupa una cadena de digitos con puntos de miles (1000000 -> 1.000.000).
String _groupThousands(String digits) {
  final buffer = StringBuffer();
  int count = 0;
  for (int i = digits.length - 1; i >= 0; i--) {
    buffer.write(digits[i]);
    count++;
    if (count % 3 == 0 && i != 0) {
      buffer.write('.');
    }
  }
  return buffer.toString().split('').reversed.join();
}

/// Formatea un valor numerico como precio en pesos colombianos.
/// Ejemplo: 320000000 -> "$ 320.000.000".
String formatPrice(double value) =>
    '\$ ${_groupThousands(value.round().toString())}';

/// Formatea un numero agrupando miles con puntos, sin simbolo de moneda.
String formatThousands(num value) => _groupThousands(value.round().toString());

/// Convierte un texto con separadores de miles a numero. Null si esta vacio.
double? parseGroupedNumber(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

/// Formatea en vivo un campo numerico agrupando miles con puntos.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = _groupThousands(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
