// filepath: /Users/momen_mac/Desktop/flutter_application/lib/services/messaging/web_message_sync.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/services/messaging/message_event_bus.dart';

/// Special service for handling web-specific message synchronization
/// This service ensures unread counts stay properly updated on web platforms
/// where Firebase event delivery can be less reliable
class WebMessageSyncService {
  // Singleton implementation
  static final WebMessageSyncService _instance = WebMessageSyncService._internal();
  factory WebMessageSyncService() => _instance;
  WebMessageSyncService._internal();

  // Timer for periodic refresh
  Timer? _refreshTimer;
  
  // Track if service is initialized
  bool _isInitialized = false;
  
  // The function that provides the actual count
  Future<int> Function()? _countProvider;
  
  /// Initialize the sync service with count provider
  void initialize(Future<int> Function() countProvider) {
    if (_isInitialized) return;
    
    _countProvider = countProvider;
    _isInitialized = true;
    
    // Only set up refresh timer on web platform
    if (kIsWeb) {
      _setupRefreshTimer();
    }
    
    debugPrint('🌐 WebMessageSyncService: Initialized (active: ${kIsWeb})');
  }
  
  /// Set up periodic refresh timer (web only)
  void _setupRefreshTimer() {
    // Cancel any existing timer
    _refreshTimer?.cancel();
    
    // Start a new timer that refreshes every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshUnreadCount();
    });
    
    debugPrint('⏰ WebMessageSyncService: Refresh timer started');
  }
  
  /// Force a one-time refresh of unread counts
  Future<void> refreshNow() async {
    if (!_isInitialized || _countProvider == null) return;
    await _refreshUnreadCount();
  }
  
  /// Internal refresh method
  Future<void> _refreshUnreadCount() async {
    if (!_isInitialized || _countProvider == null) return;
    
    try {
      final count = await _countProvider!();
      MessageEventBus().notifyUnreadCountChanged(count);
      debugPrint('🔄 WebMessageSyncService: Refreshed unread count: $count');
    } catch (e) {
      debugPrint('❌ WebMessageSyncService: Refresh error: $e');
    }
  }
  
  /// Cleanup resources
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isInitialized = false;
    debugPrint('🌐 WebMessageSyncService: Disposed');
  }
}