import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart' as core_exceptions;
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> loginWithGoogle();
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? specialty,
  });
  Future<void> logout();
  Future<void> sendPasswordReset(String email);
  Future<UserModel?> getCurrentUser();
  Future<UserModel> updateProfile(UserModel user);
  Stream<UserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceImpl(this._client);

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Fetches the profile row. If it doesn't exist (e.g. first OAuth login and
  /// the DB trigger hasn't run), it creates the row from auth user metadata
  /// so the app never treats an authenticated user as unauthenticated.
  Future<UserModel> _ensureProfile(User supabaseUser) async {
    try {
      return await _fetchProfile(supabaseUser.id);
    } catch (_) {
      final meta = supabaseUser.userMetadata ?? {};
      final email = supabaseUser.email ?? '';
      final name =
          (meta['full_name'] ?? meta['name'] ?? email.split('@').first)
              .toString();
      final avatarUrl = (meta['avatar_url'] ?? meta['picture']) as String?;

      await _client.from(AppConstants.tableProfiles).upsert({
        'id': supabaseUser.id,
        'email': email,
        'nombre': name,
        'telefono': '',
        'rol': AppConstants.roleDriver,
        'activo': true,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'creado_en': DateTime.now().toIso8601String(),
      });

      return UserModel(
        id: supabaseUser.id,
        email: email,
        name: name,
        phone: '',
        role: AppConstants.roleDriver,
        avatarUrl: avatarUrl,
        rating: 0.0,
        totalServices: 0,
        isAvailable: false,
        isApproved: true,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<UserModel> _fetchProfile(String userId) async {
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson({
      'id': data['id'],
      'email': data['email'],
      'name': data['nombre'],
      'phone': data['telefono'] ?? '',
      'role': data['rol'],
      'avatar_url': data['avatar_url'],
      'rating': 0.0,
      'total_services': 0,
      'is_available': false,
      'is_approved': data['activo'] ?? true,
      'created_at': data['creado_en']?.toString() ??
          DateTime.now().toIso8601String(),
    });
  }

  // ── AuthRemoteDataSource impl ──────────────────────────────────────────────

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const core_exceptions.AuthException(
            message: 'Credenciales incorrectas');
      }
      return _ensureProfile(response.user!);
    } on AuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message);
    } on PostgrestException catch (e) {
      throw core_exceptions.ServerException(message: e.message);
    } catch (e) {
      throw core_exceptions.ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? specialty,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre': name,
          'telefono': phone,
          'rol': role,
        },
      );
      if (response.user == null) {
        throw const core_exceptions.AuthException(
            message: 'Error al registrar usuario');
      }

      final userId = response.user!.id;

      await _client.from(AppConstants.tableProfiles).update({
        'nombre': name,
        'telefono': phone,
        'rol': role,
      }).eq('id', userId);

      if (role == AppConstants.roleTechnician) {
        await _client.from(AppConstants.tableTecnicos).insert({
          'usuario_id': userId,
          'especialidad': specialty ?? '',
        });
      }

      return UserModel(
        id: userId,
        email: email,
        name: name,
        phone: phone,
        role: role,
        specialty: specialty,
        rating: 0.0,
        totalServices: 0,
        isAvailable: false,
        isApproved: role != AppConstants.roleTechnician,
        createdAt: DateTime.now(),
      );
    } on core_exceptions.AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message);
    } on PostgrestException catch (e) {
      throw core_exceptions.ServerException(message: e.message);
    } catch (e) {
      throw core_exceptions.ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      if (kIsWeb) {
        // Supabase maneja el flujo OAuth con redirect. El navegador sale de esta
        // página; cuando vuelve, onAuthStateChange + _ensureProfile toman el control.
        await _client.auth.signInWithOAuth(OAuthProvider.google);
        return Completer<UserModel>().future;
      }

      // Plataformas nativas (Android / iOS)
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '362021637892-ta4rii3kafr7l8p2en8khst5f9ipeik4.apps.googleusercontent.com',
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const core_exceptions.AuthException(
            message: 'Inicio de sesión cancelado');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const core_exceptions.AuthException(
            message: 'No se pudo obtener el token de Google. '
                'Verifica que Google esté habilitado en Supabase.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw const core_exceptions.AuthException(
            message: 'Error al autenticar con Google en Supabase');
      }

      return await _ensureProfile(response.user!);
    } on core_exceptions.AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message);
    } on PostgrestException catch (e) {
      throw core_exceptions.ServerException(message: e.message);
    } catch (e) {
      throw core_exceptions.ServerException(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw core_exceptions.AuthException(
          message: 'No se pudo enviar el correo de recuperación');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    // Use _ensureProfile so an authenticated user without a profile row
    // (e.g. first OAuth login without a DB trigger) is never treated as logged-out.
    try {
      return await _ensureProfile(user);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    try {
      await _client.from(AppConstants.tableProfiles).update({
        'nombre': user.name,
        'telefono': user.phone,
        'avatar_url': user.avatarUrl,
      }).eq('id', user.id);
      return user;
    } on PostgrestException catch (e) {
      throw core_exceptions.ServerException(message: e.message);
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final supabaseUser = event.session?.user;
      if (supabaseUser == null) return null;
      try {
        return await _ensureProfile(supabaseUser);
      } catch (_) {
        return null;
      }
    });
  }
}
