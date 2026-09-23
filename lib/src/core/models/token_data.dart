import 'package:flutter/foundation.dart';
import '../clock/clock.dart';
import '../clock/system_clock.dart';

/// Represents an immutable container for authentication tokens, expiration
/// timestamps, and associated metadata.
///
/// Security:
/// - [toString] strictly redacts sensitive token strings.
/// - Instances are immutable and safe to share across asynchronous boundaries.
@immutable
class TokenData {
  /// Creates a new [TokenData] instance.
  TokenData({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.tokenType = 'Bearer',
    Map<String, dynamic>? metadata,
  }) : metadata = metadata != null
            ? Map<String, dynamic>.unmodifiable(metadata)
            : null {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'Access token must not be empty.',
      );
    }
  }

  /// The access token string used to authorize API requests.
  final String accessToken;

  /// The refresh token string used to obtain a new access token pair.
  final String? refreshToken;

  /// The date and time when the [accessToken] expires.
  ///
  /// If null, the token is treated as non-expiring based on time (e.g. an opaque token
  /// whose lifecycle is managed explicitly by server responses).
  final DateTime? expiresAt;

  /// The token type, usually `'Bearer'`.
  final String? tokenType;

  /// Optional unmodifiable metadata associated with the token pair
  /// (e.g. granted scopes, user ID, tenant ID).
  final Map<String, dynamic>? metadata;

  /// Indicates whether a [refreshToken] is present.
  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.trim().isNotEmpty;

  /// Determines whether the access token is expired at the given time,
  /// factoring in an optional [leeway] window for clock skew.
  ///
  /// If [expiresAt] is null, this returns `false`.
  bool isExpired({
    Clock clock = const SystemClock(),
    Duration leeway = Duration.zero,
  }) {
    if (expiresAt == null) {
      return false;
    }
    final effectiveExpiry = expiresAt!.subtract(leeway);
    return !clock.now.isBefore(effectiveExpiry);
  }

  /// Determines whether the access token will expire within the specified [threshold],
  /// taking into account [leeway] for clock skew.
  ///
  /// If [expiresAt] is null, this returns `false`.
  bool isExpiringSoon({
    required Duration threshold,
    Clock clock = const SystemClock(),
    Duration leeway = Duration.zero,
  }) {
    if (expiresAt == null) {
      return false;
    }
    final effectiveExpiry = expiresAt!.subtract(threshold + leeway);
    return !clock.now.isBefore(effectiveExpiry);
  }

  /// Determines whether the access token is currently valid (not expired),
  /// taking into account [leeway] for clock skew.
  ///
  /// If [expiresAt] is null, returns `true`.
  bool isValid({
    Clock clock = const SystemClock(),
    Duration leeway = Duration.zero,
  }) {
    return !isExpired(clock: clock, leeway: leeway);
  }

  /// Creates a copy of this [TokenData] with the given fields replaced.
  TokenData copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? tokenType,
    Map<String, dynamic>? metadata,
    bool clearRefreshToken = false,
    bool clearExpiresAt = false,
    bool clearTokenType = false,
    bool clearMetadata = false,
  }) {
    return TokenData(
      accessToken: accessToken ?? this.accessToken,
      refreshToken:
          clearRefreshToken ? null : (refreshToken ?? this.refreshToken),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      tokenType: clearTokenType ? null : (tokenType ?? this.tokenType),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
    );
  }

  /// Converts this [TokenData] to a JSON-compatible map for persistent serialization.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
      if (tokenType != null) 'tokenType': tokenType,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Constructs a [TokenData] instance from a JSON map.
  factory TokenData.fromJson(Map<String, dynamic> json) {
    final rawAccessToken = json['accessToken'];
    if (rawAccessToken is! String || rawAccessToken.trim().isEmpty) {
      throw const FormatException(
        'Invalid TokenData JSON: missing or invalid "accessToken"',
      );
    }

    final rawRefreshToken = json['refreshToken'] as String?;
    final rawExpiresAt = json['expiresAt'] as String?;
    final rawTokenType = json['tokenType'] as String?;
    final rawMetadata = json['metadata'] as Map<String, dynamic>?;

    DateTime? expiresAt;
    if (rawExpiresAt != null) {
      final parsed = DateTime.tryParse(rawExpiresAt);
      if (parsed != null) {
        expiresAt = parsed.toLocal();
      }
    }

    return TokenData(
      accessToken: rawAccessToken,
      refreshToken: rawRefreshToken,
      expiresAt: expiresAt,
      tokenType: rawTokenType ?? 'Bearer',
      metadata: rawMetadata,
    );
  }

  /// Returns a diagnostic string representation where secrets are strictly redacted.
  @override
  String toString() {
    final refreshDesc = refreshToken != null ? '[REDACTED]' : 'null';
    final expiryDesc = expiresAt?.toIso8601String() ?? 'none';
    final metaDesc = metadata != null ? '${metadata!.keys.toList()}' : 'none';
    return 'TokenData(accessToken: [REDACTED], refreshToken: $refreshDesc, '
        'expiresAt: $expiryDesc, tokenType: $tokenType, metadataKeys: $metaDesc)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenData &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt?.millisecondsSinceEpoch ==
            expiresAt?.millisecondsSinceEpoch &&
        other.tokenType == tokenType &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        accessToken,
        refreshToken,
        expiresAt?.millisecondsSinceEpoch,
        tokenType,
        metadata == null ? null : Object.hashAll(metadata!.entries),
      );
}
