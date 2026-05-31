## 0.1.0

* Initial release of `arb_ai`.
* Core CLI commands and options support (`--dry-run`, `--check`, `--config`).
* Smart Diffing engine with cryptographic `.arb_ai_state.json` hash matching to save translation costs.
* Direct integration with the Gemini Native REST API (utilizing JSON schema constraints, safety flags, and exponential 429 backoff).
* Rigid ICU validation supporting plural forms and CLDR rules across languages (Polish, Arabic, Portuguese, Russian, and more).
* Auto-healing translation retry loop on failing ICU parser outputs.
* Deterministic ARB writer for clean, git-friendly output file styling.