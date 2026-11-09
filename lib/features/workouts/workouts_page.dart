import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/workout_program.dart';
import '../../domain/workout.dart';
import '../../domain/workout_library.dart';
import '../home/home_entry.dart';
import 'workout_detail_page.dart';
import 'workout_editor_page.dart';
import 'workouts_controller.dart';

/// Bibliothèque de séances et séances personnelles.
class WorkoutsPage extends ConsumerWidget {
  const WorkoutsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = ref.watch(workoutsControllerProvider).value ?? const [];
    final entry = HomeEntry.workouts;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const WorkoutEditorPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: entry.gradient),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BackButton(color: Colors.white),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        'Séances',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mine.isNotEmpty) ...[
                  section('Mes séances'),
                  for (final w in mine) WorkoutTile(workout: w),
                ],
                section('Bibliothèque'),
                for (final w in workoutLibrary) WorkoutTile(workout: w),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          workout.isDistanceBased ? Icons.straighten : Icons.timer,
          color: scheme.primary,
        ),
        title: Text(
          workout.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(workout.sets.map(describeSet).join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkoutDetailPage(workout: workout),
          ),
        ),
      ),
    );
  }
}
