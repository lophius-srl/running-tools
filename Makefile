# Point d'entrée unique pour toutes les commandes du projet.
# La CI lance `make install lint test build`.

.PHONY: install dev lint format test build

install:
	flutter pub get

dev:
	flutter run

lint:
	dart format --output=none --set-exit-if-changed lib test
	flutter analyze

format:
	dart format lib test

test:
	flutter test

# App iOS uniquement : nécessite macOS (la CI doit tourner sur un runner macOS).
build:
	flutter build ios --no-codesign
