import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

// ─── Supabase client ──────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─── Data Source ──────────────────────────────────────────────────────────────
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.read(supabaseClientProvider));
});

// ─── Repository ───────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

// ─── Auth State (stream) ──────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return repo.authStateChanges;
});

// ─── Current User ─────────────────────────────────────────────────────────────
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

// ─── Auth Notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final result = await _repo.getCurrentUser();
    result.fold(
      (failure) => state = const AsyncValue.data(null),
      (user) => state = AsyncValue.data(user),
    );
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    final result = await _repo.login(email: email, password: password);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (user) {
        state = AsyncValue.data(user);
        return true;
      },
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? specialty,
  }) async {
    state = const AsyncValue.loading();
    final result = await _repo.register(
      email: email,
      password: password,
      name: name,
      phone: phone,
      role: role,
      specialty: specialty,
    );
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (user) {
        state = AsyncValue.data(user);
        return true;
      },
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }

  Future<bool> sendPasswordReset(String email) async {
    final result = await _repo.sendPasswordReset(email);
    return result.fold((_) => false, (_) => true);
  }

  Future<bool> updateProfile(AppUser user) async {
    final result = await _repo.updateProfile(user);
    return result.fold(
      (_) => false,
      (updated) {
        state = AsyncValue.data(updated);
        return true;
      },
    );
  }

  AppUser? get currentUser => state.value;
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
