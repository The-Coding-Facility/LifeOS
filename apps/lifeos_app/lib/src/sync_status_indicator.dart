import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_sync/lifeos_sync.dart';

import 'app_providers.dart';
import 'router.dart';

/// Sync-Symbol für das Dashboard: „Syncing“, „Synced“, „Offline-Modus“ oder
/// „Nur lokal“. Antippen öffnet die Geräteverwaltung.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).value ??
        const SyncState(phase: SyncPhase.localOnly);
    final status = switch (state.phase) {
      SyncPhase.localOnly => SyncStatus.localOnly,
      SyncPhase.syncing => SyncStatus.syncing,
      SyncPhase.synced when state.pending == 0 => SyncStatus.synced,
      SyncPhase.synced || SyncPhase.offline => SyncStatus.offline,
    };
    return Tooltip(
      message: state.message ?? 'Geräte & Synchronisation',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go(Routes.devices),
        child: SyncStatusChip(status: status, pendingChanges: state.pending),
      ),
    );
  }
}
