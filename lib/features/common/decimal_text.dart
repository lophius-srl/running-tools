/// Lit un nombre saisi en français (« 23,77 ») ou en anglais (« 23.77 »).
double? parseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Affiche un nombre avec une virgule, sans zéros inutiles (« 8 », « 23,77 »).
String formatDecimal(double value) {
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return text.replaceAll('.', ',');
}
