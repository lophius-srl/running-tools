import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';
import '../../domain/zones/zones.dart';
import '../common/decimal_text.dart';
import '../zones/zone_badge.dart';
import '../zones/zone_profile.dart';
import 'home_entry.dart';
import 'home_widgets.dart';

/// Moi : profil, zones, résultats, et la boîte à outils.
class MeTab extends ConsumerWidget {
  const MeTab({super.key, required this.onOpen});

  final EntryOpener onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(zoneProfileProvider).value;
    final zones = profile?.zones;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Moi',
              subtitle: 'Mon profil, mes zones, mes résultats et mes outils.',
            ),
          ),
          SliverToBoxAdapter(
            child: DashCard(
              title: 'Mon profil',
              onTap: () => onOpen(HomeEntry.profile),
              child: Row(
                children: [
                  for (final (label, value) in [
                    (
                      'VMA',
                      profile?.vma == null
                          ? '–'
                          : '${formatDecimal(profile!.vma!.value)} km/h',
                    ),
                    (
                      'FC max',
                      profile?.maxHeartRate == null
                          ? '–'
                          : '${profile!.maxHeartRate!.value}',
                    ),
                    (
                      'FC repos',
                      profile?.restHeartRate == null
                          ? '–'
                          : '${profile!.restHeartRate!.value}',
                    ),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: theme.textTheme.labelMedium),
                          Text(
                            value,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DashCard(
              title: 'Mes zones',
              onTap: () => onOpen(HomeEntry.zones),
              child: Wrap(
                spacing: AppSpace.s,
                runSpacing: AppSpace.s,
                children: [
                  for (final id in ZoneId.values)
                    ZoneBadge(zone: id, zones: zones, showHeartRate: false),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DashCard(
              title: 'Mes résultats',
              onTap: () => onOpen(HomeEntry.history),
              child: const Text('Tests de VMA et progression.'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.l + 4,
                AppSpace.s,
                AppSpace.l + 4,
                AppSpace.m,
              ),
              child: Text(
                'Boîte à outils',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.l,
              0,
              AppSpace.l,
              AppSpace.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: EntryGrid(entries: HomeTab.toolbox, onOpen: onOpen),
            ),
          ),
        ],
      ),
    );
  }
}
