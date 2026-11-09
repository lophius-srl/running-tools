import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_tools/measure/ar_markers.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

void main() {
  final ground = Vector3(1, -1.4, 3);

  test('plot : petit cône posé sur le sol + anneau centré sur le point', () {
    final nodes = ArMarkers.plot(ground, ArMarkers.markerColor);
    expect(nodes, hasLength(2));

    final cone = nodes.first;
    final geometry = cone.geometry! as ARKitCone;
    expect(geometry.height.value, lessThanOrEqualTo(0.1));
    expect(geometry.bottomRadius.value, lessThanOrEqualTo(0.05));
    // Base du cône au niveau du sol.
    expect(cone.position.y - geometry.height.value / 2, closeTo(-1.4, 1e-6));
    expect(cone.position.x, 1);
    expect(cone.position.z, 3);

    final ring = nodes.last;
    expect(ring.geometry, isA<ARKitTorus>());
    expect(ring.position.x, 1);
    expect(ring.position.z, 3);
    expect(ring.position.y, closeTo(-1.4, 0.01));
  });

  test('semi-transparents et sans masquer ce qui est derrière', () {
    for (final node in ArMarkers.plot(ground, ArMarkers.startColor)) {
      final material = node.geometry!.materials.value!.single;
      expect(material.transparency, lessThan(1));
      expect(material.writesToDepthBuffer, isFalse);
    }
  });

  test('chaque repère a un nom unique', () {
    final names = [
      for (var i = 0; i < 3; i++)
        ...ArMarkers.plot(ground, ArMarkers.markerColor).map((n) => n.name),
      ArMarkers.aim(ground).name,
    ];
    expect(names.toSet(), hasLength(names.length));
  });
}
