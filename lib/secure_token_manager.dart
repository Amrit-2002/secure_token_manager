/// A production-grade, platform-aware authentication token lifecycle manager
/// for Flutter applications with single-flight concurrent refresh protection.
library secure_token_manager;

// Core time abstractions
export 'src/core/clock/clock.dart';
export 'src/core/clock/system_clock.dart';

// Core error taxonomy
export 'src/core/errors/token_exceptions.dart';

// Safe logging
export 'src/core/logging/token_logger.dart';

// Token model
export 'src/core/models/token_data.dart';

// Manager & options
export 'src/manager/token_manager.dart';
export 'src/manager/token_manager_options.dart';

// Refresh callback contracts
export 'src/refresh/refresh_coordinator.dart'
    show RefreshErrorClassifier, RefreshTokenCallback;

// Authentication states and observability events
export 'src/state/auth_event.dart';
export 'src/state/auth_state.dart';

// Storage abstractions and implementations
export 'src/storage/memory_token_storage.dart';
export 'src/storage/secure_token_storage.dart';
export 'src/storage/token_storage.dart';
