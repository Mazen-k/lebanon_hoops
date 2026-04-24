/// Dedupes API + in-memory card nationalities and sorts Lebanon-style codes first.
List<String> mergeNationalityFilterOptions(
  List<String> fromApi,
  Iterable<String> fromCards,
) {
  final set = <String>{};
  for (final s in fromApi) {
    final t = s.trim();
    if (t.isNotEmpty) {
      set.add(t);
    }
  }
  for (final s in fromCards) {
    final t = s.trim();
    if (t.isNotEmpty) {
      set.add(t);
    }
  }
  final list = set.toList();
  bool leb(String x) {
    final u = x.toUpperCase();
    return const {'LB', 'LEB', 'LEBANON', 'LBN'}.contains(u);
  }

  list.sort((a, b) {
    final la = leb(a);
    final lb = leb(b);
    if (la != lb) {
      return la ? -1 : 1;
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  });
  return list;
}
