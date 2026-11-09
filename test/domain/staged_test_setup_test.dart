import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/domain/measurement_method.dart';
import 'package:running_tools/domain/stage_protocol.dart';
import 'package:running_tools/domain/staged_test_setup.dart';

void main() {
  final vameval = StagedTestSetup.defaults(StagedTest.vameval);

  test(
    'VAMEVAL par défaut : 25 paliers jusqu\'à 20 km/h, bip toutes les 9 s',
    () {
      expect(vameval.isValid, isTrue);
      expect(vameval.stageCount, 25);
      expect(vameval.maxDuration, const Duration(minutes: 25));
      expect(vameval.firstBeepInterval, const Duration(seconds: 9));
    },
  );

  test('Luc Léger par défaut : 24 paliers de 8,5 à 20 km/h', () {
    expect(StagedTestSetup.defaults(StagedTest.lucLeger).stageCount, 24);
  });

  test('vitesse max non atteinte pile : on s\'arrête au palier inférieur', () {
    final s = StagedTestSetup(
      test: StagedTest.vameval,
      protocol: vameval.protocol,
      maxSpeedKmh: 10.2,
      method: MeasurementMethod.tape,
    );
    expect(s.stageCount, 5); // 8 ; 8,5 ; 9 ; 9,5 ; 10
  });

  test('validation : incrément nul et vitesse max trop basse', () {
    final s = StagedTestSetup(
      test: StagedTest.vameval,
      protocol: vameval.protocol.copyWith(incrementKmh: 0),
      maxSpeedKmh: 8,
      method: MeasurementMethod.tape,
    );
    expect(s.validationErrors, hasLength(2));
  });

  test('aller-retour JSON', () {
    final s = StagedTestSetup(
      test: StagedTest.lucLeger,
      protocol: StagedTest.lucLeger.defaultProtocol.copyWith(
        markerSpacingM: 23.77,
        stageDuration: const Duration(seconds: 90),
      ),
      maxSpeedKmh: 18.5,
      method: MeasurementMethod.ar,
    );
    final back = StagedTestSetup.fromJson(s.toJson())!;
    expect(back.test, StagedTest.lucLeger);
    expect(back.protocol.markerSpacingM, 23.77);
    expect(back.protocol.stageDuration, const Duration(seconds: 90));
    expect(back.maxSpeedKmh, 18.5);
    expect(back.method, MeasurementMethod.ar);
  });

  test('JSON inattendu : null plutôt qu\'un plantage', () {
    expect(StagedTestSetup.fromJson({'test': 'inconnu'}), isNull);
  });
}
