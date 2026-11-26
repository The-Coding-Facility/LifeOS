import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tag_item.dart';
import 'tag_repository.dart';

/// Wird in `main()` mit der echten Instanz überschrieben.
final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => throw UnimplementedError('tagRepositoryProvider muss in main() überschrieben werden.'),
);

/// Tags eines Bereichs, live aus der Datenbank, nach Namen sortiert.
final tagsProvider = StreamProvider.family<List<TagItem>, TagScope>(
  (ref, scope) => ref.watch(tagRepositoryProvider).watch(scope),
);
