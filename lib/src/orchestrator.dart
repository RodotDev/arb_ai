import 'dart:io';
import 'ai/gemini_provider.dart';
import 'ai/translation_batcher.dart';
import 'ai/translation_provider.dart';
import 'arb/arb_parser.dart';
import 'arb/arb_state_manager.dart';
import 'arb/arb_writer.dart';
import 'arb/icu_validator.dart';
import 'cli/logger.dart';
import 'config/arb_ai_config.dart';

/// Orchestrator coordinating configuration, smart diffing, batching,
/// AI translations, ICU validation, and deterministic writing.
class ArbAiOrchestrator {
  final ArbAiConfig config;
  final TranslationProvider provider;
  final Logger logger;

  ArbAiOrchestrator({
    required this.config,
    TranslationProvider? provider,
    this.logger = const Logger(),
  }) : provider = provider ?? GeminiProvider();

  /// Resolves the target file path based on source file path, target language, and source locale.
  File getTargetFile(String sourcePath, String targetLocale, String? sourceLocale) {
    final file = File(sourcePath);
    final directory = file.parent.path;
    final name = file.uri.pathSegments.last;

    if (sourceLocale != null && name.contains('_$sourceLocale.arb')) {
      final newName = name.replaceAll('_$sourceLocale.arb', '_$targetLocale.arb');
      return File('$directory/$newName');
    }

    final dotIndex = name.lastIndexOf('.');
    final ext = dotIndex != -1 ? name.substring(dotIndex) : '.arb';
    final base = dotIndex != -1 ? name.substring(0, dotIndex) : name;

    final underIndex = base.lastIndexOf('_');
    if (underIndex != -1) {
      final suffix = base.substring(underIndex + 1);
      if (suffix.length >= 2 && suffix.length <= 6) {
        final newBase = base.substring(0, underIndex);
        return File('$directory/${newBase}_$targetLocale$ext');
      }
    }

    return File('$directory/${base}_$targetLocale$ext');
  }

  /// Runs the orchestration pipeline.
  ///
  /// - [dryRun]: If true, simulates the process and logs estimated actions without writing files or calling APIs.
  /// - [check]: If true, acts as a CI safety check. Verifies if any translations are out-of-sync or missing,
  ///   prints them, and returns false without making changes.
  ///
  /// Returns `true` if successful or fully in sync, and `false` if check failed (out-of-sync).
  Future<bool> run({bool dryRun = false, bool check = false}) async {
    final sourceFile = File(config.sourceArb);
    if (!sourceFile.existsSync()) {
      logger.error('Source ARB file does not exist at "${config.sourceArb}".');
      return false;
    }

    ArbFile sourceArb;
    try {
      sourceArb = ArbFile.parseFile(sourceFile);
    } catch (e) {
      logger.error('Failed to parse source ARB file: $e');
      return false;
    }

    final stateManager = ArbStateManager.forSourceArb(config.sourceArb);

    if (config.targets.isEmpty) {
      logger.warning('No target languages specified in configuration.');
      return true;
    }

    logger.info('Starting arb_ai translation pipeline...');
    logger.info('Source locale: ${sourceArb.locale ?? "not specified (fallback to English)"}');
    logger.info('Target languages: ${config.targets.join(", ")}');



    var allInSync = true;
    final Map<String, List<String>> outdatedKeysPerTarget = {};
    final Map<String, List<String>> missingKeysPerTarget = {};

    // 1. Analyze and diff for each target language
    final Map<String, Map<String, String>> keysToTranslatePerTarget = {};
    final Map<String, File> targetFiles = {};
    final Map<String, ArbFile?> targetArbs = {};

    for (final targetLang in config.targets) {
      final targetFile = getTargetFile(config.sourceArb, targetLang, sourceArb.locale);
      targetFiles[targetLang] = targetFile;

      ArbFile? targetArb;
      if (targetFile.existsSync()) {
        try {
          targetArb = ArbFile.parseFile(targetFile);
        } catch (e) {
          logger.warning('Target file for "$targetLang" exists but failed to parse: $e. It will be overwritten.');
        }
      }
      targetArbs[targetLang] = targetArb;

      final outdated = <String>[];
      final missing = <String>[];
      final toTranslate = <String, String>{};

      for (final key in sourceArb.translations.keys) {
        final sourceValue = sourceArb.translations[key]!;
        final upToDate = stateManager.isUpToDate(
          targetLanguage: targetLang,
          key: key,
          sourceValue: sourceValue,
          targetArb: targetArb,
        );

        if (!upToDate) {
          toTranslate[key] = sourceValue;
          if (targetArb != null && targetArb.translations.containsKey(key)) {
            outdated.add(key);
          } else {
            missing.add(key);
          }
        }
      }

      if (toTranslate.isNotEmpty) {
        allInSync = false;
        keysToTranslatePerTarget[targetLang] = toTranslate;
        if (outdated.isNotEmpty) {
          outdatedKeysPerTarget[targetLang] = outdated;
        }
        if (missing.isNotEmpty) {
          missingKeysPerTarget[targetLang] = missing;
        }
      }
    }

    // 2. Handle CI/CD Check Mode
    if (check) {
      if (allInSync) {
        logger.success('CI Check: All translations are fully up-to-date!');
        return true;
      }

      logger.error('CI Check Failed: Outdated or missing translations detected!');
      for (final targetLang in config.targets) {
        final missing = missingKeysPerTarget[targetLang] ?? [];
        final outdated = outdatedKeysPerTarget[targetLang] ?? [];
        if (missing.isNotEmpty || outdated.isNotEmpty) {
          logger.info('Language "$targetLang":');
          if (missing.isNotEmpty) {
            logger.info('  Missing keys: ${missing.join(", ")}');
          }
          if (outdated.isNotEmpty) {
            logger.info('  Outdated keys: ${outdated.join(", ")}');
          }
        }
      }
      return false;
    }

    if (allInSync) {
      logger.success('All translations are fully up-to-date. Nothing to translate!');
      return true;
    }

    // 3. Handle Dry Run Mode
    if (dryRun) {
      logger.info('=== Dry Run Simulation ===');
      for (final targetLang in keysToTranslatePerTarget.keys) {
        final toTranslate = keysToTranslatePerTarget[targetLang]!;
        logger.info('Language "$targetLang" would translate ${toTranslate.length} keys:');
        for (final entry in toTranslate.entries) {
          logger.info('  - ${entry.key}: "${entry.value}"');
        }
      }
      logger.success('Dry run simulation completed successfully.');
      return true;
    }

    // 4. Perform actual translations, validation, and writing
    for (final targetLang in keysToTranslatePerTarget.keys) {
      final toTranslate = keysToTranslatePerTarget[targetLang]!;
      final targetFile = targetFiles[targetLang]!;
      final targetArb = targetArbs[targetLang];

      logger.info('Translating ${toTranslate.length} keys to "$targetLang"...');

      final batches = TranslationBatcher.chunk(toTranslate, maxKeys: 25);
      final newTranslations = <String, String>{};

      for (int i = 0; i < batches.length; i++) {
        final batch = batches[i];
        logger.debug('Processing batch ${i + 1}/${batches.length} (${batch.length} keys) for "$targetLang"...');

        try {
          final translatedBatch = await _translateAndValidateBatch(
            batch: batch,
            targetLanguage: targetLang,
            sourceArb: sourceArb,
            stateManager: stateManager,
          );
          newTranslations.addAll(translatedBatch);
        } catch (e) {
          logger.error('Failed to translate batch ${i + 1}/${batches.length} for "$targetLang": $e');
          return false;
        }
      }

      // Merge newly translated keys with existing ones
      final mergedTranslations = <String, String>{};
      if (targetArb != null) {
        mergedTranslations.addAll(targetArb.translations);
      }
      mergedTranslations.addAll(newTranslations);

      // Write target ARB file deterministically
      try {
        ArbWriter.write(
          file: targetFile,
          locale: targetLang,
          translations: mergedTranslations,
          sourceKeyOrder: sourceArb.keyOrder,
        );
        logger.success('Successfully wrote translations to "${targetFile.path}".');
      } catch (e) {
        logger.error('Failed to write target file "${targetFile.path}": $e');
        return false;
      }
    }

    // Save final state changes
    try {
      stateManager.save();
      logger.success('State updated successfully.');
    } catch (e) {
      logger.warning('Failed to save state file: $e');
    }

    logger.success('All translations completed successfully!');
    return true;
  }

