import 'sales_tools.dart';

enum SearchKind { product, customer, supplier, sale, purchase }

class SearchItem {
  const SearchItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.keywords = const [],
  });

  final String id;
  final SearchKind kind;
  final String title;
  final String subtitle;
  final List<String> keywords;
}

int searchScore(SearchItem item, String query) {
  final term = normalizeProductSearch(query);
  if (term.isEmpty) return 0;
  final title = normalizeProductSearch(item.title);
  if (title == term) return 100;
  if (title.startsWith(term)) return 80;
  if (title.contains(term)) return 60;
  for (final keyword in item.keywords) {
    final value = normalizeProductSearch(keyword);
    if (value == term) return 50;
    if (value.startsWith(term)) return 40;
    if (value.contains(term)) return 20;
  }
  return -1;
}

List<SearchItem> findAcrossWorkspace(
  Iterable<SearchItem> items,
  String query, {
  int limit = 24,
}) {
  if (query.trim().isEmpty || limit < 1) return const [];
  final matched = items.where((item) => searchScore(item, query) >= 0).toList();
  matched.sort((a, b) {
    final score = searchScore(b, query).compareTo(searchScore(a, query));
    return score != 0 ? score : a.title.compareTo(b.title);
  });
  return matched.take(limit).toList(growable: false);
}
