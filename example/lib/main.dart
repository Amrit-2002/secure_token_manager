import 'dart:async';
import 'package:flutter/material.dart';
import 'package:secure_token_manager/secure_token_manager.dart';

void main() {
  runApp(const SecureTokenManagerExampleApp());
}

/// Root widget for the example application.
class SecureTokenManagerExampleApp extends StatelessWidget {
  /// Creates the root example widget.
  const SecureTokenManagerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Token Manager Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const TokenManagerDemoPage(),
    );
  }
}

/// Interactive demonstration page for [TokenManager].
class TokenManagerDemoPage extends StatefulWidget {
  /// Creates the demo page.
  const TokenManagerDemoPage({super.key});

  @override
  State<TokenManagerDemoPage> createState() => _TokenManagerDemoPageState();
}

class _TokenManagerDemoPageState extends State<TokenManagerDemoPage> {
  late final TokenManager _tokenManager;
  final List<String> _activityLog = <String>[];
  int _actualRefreshNetworkCallCount = 0;
  bool _isSlowRefreshSimulated = false;

  @override
  void initState() {
    super.initState();

    // In this example, we use MemoryTokenStorage for platform-independent desktop/preview convenience.
    // In actual production Flutter apps, omit the storage parameter or use SecureTokenStorage().
    _tokenManager = TokenManager(
      storage: MemoryTokenStorage(),
      options: const TokenManagerOptions(
        clockSkewLeeway: Duration(seconds: 10),
      ),
      refreshToken: (currentRefreshToken) async {
        _actualRefreshNetworkCallCount++;
        _addLog(
          '🌐 Network: Refresh API invoked on backend (Call #$_actualRefreshNetworkCallCount).',
        );

        if (_isSlowRefreshSimulated) {
          _addLog('⏳ Simulating 2.5s network delay for refresh...');
          await Future<void>.delayed(const Duration(milliseconds: 2500));
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }

        final newExpiry = DateTime.now().add(const Duration(minutes: 5));
        _addLog('✅ Network: Backend issued new access & refresh tokens.');

        return TokenData(
          accessToken: 'access_${DateTime.now().millisecondsSinceEpoch}',
          refreshToken: 'refresh_${DateTime.now().millisecondsSinceEpoch}',
          expiresAt: newExpiry,
        );
      },
    );

    // Listen to observability events
    _tokenManager.events.listen((event) {
      _addLog('📣 Event: $event');
    });

    // Initialize session
    _tokenManager.initialize().then((_) {
      _addLog('🚀 TokenManager initialized successfully.');
    }).catchError((Object error) {
      _addLog('❌ Initialization failed: $error');
    });
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      final timestamp = TimeOfDay.now().format(context);
      _activityLog.insert(0, '[$timestamp] $message');
      if (_activityLog.length > 50) {
        _activityLog.removeLast();
      }
    });
  }

  Future<void> _login() async {
    final tokens = TokenData(
      accessToken: 'access_login_initial_token',
      refreshToken: 'refresh_login_initial_token',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      tokenType: 'Bearer',
      metadata: const {'user': 'developer@example.com'},
    );

    await _tokenManager.setTokens(tokens);
    _addLog('👤 Logged in with fresh token pair (expires in 5 minutes).');
  }

  Future<void> _makeSingleApiRequest() async {
    _addLog('➡️ Initiating API request (fetching valid access token)...');
    try {
      final token = await _tokenManager.getValidAccessToken();
      // Mask token display in UI for safety
      final masked = token.length > 12
          ? '${token.substring(0, 6)}...${token.substring(token.length - 4)}'
          : token;
      _addLog('🎉 API request successful! Used token: $masked');
    } catch (e) {
      _addLog('❌ API request failed: $e');
    }
  }

  Future<void> _simulateExpiredToken() async {
    if (_tokenManager.currentTokens == null) {
      _addLog('⚠️ Please log in first before simulating expiration.');
      return;
    }

    // Force expiration into the past
    final expiredTokens = _tokenManager.currentTokens!.copyWith(
      expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    await _tokenManager.setTokens(expiredTokens);
    _addLog('⏰ Current token manually expired (timestamp set to -2 mins).');
  }

  Future<void> _trigger10ConcurrentRequests() async {
    _addLog('🚀 Launching 10 SIMULTANEOUS API requests...');
    final beforeCallCount = _actualRefreshNetworkCallCount;

    final stopwatch = Stopwatch()..start();
    final futures = List<Future<String>>.generate(
      10,
      (index) async {
        final token = await _tokenManager.getValidAccessToken();
        return 'Request #${index + 1}: ${token.substring(0, 7)}...';
      },
    );

    try {
      final results = await Future.wait(futures);
      stopwatch.stop();

      final refreshCallsMade = _actualRefreshNetworkCallCount - beforeCallCount;
      _addLog(
        '🏆 All 10 requests completed in ${stopwatch.elapsedMilliseconds}ms! '
        'Backend refresh API calls triggered: $refreshCallsMade (Expected: 1).',
      );
      for (final res in results.take(3)) {
        _addLog('   $res');
      }
      _addLog('   ... (${results.length} total callers resolved)');
    } catch (e) {
      _addLog('❌ Concurrent requests failed: $e');
    }
  }

  Future<void> _simulateSlowRefreshAndLogout() async {
    _isSlowRefreshSimulated = true;
    _addLog('🧪 Testing Logout-during-refresh race condition...');

    // 1. Expire token
    await _simulateExpiredToken();

    // 2. Start token request that initiates slow 2.5s refresh
    _addLog('1️⃣ Caller #1 requesting token (initiating 2.5s refresh)...');
    final inFlightRequest = _tokenManager.getValidAccessToken();

    // 3. User taps logout 400ms later while network is still running
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _addLog('2️⃣ User tapped Logout while refresh is still in flight!');
    await _tokenManager.logout();

    // 4. Await original request to observe safe rejection
    try {
      await inFlightRequest;
      _addLog('❌ ERROR: Refresh incorrectly restored session!');
    } catch (e) {
      _addLog('✅ SUCCESS: Refresh safely discarded! Error: $e');
      _addLog(
        '🔒 Stored tokens remaining: ${_tokenManager.currentTokens == null ? 'NULL (SAFE)' : 'LEAKED!'}',
      );
    } finally {
      _isSlowRefreshSimulated = false;
    }
  }

  Future<void> _logout() async {
    await _tokenManager.logout();
    _addLog('👋 User logged out. Storage & in-memory cache cleared.');
  }

  @override
  void dispose() {
    _tokenManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Token Manager Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<AuthState>(
        stream: _tokenManager.authState,
        initialData: _tokenManager.currentAuthState,
        builder: (context, snapshot) {
          final authState = snapshot.data ?? const AuthStateUnknown();
          final isAuth = authState.isAuthenticated;
          final isRefreshing = authState.isRefreshing;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // State banner card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isAuth
                                  ? Icons.check_circle
                                  : (isRefreshing
                                      ? Icons.sync
                                      : Icons.cancel_outlined),
                              color: isAuth
                                  ? Colors.green
                                  : (isRefreshing
                                      ? Colors.orange
                                      : Colors.grey),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'State: ${authState.runtimeType}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Backend Refresh Network Calls: $_actualRefreshNetworkCallCount',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_tokenManager.currentTokens?.expiresAt != null) ...[
                          const Divider(height: 20),
                          Text(
                            'Expires at: ${_tokenManager.currentTokens!.expiresAt!.toLocal()}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isAuth ? null : _login,
                      icon: const Icon(Icons.login),
                      label: const Text('1. Login'),
                    ),
                    ElevatedButton.icon(
                      onPressed: isAuth ? _makeSingleApiRequest : null,
                      icon: const Icon(Icons.send),
                      label: const Text('2. API Request'),
                    ),
                    ElevatedButton.icon(
                      onPressed: isAuth ? _simulateExpiredToken : null,
                      icon: const Icon(Icons.timer_off),
                      label: const Text('3. Expire Token'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                      ),
                      onPressed: isAuth ? _trigger10ConcurrentRequests : null,
                      icon: const Icon(Icons.bolt, color: Colors.indigo),
                      label: const Text('4. 10 Concurrent Calls'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isAuth ? _simulateSlowRefreshAndLogout : null,
                      icon: const Icon(Icons.warning_amber),
                      label: const Text('5. Race: Logout in Refresh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isAuth ? _logout : null,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Diagnostic Activity Log
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Activity Log:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _activityLog.clear();
                        });
                      },
                      child: const Text('Clear Log'),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: _activityLog.isEmpty
                        ? const Center(
                            child: Text(
                              'Perform actions above to observe token lifecycle & logs.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _activityLog.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  _activityLog[index],
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
