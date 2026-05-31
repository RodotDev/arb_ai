/// Utility for chunking translation payloads to respect rate and token limits.
class TranslationBatcher {
  /// Chunks a map of [strings] into a list of smaller maps, each containing
  /// up to [maxKeys] entries.
  ///
  /// This ensures payloads remain within safety, rate, and token limits.
  static List<Map<String, String>> chunk(
    Map<String, String> strings, {
    int maxKeys = 25,
  }) {
    if (strings.isEmpty) return [];
    if (maxKeys <= 0) {
      throw ArgumentError('maxKeys must be greater than 0.');
    }

    final List<Map<String, String>> batches = [];
    Map<String, String> currentBatch = {};

    for (final entry in strings.entries) {
      currentBatch[entry.key] = entry.value;
      if (currentBatch.length == maxKeys) {
        batches.add(currentBatch);
        currentBatch = {};
      }
    }

    if (currentBatch.isNotEmpty) {
      batches.add(currentBatch);
    }

    return batches;
  }
}
