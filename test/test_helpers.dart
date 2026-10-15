import 'package:roomeez/data/mock/mock_seed.dart';
import 'package:roomeez/data/mock/mock_store.dart';

/// A fixed "now" so tests don't depend on the real date.
final testNow = DateTime(2026, 10, 15, 12);

/// A seeded store with no simulated latency.
MockStore seededStore() {
  final store = MockStore(latency: Duration.zero, clock: () => testNow);
  seedSampleData(store);
  return store;
}
