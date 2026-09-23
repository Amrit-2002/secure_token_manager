# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-24

### Added
- Core `TokenData` model with secret redaction in `toString()`, JSON serialization, and immutable value equality.
- `Clock` and `SystemClock` abstractions for deterministic expiration testing.
- `TokenStorage` interface and `MemoryTokenStorage` implementation for testing and development.
- Platform-aware `SecureTokenStorage` implementation leveraging:
  - Android KeyStore (AES-GCM encryption with RSA-OAEP key wrapping).
  - Apple iOS & macOS Keychain Services (`KeychainAccessibility.first_unlock`).
  - Windows Data Protection API (DPAPI).
  - Linux Secret Service API (`libsecret`).
- Explicit web platform boundary throwing `PlatformNotSupportedException` to prevent insecure `localStorage` fallbacks.
- Single-flight `RefreshCoordinator` protecting against concurrent refresh race conditions and the thundering herd problem.
- Monotonically increasing session epoch guard preventing logout race conditions (stale in-flight refresh response discarding).
- Comprehensive error taxonomy with `TokenException` and concrete typed exceptions distinguishing transient network errors from authentication-invalidating errors.
- Reactive `AuthState` sealed class hierarchy (`unknown`, `unauthenticated`, `authenticated`, `refreshing`, `error`).
- Non-sensitive `AuthEvent` stream for APM, Crashlytics, and analytics monitoring.
- Zero-dependency architecture decoupled from any specific HTTP client (Dio, Chopper, `package:http`).
- Complete interactive example Flutter application demonstrating concurrent requests, single-flight refresh protection, and logout race handling.
- Comprehensive test suite with 59 tests covering concurrency, storage failures, leeway skew, and lifecycle transitions.

