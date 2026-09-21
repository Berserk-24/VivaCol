/// Formatea un valor numerico como precio en pesos colombianos.
/// Ejemplo: 320000000 -> "$ 320.000.000".
String formatPrice(double value) {
  final intValue = value.round().toString();
  final buffer = StringBuffer();
  int count = 0;
  for (int i = intValue.length - 1; i >= 0; i--) {
    buffer.write(intValue[i]);
    count++;
    if (count % 3 == 0 && i != 0) {
      buffer.write('.');
    }
  }
  final reversed = buffer.toString().split('').reversed.join();
  return '\$ $reversed';
}
