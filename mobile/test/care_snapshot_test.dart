import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/features/care/care_snapshot.dart';
import 'package:petcare/core/images/photo_cache.dart';

void main() {
  test(
      'local midnight, overdue, future, cancellations and same-name pets stay separate',
      () {
    final now = DateTime(2026, 9, 17, 23, 59);
    Map<String, dynamic> task(String id, DateTime due,
            {String pet = 'a',
            bool done = false,
            bool cancelled = false,
            bool skipped = false}) =>
        {
          'id': id,
          'petId': pet,
          'petName': 'Mochi',
          'dueAt': due.toUtc().toIso8601String(),
          'completed': done,
          'cancelled': cancelled,
          'skipped': skipped
        };
    final tasks = [
      task('overdue', DateTime(2026, 9, 16)),
      task('today', DateTime(2026, 9, 17, 23, 59)),
      task('future', DateTime(2026, 9, 18)),
      task('old-done', DateTime(2026, 9, 16), done: true),
      task('done', now, done: true),
      task('other', now, pet: 'b'),
      task('cancel', now, cancelled: true),
      task('skip', now, skipped: true)
    ];
    final history = [
      {'id': 'one', 'petId': 'a', 'at': now.toUtc().toIso8601String()},
      {
        'id': 'old',
        'petId': 'a',
        'at': DateTime(2026, 9, 16).toUtc().toIso8601String()
      },
      {'id': 'other', 'petId': 'b', 'at': now.toUtc().toIso8601String()}
    ];
    final view =
        CareSnapshot(petId: 'a', now: now, tasks: tasks, history: history);
    expect(view.due.map((v) => v['id']), ['overdue', 'today']);
    expect(view.pending.length, 3);
    expect(view.todayCompleted, 1);
    expect(view.todayEvents.map((v) => v['id']), ['one']);
    final next = CareSnapshot(
        petId: 'a', now: DateTime(2026, 9, 18), tasks: tasks, history: history);
    expect(next.due.length, 3);
    expect(next.todayEvents, isEmpty);
    expect(next.todayCompleted, 0);
  });
  test('photo bytes reuse identity and cache respects memory budget', () {
    final cache = PhotoCache(maxBytes: 12);
    final first = cache.decode('AA==');
    expect(identical(first, cache.decode('AA==')), true);
    cache.decode('AQ==');
    expect(cache.retainedBytes, lessThanOrEqualTo(12));
    expect(identical(first, cache.decode('AA==')), false);
    expect(() => cache.decode('not base64'), throwsFormatException);
    cache.clear();
    expect(cache.retainedBytes, 0);
  });
}
