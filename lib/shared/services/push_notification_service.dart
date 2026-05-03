import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../features/auth/domain/entities/user_entity.dart';

class PushNotificationService {
  static const _appId = String.fromEnvironment('ONESIGNAL_APP_ID');

  static bool _initialized = false;
  static String? _syncedUserId;

  static bool get isConfigured => _appId.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      OneSignal.initialize(_appId);
      await OneSignal.Notifications.requestPermission(false);
      _initialized = true;
    } catch (error) {
      debugPrint('[AutoResQ] OneSignal init skipped: $error');
    }
  }

  static Future<void> syncUser(AppUser? user) async {
    if (!isConfigured || !_initialized) return;
    try {
      if (user == null) {
        if (_syncedUserId != null) {
          OneSignal.logout();
          _syncedUserId = null;
        }
        return;
      }

      if (_syncedUserId == user.id) return;
      OneSignal.login(user.id);
      _syncedUserId = user.id;
    } catch (error) {
      debugPrint('[AutoResQ] OneSignal user sync skipped: $error');
    }
  }
}
