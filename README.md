# Secure Token Manager Example App

<p align="center">
  <img src="https://raw.githubusercontent.com/Amrit-2002/secure_token_manager/main/doc/images/demo_app_preview.jpg" alt="Secure Token Manager Example Application" width="800"/>
</p>

This example application demonstrates how to integrate and use `secure_token_manager` in a Flutter application.

## Key Scenarios Demonstrated

1. **Authentication State Flow**: Observing changes between `AuthStateUnknown`, `AuthStateUnauthenticated`, `AuthStateAuthenticated`, and `AuthStateRefreshing`.
2. **Single-Flight Concurrent Refresh Protection**: Triggering 10 simultaneous API requests with an expired token to demonstrate that **only a single backend refresh network call** is executed.
3. **Race Condition Prevention**: Simulating a user logging out while an asynchronous token refresh is in flight, demonstrating that stale tokens are discarded and cannot resurrect the old session.
4. **Token Expiration & Leeway**: Demonstrating automatic renewal of access tokens before they expire.

## Running the Example

Run the following commands from this directory:

```bash
flutter pub get
flutter run
```

