import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../features/auth/domain/entities/user_entity.dart';

typedef PushNotificationOpenHandler =
    Future<void> Function(PushNotificationRoute route);

class PushNotificationRoute {
  final String type;
  final String? emergencyId;
  final String? referenceId;
  final Map<String, dynamic> data;

  const PushNotificationRoute({
    required this.type,
    required this.data,
    this.emergencyId,
    this.referenceId,
  });

  String? get targetId {
    final emergency = emergencyId?.trim();
    if (emergency != null && emergency.isNotEmpty) return emergency;
    final reference = referenceId?.trim();
    if (reference != null && reference.isNotEmpty) return reference;
    return null;
  }

  static PushNotificationRoute? fromNotification(OSNotification notification) {
    final data = notification.additionalData;
    if (data == null || data.isEmpty) return null;

    final type = data['type']?.toString().trim();
    if (type == null || type.isEmpty) return null;

    return PushNotificationRoute(
      type: type,
      emergencyId: data['emergency_id']?.toString(),
      referenceId: data['reference_id']?.toString(),
      data: Map<String, dynamic>.from(data),
    );
  }
}

class PushNotificationService {
  static const _fallbackAppId = 'd0cacba5-7d95-4959-851c-95bdc9336494';
  static const _appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: _fallbackAppId,
  );

  static bool _initialized = false;
  static bool _listenersAttached = false;
  static bool _permissionRequested = false;
  static String? _syncedUserId;
  static PushNotificationOpenHandler? _openHandler;
  static PushNotificationRoute? _pendingRoute;

  static bool get isConfigured => _appId.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      }
      await OneSignal.initialize(_appId);
      _attachListeners();
      await requestPermission();
      _initialized = true;
    } catch (error) {
      debugPrint('[AutoResQ] OneSignal init skipped: $error');
    }
  }

  static Future<void> requestPermission() async {
    if (!isConfigured || _permissionRequested) return;
    try {
      _permissionRequested = true;
      await OneSignal.Notifications.requestPermission(true);
    } catch (error) {
      debugPrint('[AutoResQ] OneSignal permission skipped: $error');
    }
  }

  static Future<void> registerOpenHandler(
    PushNotificationOpenHandler handler,
  ) async {
    _openHandler = handler;
    final pendingRoute = _pendingRoute;
    if (pendingRoute == null) return;
    _pendingRoute = null;
    await handler(pendingRoute);
  }

  static void _attachListeners() {
    if (_listenersAttached) return;

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      event.notification.display();
    });

    OneSignal.Notifications.addClickListener((event) {
      final route = PushNotificationRoute.fromNotification(event.notification);
      if (route == null) return;

      final handler = _openHandler;
      if (handler == null) {
        _pendingRoute = route;
        return;
      }

      unawaited(handler(route));
    });

    _listenersAttached = true;
  }

  static Future<void> syncUser(AppUser? user) async {
    if (!isConfigured || !_initialized) return;
    try {
      if (user == null) {
        if (_syncedUserId != null) {
          await OneSignal.logout();
          _syncedUserId = null;
        }
        return;
      }

      if (_syncedUserId == user.id) return;
      await OneSignal.login(user.id);
      _syncedUserId = user.id;
      await requestPermission();
    } catch (error) {
      debugPrint('[AutoResQ] OneSignal user sync skipped: $error');
    }
  }
}
