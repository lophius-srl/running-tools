import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Repères AR : petits, semi-transparents, pour voir le sol à travers.
abstract final class ArMarkers {
  static const startColor = Color(0xFF22C55E);
  static const markerColor = Color(0xFFFF7A1A);
  static const aimColor = Colors.white;

  /// Plot d'entraînement de 9 cm.
  static const coneHeight = 0.09;
  static const coneRadius = 0.045;

  /// Anneau posé au sol : son centre est le point exact.
  static const ringRadius = 0.07;
  static const ringThickness = 0.004;

  /// Plot + anneau au sol, centrés sur [ground].
  static List<ARKitNode> plot(Vector3 ground, Color color) => [
    ARKitNode(
      name: _name('plot'),
      geometry: ARKitCone(
        height: coneHeight,
        topRadius: 0.006,
        bottomRadius: coneRadius,
        materials: [_material(color, opacity: 0.55)],
      ),
      position: Vector3(ground.x, ground.y + coneHeight / 2, ground.z),
    ),
    ring(ground, color, opacity: 0.85),
  ];

  /// Anneau fin à plat sur le sol.
  static ARKitNode ring(
    Vector3 ground,
    Color color, {
    double opacity = 0.85,
    double radius = ringRadius,
  }) => ARKitNode(
    name: _name('ring'),
    geometry: ARKitTorus(
      ringRadius: radius,
      pipeRadius: ringThickness,
      materials: [_material(color, opacity: opacity)],
    ),
    // Légèrement au-dessus du sol pour ne pas scintiller avec lui.
    position: Vector3(ground.x, ground.y + ringThickness, ground.z),
  );

  /// Viseur 3D qui suit le point visé au sol.
  static ARKitNode aim(Vector3 ground) =>
      ring(ground, aimColor, opacity: 0.9, radius: 0.05);

  static ARKitMaterial _material(Color color, {required double opacity}) =>
      ARKitMaterial(
        diffuse: ARKitMaterialProperty.color(color),
        transparency: opacity,
        lightingModelName: ARKitLightingModel.physicallyBased,
        // Les objets transparents ne masquent pas ce qui est derrière.
        writesToDepthBuffer: false,
      );

  static var _counter = 0;
  static String _name(String kind) => 'ar_${kind}_${_counter++}';
}
