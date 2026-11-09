/// Conseil donné quand la cadence s'écarte de la cible.
enum CadenceAdvice {
  faster('Accélère la cadence.'),
  slower('Ralentis la cadence.');

  const CadenceAdvice(this.phrase);

  final String phrase;
}

/// Conseil si l'écart dépasse [tolerance] pas/min ; `null` sinon.
CadenceAdvice? adviceFor(double? measured, int target, {double tolerance = 3}) {
  if (measured == null) return null;
  if (measured < target - tolerance) return CadenceAdvice.faster;
  if (measured > target + tolerance) return CadenceAdvice.slower;
  return null;
}
