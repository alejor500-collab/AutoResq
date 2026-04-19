import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
      final profile = await _fetchProfile(response.user!.id);
      return profile;
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
      // Las claves de metadata deben coincidir con lo que lee el trigger
      // (nombre, telefono, rol) para que se guarden correctamente en `usuarios`.
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

      // El trigger ya creó el registro en `usuarios`. Actualizamos para
      // garantizar que nombre, telefono y rol queden correctos.
      await _client.from(AppConstants.tableProfiles).update({
        'nombre': name,
        'telefono': phone,
        'rol': role,
      }).eq('id', userId);

      // Si es técnico, crear el registro en la tabla `tecnicos`.
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
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const core_exceptions.AuthException(message: 'Inicio de sesión cancelado');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw const core_exceptions.AuthException(message: 'No se pudo obtener el token de Google');
      }

      // Autenticar en Firebase
      final firebaseCredential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await firebase_auth.FirebaseAuth.instance.signInWithCredential(firebaseCredential);

      // Autenticar en Supabase con el idToken de Google
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        throw const core_exceptions.AuthException(message: 'Error al autenticar con Google');
      }

      // Obtener perfil existente o crear uno nuevo
      try {
        return await _fetchProfile(response.user!.id);
      } catch (_) {
        final name = googleUser.displayName ?? googleUser.email.split('@')[0];
        await _client.from(AppConstants.tableProfiles).upsert({
          'id': response.user!.id,
          'email': googleUser.email,
          'nombre': name,
          'telefono': '',
          'rol': AppConstants.roleDriver,
          'activo': true,
          'creado_en': DateTime.now().toIso8601String(),
        });
        return UserModel(
          id: response.user!.id,
          email: googleUser.email,
          name: name,
          phone: '',
          role: AppConstants.roleDriver,
          rating: 0.0,
          totalServices: 0,
          isAvailable: false,
          isApproved: true,
          createdAt: DateTime.now(),
        );
      }
    } on core_exceptions.AuthException {
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message ?? 'Error con Google');
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
    await firebase_auth.FirebaseAuth.instance.signOut();
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
    try {
      return await _fetchProfile(user.id);
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
      if (event.session?.user == null) return null;
      try {
        return await _fetchProfile(event.session!.user.id);
      } catch (_) {
        return null;
      }
    });
  }

  Future<UserModel> _fetchProfile(String userId) async {
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .single();
    // La tabla `usuarios` usa nombres de columna en español.
    // Mapeamos a los nombres que espera UserModel.fromJson.
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
}
