import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'fitoak_offline_sync_queue';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Initialize connectivity listener on app launch
  void init(String baseUrl) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('🌐 Internet restored! Triggering offline sync queue...');
        flushQueue(baseUrl);
      }
    });
  }

  /// Add a failed request payload to the local storage queue
  Future<void> enqueueRequest({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentQueue = prefs.getStringList(_queueKey) ?? [];

      final newItem = jsonEncode({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'endpoint': endpoint,
        'method': method,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });

      currentQueue.add(newItem);
      await prefs.setStringList(_queueKey, currentQueue);
      debugPrint('📦 Enqueued offline item. Total pending items: ${currentQueue.length}');
    } catch (e) {
      debugPrint('❌ Failed to enqueue offline request: $e');
    }
  }

  /// Process all pending requests in local storage when online
  Future<void> flushQueue(String baseUrl) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentQueue = prefs.getStringList(_queueKey) ?? [];

      if (currentQueue.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('🔄 Flushing ${currentQueue.length} pending offline logs...');
      final List<String> remainingQueue = [];

      for (String itemStr in currentQueue) {
        try {
          final item = jsonDecode(itemStr);
          final String endpoint = item['endpoint'];
          final String method = item['method'];
          final Map<String, dynamic> payload = item['payload'];

          final uri = Uri.parse('$baseUrl$endpoint');
          http.Response response;

          if (method.toUpperCase() == 'POST') {
            response = await http
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 15));
          } else {
            response = await http
                .delete(uri)
                .timeout(const Duration(seconds: 15));
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('✅ Synced offline item: $endpoint');
          } else {
            debugPrint('⚠️ Sync failed (${response.statusCode}) for $endpoint. Retaining in queue.');
            remainingQueue.add(itemStr);
          }
        } catch (err) {
          debugPrint('⚠️ Network error during flush: $err. Retaining item.');
          remainingQueue.add(itemStr);
        }
      }

      await prefs.setStringList(_queueKey, remainingQueue);
      debugPrint('🏁 Sync completed. Pending items remaining: ${remainingQueue.length}');
    } catch (e) {
      debugPrint('❌ Error during queue flush: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Get pending queue count for UI badge indicator
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentQueue = prefs.getStringList(_queueKey) ?? [];
    return currentQueue.length;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

final offlineSyncService = OfflineSyncService();