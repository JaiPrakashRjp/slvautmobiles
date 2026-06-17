/// Simple monotonic id generator for the mock layer (Firestore supplies real
/// ids in Phase 7). Not random — keeps ids stable and readable across a run.
class IdGen {
  IdGen._();

  static final Map<String, int> _counters = {};

  /// e.g. nextId('v') -> 'v_004'
  static String nextId(String prefix) {
    final n = (_counters[prefix] ?? 0) + 1;
    _counters[prefix] = n;
    return '${prefix}_${n.toString().padLeft(3, '0')}';
  }

  /// Seeds the counter so seeded ids don't collide with generated ones.
  static void seedAtLeast(String prefix, int value) {
    final current = _counters[prefix] ?? 0;
    if (value > current) _counters[prefix] = value;
  }
}
