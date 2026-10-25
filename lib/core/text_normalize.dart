const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c', '·': '', '\'': '', '’': '',
};

/// Lower case without accents, so "colon" matches "Colón" and "angel" matches "Àngel".
String normalizeForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True when every word of [query] appears in [text], in any order.
bool matchesSearch(String text, String query) {
  final words = normalizeForSearch(query).split(' ').where((w) => w.isNotEmpty);
  final target = normalizeForSearch(text);
  return words.every(target.contains);
}
