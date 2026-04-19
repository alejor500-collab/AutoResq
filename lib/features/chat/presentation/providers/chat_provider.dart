import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/models/message_model.dart';
import '../../domain/entities/message_entity.dart';

// ─── Data Source ──────────────────────────────────────────────────────────────
final chatDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl(ref.read(supabaseClientProvider));
});

// ─── Messages Stream ──────────────────────────────────────────────────────────
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, asignacionId) {
  final ds = ref.read(chatDataSourceProvider);
  return ds.watchMessages(asignacionId).map(
    (rows) => rows
        .map((json) => MessageModel.fromJson(json))
        .toList(),
  );
});

// ─── Chat Notifier ────────────────────────────────────────────────────────────
class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRemoteDataSource _dataSource;
  final Ref _ref;

  ChatNotifier(this._dataSource, this._ref)
      : super(const AsyncValue.loading());

  Future<void> loadMessages(String asignacionId) async {
    state = const AsyncValue.loading();
    try {
      final msgs = await _dataSource.getMessages(asignacionId);
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
      await _dataSource.sendMessage(
        asignacionId: emergencyId,
        remitenteId: user.id,
        contenido: content.trim(),
      );
      return true;
    } catch (_) {
      return false;
    }
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
