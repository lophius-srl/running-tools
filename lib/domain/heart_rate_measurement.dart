/// Décode la caractéristique BLE « Heart Rate Measurement » (0x2A37).
///
/// Octet 0 : drapeaux ; bit 0 à 1 → FC sur 16 bits (petit-boutiste) aux
/// octets 1-2, sinon sur 8 bits à l'octet 1. Renvoie `null` si la trame est
/// trop courte ou la valeur nulle (capteur pas encore en contact).
int? parseHeartRateMeasurement(List<int> bytes) {
  if (bytes.isEmpty) return null;
  final sixteenBits = bytes[0] & 0x01 == 1;
  if (sixteenBits) {
    if (bytes.length < 3) return null;
    final bpm = bytes[1] | (bytes[2] << 8);
    return bpm == 0 ? null : bpm;
  }
  if (bytes.length < 2) return null;
  return bytes[1] == 0 ? null : bytes[1];
}
