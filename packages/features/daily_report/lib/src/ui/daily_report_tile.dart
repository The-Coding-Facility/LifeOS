import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';

import '../providers.dart';
import '../report_math.dart';

/// Dashboard-Kachel: Ist der heutige Bericht erledigt?
class DailyReportTile extends ConsumerWidget {
  const DailyReportTile({super.key, required this.onOpen, this.clock});

  final VoidCallback onOpen;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = dateOnly((clock ?? DateTime.now)());
    final reports = ref.watch(dailyReportsProvider).value ?? const [];
    final done = reports.any((report) => isoDate(report.date) == isoDate(today));
    final streak = reportStreak(reports.map((report) => report.date), today);

    return SectionCard(
      title: 'Daily Report',
      icon: Icons.edit_note,
      action: TextButton(onPressed: onOpen, child: Text(done ? 'Ansehen' : 'Ausfüllen')),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF2E9E6B) : theme.colorScheme.outline,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(done ? 'Heute erledigt' : 'Heute noch offen', style: theme.textTheme.titleMedium),
                if (streak > 0)
                  Text(streak == 1 ? 'Serie: 1 Tag' : 'Serie: $streak Tage', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
