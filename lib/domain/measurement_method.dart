/// Comment l'espacement des repères a été mesuré (enregistré avec le test).
enum MeasurementMethod {
  tape('Décamètre'),
  field('Terrain normé'),
  shoe('Chaussures (talon-pointe)'),
  ar('Réalité augmentée'),
  manual('Estimation');

  const MeasurementMethod(this.label);

  final String label;
}