  /// Translates and validates a single batch of keys with exponential retries.
  Future<Map<String, String>> _translateAndValidateBatch({
    required Map<String, String> batch,
    required String targetLanguage,
    required ArbFile sourceArb,
    required ArbStateManager stateManager,
  }) async {
    var currentBatch = Map<String, String>.from(batch);
    final Map<String, String> successfulTranslations = {};

    int attempt = 0;
    const maxRetries = 3;

    while (currentBatch.isNotEmpty && attempt < maxRetries) {
      if (attempt > 0) {
        logger.warning('ICU validation failed or API failed for some keys. Retrying translation attempt ${attempt + 1}/$maxRetries...');
      }

      Map<String, String> translated;
      try {
        translated = await provider.translate(
          strings: currentBatch,
          targetLanguage: targetLanguage,
          config: config,
        );
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        logger.warning('Translation call failed: $e. Retrying in ${1 << attempt} seconds...');
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
        continue;
      }

      final failedKeys = <String, String>{};
      for (final key in currentBatch.keys) {
        final sourceVal = sourceArb.translations[key]!;
        final targetVal = translated[key];

        if (targetVal == null) {
          failedKeys[key] = sourceVal;
          logger.warning('Key "$key" was not returned in translation.');
          continue;
        }

        final valResult = IcuValidator.validate(
          key: key,
          source: sourceVal,
          target: targetVal,
          targetLanguage: targetLanguage,
        );

        if (valResult.isValid) {
          successfulTranslations[key] = targetVal;
          stateManager.updateState(
            targetLanguage: targetLanguage,
            key: key,
            sourceValue: sourceVal,
          );
        } else {
          failedKeys[key] = sourceVal;
          logger.warning('ICU validation failed for key "$key": ${valResult.error}');
        }
      }

      currentBatch = failedKeys;
      attempt++;
    }

    if (currentBatch.isNotEmpty) {
      throw FormatException(
        'ICU validation failed after $maxRetries attempts for keys: ${currentBatch.keys.join(", ")}',
      );
    }

    return successfulTranslations;
  }
}
