# Contributing to `arb_ai`

First off, thank you for considering contributing to `arb_ai`! We welcome contributions from everyone and appreciate your help in making this tool better.

## Getting Started

1. **Fork the repository** and clone it locally.
2. **Install dependencies**: Run `dart pub get` to install all necessary packages.
3. **Branching**: Create a new branch for your feature or bugfix (e.g., `feature/awesome-new-feature` or `fix/issue-123`).

## Development

- **Language**: The project is written purely in Dart. Make sure you have the [Dart SDK](https://dart.dev/get-dart) installed.
- **Code Style**: We follow the standard Dart formatting. Run `dart format .` before committing your code.
- **Static Analysis**: We use strict linting rules. Ensure your code passes analysis by running `dart analyze` and resolving any warnings.

## Testing

- Write unit tests for new features or bug fixes.
- Run the test suite using `dart test` to ensure your changes do not break existing functionality.
- **Assertions**: Use `package:checks` (`check(...)`) for all assertions instead of the legacy `expect(...)` from `package:matcher`.
- **Mocking**: Use `package:mocktail` for creating mock implementations. Avoid manual mock boilerplate or code generation with `package:mockito`.


## Changelog and Versioning

We maintain a detailed changelog to track updates. 

- The changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
- This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

When contributing, please ensure your changes are appropriately documented if they are notable. However, leave version bumping to the maintainers during the release process.

## Submitting a Pull Request

1. Push your branch to your fork.
2. Open a Pull Request against the `main` branch.
3. Provide a clear and descriptive title and description for your PR.
4. Ensure CI checks (if any) pass.

Thank you for contributing!
