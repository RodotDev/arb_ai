# `arb_ai`

[![pub package](https://img.shields.io/pub/v/arb_ai.svg)](https://pub.dev/packages/arb_ai)
[![CI](https://github.com/RodotDev/arb_ai/actions/workflows/ci.yml/badge.svg)](https://github.com/RodotDev/arb_ai/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-BSD_3--Clause-blue.svg)](https://github.com/RodotDev/arb_ai/blob/main/LICENSE)

`arb_ai` is a AI-powered command-line tool (CLI) and Dart package designed to automate Flutter localization (l10n) and internationalization (i18n) workflows. It leverages advanced Large Language Models (LLMs) to translate Flutter `.arb` files at build-time, with cost optimization via smart-diffing and strict CI/CD alignment.

## Features

- **Flutter ARB Specification Compliance**: Parses and forwards resource descriptions and detailed placeholder metadata (types, formats, examples, and descriptions) to the AI translation engine for better contextual translation. Respects the ARB specification by automatically skipping non-text resources (like `@key.type: "image"`), preserving them intact in targets.
- **Smart Diffing for Cost Optimization**: Computes cryptographic MD5 hashes of source translation templates and tracks them locally in `.arb_ai_state.json`. It will only request translations for missing or modified keys, avoiding redundant API calls and keeping your AI translation costs minimal.
- **Progressive Batch Saving**: Persists translations and state incrementally after each batch. If a translation run is interrupted, it can resume exactly where it left off without losing progress or incurring duplicate costs.
- **ICU Parser & Validator**: Analyzes both source and target translation strings using a custom-built recursive descent parser. Validates that ICU placeholders, plurals, and select categories match, verifying target-language CLDR rules.
- **Auto-Recovery Retry Loop**: Detects AI translation anomalies (like missing placeholders or incorrect syntax) and automatically retries translations up to 3 times to heal outputs before applying them to your local files.
- **Git-Friendly Target Writer**: Serializes target files deterministically (alphabetical order or matching source order, fixed 2-space indentation, trailing newline) while omitting metadata in targets for clean, readable Git diffs.
- **DX & CI/CD Ready**: Supports `--dry-run` to estimate translation overheads/costs, and a strict `--check` mode which exits with code `1` if translations are out-of-sync or missing (perfect for continuous integration pipelines and GitHub Actions).

## Getting Started

### 1. Install `arb_ai` globally or as a dev dependency

```bash
# Add as a dev dependency (Recommended)
dart pub add --dev arb_ai

# Or activate globally
dart pub global activate arb_ai
```

### 2. Configure `arb_ai.yaml`

Create a file named `arb_ai.yaml` in the root of your project:

```yaml
# Provider engine (Currently supports 'gemini')
provider: gemini

# The environment variable to fetch your API Key
api_key_env: ARB_AI_API_KEY

# The model to use (default: gemini-2.5-flash)
model: gemini-2.5-flash

# Source ARB template (optional)
# If omitted, arb_ai dynamically infers it from your Flutter `l10n.yaml` file (combining `arb-dir` and `template-arb-file`). Falls back to 'lib/l10n/app_en.arb'.
source_arb: lib/l10n/app_en.arb

# Target language codes to translate into (supports regional codes like pt_BR, es_419)
targets:
  - pt
  - es
  - pl
  - ar

# Tone configuration (optional)
tone: formal

# Glossary to force specific target-language translations (optional).
# Supports smart regional fallbacks (e.g. if translating into 'pt_BR', the engine will fall back to using 'pt' glossary rules if no exact regional match is configured).
glossary:
  pt:
    hello: oi
    world: mundo
  es:
    hello: hola
  pl:
    hello: cześć
  ar:
    hello: أهلا

# Words that should not be translated (optional)
do_not_translate:
  - Flutter
  - Dart

# Maximum translation keys per single API request batch (optional, default: 100)
# Reduce this if you hit strict API capacity/rate limit boundaries (TPM/RPM)
batch_size: 100
```

### 3. Expose your API Key

Expose the target environment key (e.g. `ARB_AI_API_KEY`) in your shell or place it in a local `.env` file:

```env
ARB_AI_API_KEY=PutYourApiKeyHere
```

## Usage

Run `arb_ai` from the command line:

```bash
# Translate missing or modified keys
dart run arb_ai

# Simulate a translation run to see what would be updated
dart run arb_ai --dry-run

# Run as a CI safety gate (Exits with 1 if translations are outdated/missing)
dart run arb_ai --check

# Force a full translation of all text keys, bypassing cache
dart run arb_ai --force

# Delete the cached translation state file (.arb_ai_state.json) before translating
dart run arb_ai --clean

# Specify a custom configuration file path
dart run arb_ai -c config/custom_arb_ai.yaml
```

## CLI Options

| Flag | Abbreviation | Description |
|---|---|---|
| `--dry-run` | - | Simulates the translation process, listing keys and estimating costs without calling APIs or writing files. |
| `--check` | - | CI/CD safety check. Exits with code 1 if translations are missing or outdated, 0 otherwise. |
| `--force` | - | Bypasses the translation state cache and forces a full translation of all text keys. |
| `--clean` | - | Deletes the cached translation state file (`.arb_ai_state.json`) before running. |
| `--config` | `-c` | Path to the `arb_ai.yaml` configuration file (defaults to `arb_ai.yaml`). |
| `--help` | `-h` | Show usage instructions. |


## CI/CD Integration

Use the `--check` flag to integrate `arb_ai` into your continuous integration workflow. This ensures that pull requests cannot be merged if targets are out-of-sync or missing, preventing translation drifts in production.

Here is a complete example of a GitHub Actions workflow `.github/workflows/ci_translation_check.yml`:

```yaml
name: Verify Translations

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install dependencies
        run: dart pub get

      - name: Validate ARB Translations Alignment
        env:
          ARB_AI_API_KEY: ${{ secrets.ARB_AI_API_KEY }}
        run: dart run arb_ai --check
```

## Developer API

You can also orchestrate translations directly in Dart.

### Option A: Loading from `arb_ai.yaml` file (Recommended)

```dart
import 'dart:io';
import 'package:arb_ai/arb_ai.dart';

void main() async {
  final config = ConfigParser.parseFile(File('arb_ai.yaml'));
  final orchestrator = ArbAiOrchestrator(
    config: config,
    logger: const Logger(),
  );

  final success = await orchestrator.run();
  print('Orchestrator executed successfully: $success');
}
```

### Option B: Initializing programmatically in code

If you are building your own scripts, custom developer utilities, or pipeline automations, you can construct `ArbAiConfig` programmatically in memory:

```dart
import 'package:arb_ai/arb_ai.dart';

void main() async {
  const config = ArbAiConfig(
    provider: 'gemini',
    apiKeyEnv: 'ARB_AI_API_KEY',
    model: 'gemini-2.5-flash',
    sourceArb: 'lib/l10n/app_en.arb',
    targets: ['pt', 'es', 'fr'],
    glossary: {
      'pt': {'hello': 'oi'},
    },
    doNotTranslate: ['Flutter', 'Dart'],
    tone: 'formal',
  );

  final orchestrator = ArbAiOrchestrator(
    config: config,
    logger: const Logger(),
  );

  final success = await orchestrator.run();
  print('Manual translation pipeline finished: $success');
}
```

## Next Steps (Roadmap)

- **Anthropic Claude Provider**: Native support for Claude models via the Anthropic REST API.
- **OpenAI ChatGPT Provider**: Native support for GPT models via the OpenAI REST API.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
