import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_report_repository.dart';
import 'model.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final dailyReportRepositoryProvider = Provider<DailyReportRepository>(
  (ref) => throw UnimplementedError('dailyReportRepositoryProvider muss in main() überschrieben werden.'),
);

/// Alle Berichte, neueste zuerst.
final dailyReportsProvider = StreamProvider<List<DailyReport>>(
  (ref) => ref.watch(dailyReportRepositoryProvider).watchAll(),
);
