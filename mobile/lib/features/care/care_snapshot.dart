/// Local-day projection shared by the home view and regression tests.
class CareSnapshot {
  CareSnapshot(
      {required this.petId,
      required DateTime now,
      required List<Map<String, dynamic>> tasks,
      required List<Map<String, dynamic>> history}) {
    final local = now.toLocal();
    start = DateTime(local.year, local.month, local.day);
    end = DateTime(local.year, local.month, local.day + 1);
    final own = tasks.where((v) =>
        v['petId'] == petId && v['cancelled'] != true && v['skipped'] != true);
    pending = own.where((v) => v['completed'] != true).toList()
      ..sort((a, b) => DateTime.parse(a['dueAt'] as String)
          .compareTo(DateTime.parse(b['dueAt'] as String)));
    due = pending
        .where((v) => DateTime.parse(v['dueAt'] as String).isBefore(end))
        .toList();
    completed = own.where((v) => v['completed'] == true).toList();
    todayCompleted = completed
        .where((v) => today((v['completedAt'] ?? v['dueAt']) as String))
        .length;
    events = history.where((v) => v['petId'] == petId).toList()
      ..sort((a, b) => DateTime.parse(b['at'] as String)
          .compareTo(DateTime.parse(a['at'] as String)));
    todayEvents = events.where((v) => today(v['at'] as String)).toList();
  }
  final String? petId;
  late final DateTime start, end;
  late final List<Map<String, dynamic>> pending,
      due,
      completed,
      events,
      todayEvents;
  late final int todayCompleted;
  bool today(String value) {
    final at = DateTime.parse(value);
    return !at.isBefore(start) && at.isBefore(end);
  }
}
