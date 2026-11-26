import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_repository.dart';
import 'model.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => throw UnimplementedError('financeRepositoryProvider muss in main() überschrieben werden.'),
);

/// Alle Buchungen, neueste zuerst.
final financeEntriesProvider = StreamProvider<List<FinanceEntry>>(
  (ref) => ref.watch(financeRepositoryProvider).watchEntries(),
);

/// Alle Daueraufträge.
final recurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(financeRepositoryProvider).watchRecurring(),
);

/// Alle Sparziele.
final savingGoalsProvider = StreamProvider<List<SavingGoal>>(
  (ref) => ref.watch(financeRepositoryProvider).watchGoals(),
);
