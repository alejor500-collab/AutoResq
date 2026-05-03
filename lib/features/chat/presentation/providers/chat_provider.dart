import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../domain/entities/message_entity.dart';

// ─── Data Source ──────────────────────────────────────────────────────────────
final chatDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl(ref.read(supabaseClientProvider));
});

// ─── Messages Stream ──────────────────────────────────────────────────────────
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, emergencyId) async* {
  final ds = ref.read(chatDataSourceProvider);
  final assignmentId = await ds.getAssignmentIdForEmergency(emergencyId);
  yield await ds.getMessages(assignmentId);
  yield* Stream.periodic(const Duration(seconds: 2)).asyncMap(
    (_) => ds.getMessages(assignmentId),
  );
});

// ─── Chat Notifier ────────────────────────────────────────────────────────────
class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRemoteDataSource _dataSource;
  final Ref _ref;

  ChatNotifier(this._dataSource, this._ref)
      : super(const AsyncValue.loading());

  Future<void> loadMessages(String emergencyId) async {
    state = const AsyncValue.loading();
    try {
      final assignmentId =
          await _dataSource.getAssignmentIdForEmergency(emergencyId);
      final msgs = await _dataSource.getMessages(assignmentId);
      state = AsyncValue.data(msgs);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<bool> sendMessage({
    required String emergencyId,
    required String content,
  }) async {
    final user = _ref.read(authNotifierProvider).value;
    if (user == null) return false;

    try {
      final assignmentId =
          await _dataSource.getAssignmentIdForEmergency(emergencyId);
      await _dataSource.sendMessage(
        asignacionId: assignmentId,
        remitenteId: user.id,
        contenido: content.trim(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markIncomingAsDelivered(String emergencyId) async {
    final user = _ref.read(authNotifierProvider).value;
    if (user == null) return;
    try {
      final assignmentId =
          await _dataSource.getAssignmentIdForEmergency(emergencyId);
      await _dataSource.markIncomingAsDelivered(assignmentId, user.id);
    } catch (_) {}
  }

  Future<void> markIncomingAsRead(String emergencyId) async {
    final user = _ref.read(authNotifierProvider).value;
    if (user == null) return;
    try {
      final assignmentId =
          await _dataSource.getAssignmentIdForEmergency(emergencyId);
      await _dataSource.markIncomingAsRead(assignmentId, user.id);
    } catch (_) {}
  }
}

final chatNotifierProvider =
    StateNotifierProvider.family<ChatNotifier, AsyncValue<List<ChatMessage>>,
        String>((ref, emergencyId) {
  final notifier = ChatNotifier(
    ref.read(chatDataSourceProvider),
    ref,
  );
  notifier.loadMessages(emergencyId);
  return notifier;
});
