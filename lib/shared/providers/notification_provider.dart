import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';
import 'auth_provider.dart';

class AppNotification {
  final String id;
  final String type;
  final String message;
  final bool read;
  final String? referenceId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    this.referenceId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['tipo']?.toString() ?? 'general',
      message: json['mensaje']?.toString() ?? '',
      read: json['leida'] == true,
      referenceId: json['referencia_id']?.toString(),
      createdAt: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get title {
    return switch (type) {
      'nueva_solicitud' => 'Nueva solicitud',
      'nuevo_mensaje' => 'Nuevo mensaje',
      'solicitud_cancelada' => 'Solicitud cancelada',
      'tecnico_cancelo' => 'Tecnico cancelado',
      'solicitud_aceptada' => 'Solicitud aceptada',
      'tecnico_en_ruta' => 'Tecnico en tu ubicacion',
      'servicio_finalizado' => 'Servicio finalizado',
      _ => 'Notificacion',
    };
  }

  String get timeLabel => AppHelpers.formatDateTime(createdAt);
}

final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) async* {
  final user = ref.watch(authNotifierProvider).value ??
      ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield const [];
    return;
  }

  final client = ref.read(supabaseClientProvider);
  Future<List<AppNotification>> fetch() async {
    final rows = await client
        .from(AppConstants.tableNotificaciones)
        .select()
        .eq('usuario_id', user.id)
        .order('fecha', ascending: false)
        .limit(50);
    return (rows as List)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  yield await fetch();
  yield* client
      .from(AppConstants.tableNotificaciones)
      .stream(primaryKey: ['id'])
      .eq('usuario_id', user.id)
      .order('fecha', ascending: false)
      .asyncMap((_) => fetch());
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (notifications == null) return 0;
  return notifications.where((notification) => !notification.read).length;
});

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref _ref;

  NotificationActions(this._ref);

  Future<void> markAllRead() async {
    final user = _ref.read(authNotifierProvider).value ??
        _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await _ref
        .read(supabaseClientProvider)
        .from(AppConstants.tableNotificaciones)
        .update({'leida': true})
        .eq('usuario_id', user.id)
        .eq('leida', false);
  }
}
