# Changelog

## [0.3.0] - 2026-09-02

### Added

- Automatic detection and pruning of obsolete/orphan keys from target `.arb` files and local state cache (`.arb_ai_state.json`) when keys are removed from the source ARB template.
- Obsolete/deleted key diagnostics in `--check` and `--dry-run` modes.
- Output sink customization in `Logger` (`outputSink`, `errorSink`) for isolated testing while preserving `const Logger()` compatibility.
- Unit test coverage for `ArbAiCommandRunner.run()` exit codes and usage outputs.

### Changed

- Updated `ArbAiCommandRunner.run()` to return integer exit codes (`0`, `1`, `64`) instead of calling `exit()` directly, enabling integration testing.
- Standardized `Logger` on `stdout.writeln` and `stderr.writeln`.
- Aligned `batch_size` default documentation and example in `example/arb_ai_example.yaml` to `100`.
- Updated GitHub Actions publish workflow to `actions/checkout@v6` for Node 24 runtime alignment.
- Upgraded dependencies: `yaml` to `^3.1.4`, `http` to `^1.6.0`, and `test` to `^1.31.2`, along with 13 transitive dependencies.
- Added `tmp/` and `coverage/` to `.gitignore` and `.pubignore`.

### Fixed

- Fixed target translation files accumulating deleted/obsolete keys indefinitely.
- Fixed `ArbAiConfig` equality and hash code calculation to adhere to Dart's `hashCode` contract (`a == b => a.hashCode == b.hashCode`) using deep collection comparison instead of `.toString()`.

## [0.2.1] - 2026-06-03

### Changed

- Updated default model from `gemini-2.5-flash` to `gemini-3.5-flash` after demonstrating stability in real-world tests.

### Fixed

- Fixed ICU plural syntax warnings caused by overlapping categories (e.g., having both `=1` and `one`) in target translations.
- Added base-language fallback (e.g., `pt` for `pt_BR`) for target locales to enforce CLDR category validations correctly.

## [0.2.0] - 2026-06-03

### Added

- Early "fail-fast" validation for the AI provider API key, ensuring the CLI halts immediately with clear instructions if the key is missing, rather than parsing files and starting the pipeline only to fail midway.
- Auto-formatting (pretty-print) for raw API JSON error responses in the terminal console to improve diagnostic readability.
- Progressive batch saving that writes target `.arb` files and updates the state cache (`.arb_ai_state.json`) immediately after each batch of translations is completed and validated, preventing data loss and maintaining translation integrity.

### Changed

- Updated default model from `gemini-3.5-flash` to `gemini-2.5-flash` for improved availability and stability.
- Increased default batch size from 25 to 100 to optimize API quota consumption.
- Expanded CLDR plural rules validation support to cover more languages: Czech (`cs`), Slovak (`sk`), Romanian (`ro`), Croatian (`hr`), Bosnian (`bs`), Serbian (`sr`), Lithuanian (`lt`), Latvian (`lv`), and Slovenian (`sl`).

### Fixed

- Added translation retry error feedback, passing validation issues from previous attempts back to the LLM context to enable self-correction.
- Implemented smart HTTP 429 rate limit backoff parser that respects the API's `retryDelay` and aborts if it exceeds 120 seconds.
- Added automated retries for transient server errors (`500`, `502`, `503`) and instant fail-fast for fatal API errors (`400`, `401`, `403`).


## [0.1.0] - 2026-05-31

### Added

- Initial release of `arb_ai`.
- Core CLI commands and options support (`--dry-run`, `--check`, `--config`, `--force`, `--clean`).
- Smart Diffing engine with cryptographic `.arb_ai_state.json` hash matching to save translation costs.
- Direct integration with the Gemini Native REST API (utilizing JSON schema constraints, safety flags, and exponential 429 backoff).
- Rigid ICU validation supporting plural forms and CLDR rules across languages (Polish, Arabic, Portuguese, Russian, and more).
- Auto-healing translation retry loop on failing ICU parser outputs.
- Deterministic ARB writer for clean, git-friendly output file styling.
