# Contributing to secure_token_manager

Thank you for your interest in contributing to `secure_token_manager`! We welcome bug reports, feature requests, documentation improvements, and pull requests.

---

## Code of Conduct

Please be respectful, constructive, and professional in all interactions within this project.

---

## Development Setup

1. **Prerequisites**:
   - Flutter SDK `>=3.19.0`
   - Dart SDK `>=3.3.0`
2. **Clone the repository**:
   ```bash
   git clone https://github.com/example/secure_token_manager.git
   cd secure_token_manager
   ```
3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

---

## Quality Standards

Before submitting a pull request, ensure the following checks pass cleanly:

1. **Formatting**:
   Ensure all files conform to Dart formatting rules:
   ```bash
   dart format --output=none --set-exit-if-changed .
   ```
2. **Static Analysis**:
   Verify zero analyzer warnings or errors with strict mode:
   ```bash
   flutter analyze
   ```
3. **Tests**:
   Run the test suite to ensure all unit and concurrency tests pass:
   ```bash
   flutter test
   ```
4. **Publish Dry-Run**:
   Ensure pub.dev package verification passes:
   ```bash
   dart pub publish --dry-run
   ```

---

## Submitting Pull Requests

1. Fork the repository and create a descriptive branch:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. Write clean, readable code with documentation comments on all public symbols.
3. Add unit tests covering all new features and edge cases (especially concurrency and race conditions).
4. Never introduce dependencies on specific networking libraries (Dio, Chopper, etc.) into the core package.
5. Push to your branch and open a Pull Request.

---

## Reporting Issues

- Use the GitHub Issue Tracker to report bugs or request features.
- Please provide reproduction steps, Flutter/Dart versions (`flutter doctor -v`), and relevant code snippets.
- **SECURITY NOTE**: If you have discovered a security vulnerability, please follow our [Security Policy](SECURITY.md) and do NOT file a public issue.

