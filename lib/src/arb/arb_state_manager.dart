import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'arb_parser.dart';

/// Manages the state of translated keys using cryptographic hashing (True Smart Diffing).
/// This prevents redundant translations and automatically detects when a source value changes.
class ArbStateManager {
  /// The file where translation state is persisted.
  final File stateFile;

  /// Map of target languages -> (key -> source value MD5 hash).
  Map<String, Map<String, String>> _state = {};

  ArbStateManager(this.stateFile) {
    _load();
  }

  /// Factory constructor to get the state manager sibling to the source ARB.
  factory ArbStateManager.forSourceArb(String sourceArbPath) {
    final parent = File(sourceArbPath).parent;
    final file = File('${parent.path}/.arb_ai_state.json');
    return ArbStateManager(file);
  }

  /// Loads the state from disk.
  void _load() {
    if (stateFile.existsSync()) {
      try {
        final content = stateFile.readAsStringSync();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        final hashes = decoded['last_translated_hashes'] as Map<String, dynamic>? ?? {};
        _state = hashes.map((lang, value) {
          final map = (value as Map<String, dynamic>).map((key, val) => MapEntry(key, val as String));
          return MapEntry(lang, map);
        });
      } catch (_) {
        // Fallback to empty state on parse/read error
        _state = {};
      }
    }
  }

  /// Saves the current state back to disk.
  void save() {
    final data = {
      'last_translated_hashes': _state,
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    stateFile.writeAsStringSync('$jsonString\n');
  }

  /// Computes the MD5 hash of a source string.
  String computeHash(String val) {
    return md5.convert(utf8.encode(val)).toString();
  }

  /// Updates the state for a single key and target language.
  void updateState({
    required String targetLanguage,
    required String key,
    required String sourceValue,
  }) {
    final langState = _state.putIfAbsent(targetLanguage, () => {});
    langState[key] = computeHash(sourceValue);
  }

  /// Checks if a translation is up-to-date by verifying:
  /// 1. The key exists in the target ARB translations.
  /// 2. The key exists in our saved state.
  /// 3. The recorded hash matches the current source string hash.
  bool isUpToDate({
    required String targetLanguage,
    required String key,
    required String sourceValue,
    required ArbFile? targetArb,
  }) {
    if (targetArb == null) {
      return false;
    }

    // 1. Is the key present in the target ARB translations?
    if (!targetArb.translations.containsKey(key)) {
      return false;
    }

    // 2. Is there a stored hash for this key and language?
    final langState = _state[targetLanguage];
    if (langState == null) {
      return false;
    }

    final storedHash = langState[key];
    if (storedHash == null) {
      return false;
    }

    // 3. Does the stored hash match the current source string hash?
    final currentHash = computeHash(sourceValue);
    return storedHash == currentHash;
  }

  /// Clears state for a key if it is deleted or no longer needed.
  void removeKey(String key) {
    for (final langState in _state.values) {
      langState.remove(key);
    }
  }

  /// Clears all state.
  void clear() {
    _state.clear();
  }
}
