import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  Future<void> updatePassword(String newPassword);
  Future<UserModel?> getCurrentUser();
  Future<UserModel> updateProfile(UserModel user);
  Stream<UserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceImpl(this._client);

  // ── Helpers ────────────────────────────────────────────────────────────────

  core_exceptions.NetworkException _networkException() {
    return const core_exceptions.NetworkException(
      message:
          'No se pudo conectar con AutoResQ. Revisa tu internet, VPN, firewall o bloqueo del navegador e intenta nuevamente.',
    );
  }

  bool _looksLikeNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('clientexception') ||
        message.contains('failed to fetch') ||
        message.contains('xmlhttprequest error') ||
        message.contains('socketexception') ||
        message.contains('connection refused') ||
        message.contains('timed out') ||
        message.contains('network');
  }

  /// Fetches the profile row. If it doesn't exist (e.g. first OAuth login and
  /// the DB trigger hasn't run), it creates the row from auth user metadata
  /// so the app never treats an authenticated user as unauthenticated.
  Future<UserModel> _ensureProfile(User supabaseUser) async {
    try {
      return await _fetchProfile(supabaseUser.id);
    } catch (_) {
      final meta = supabaseUser.userMetadata ?? {};
      final email = supabaseUser.email ?? '';
      final name = (meta['full_name'] ?? meta['name'] ?? email.split('@').first)
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
        isActive: true,
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

    String? specialty;
    String? verificationStatus;
    String? rejectionReason;
    double? lat;
    double? lng;
    double rating = (data['calificacion_promedio'] as num?)?.toDouble() ?? 0.0;
    int totalServices = (data['total_servicios'] as num?)?.toInt() ?? 0;
    bool isAvailable = false;
    final isActive = data['activo'] as bool? ?? true;
    bool isApproved = isActive;

    Map<String, dynamic>? tecnico;
    try {
      tecnico = await _client
          .from(AppConstants.tableTecnicos)
          .select(
              'id, especialidad, disponible, estado_verificacion, motivo_rechazo, ubicacion_lat, ubicacion_lng, calificacion_promedio, total_servicios')
          .eq('usuario_id', userId)
          .maybeSingle();
    } on PostgrestException {
      tecnico = await _client
          .from(AppConstants.tableTecnicos)
          .select(
              'id, especialidad, disponible, estado_verificacion, motivo_rechazo, ubicacion_lat, ubicacion_lng, calificacion_promedio')
          .eq('usuario_id', userId)
          .maybeSingle();
    }
    specialty = tecnico?['especialidad'] as String?;
    isAvailable = tecnico?['disponible'] as bool? ?? false;
    verificationStatus = tecnico?['estado_verificacion'] as String?;
    rejectionReason = tecnico?['motivo_rechazo'] as String?;
    lat = (tecnico?['ubicacion_lat'] as num?)?.toDouble();
    lng = (tecnico?['ubicacion_lng'] as num?)?.toDouble();
    rating =
        (tecnico?['calificacion_promedio'] as num?)?.toDouble() ?? rating;
    totalServices =
        (tecnico?['total_servicios'] as num?)?.toInt() ?? totalServices;

    final tecnicoId = tecnico?['id']?.toString();
    if (totalServices == 0 && tecnicoId != null && tecnicoId.isNotEmpty) {
      try {
        final finishedAssignments = await _client
            .from(AppConstants.tableAsignaciones)
            .select('id')
            .eq('tecnico_id', tecnicoId)
            .eq('estado', AppConstants.assignFinished);
        totalServices = (finishedAssignments as List).length;
      } catch (_) {
        totalServices = 0;
      }
    }

    if (data['rol'] == AppConstants.roleTechnician) {
      // Un tecnico solo opera como tecnico cuando el administrador lo aprobo.
      isApproved =
          verificationStatus == AppConstants.verificationApproved && isApproved;
    }

    return UserModel.fromJson({
      'id': data['id'],
      'email': data['email'],
      'name': data['nombre'],
      'phone': data['telefono'] ?? '',
      'role': data['rol'],
      'avatar_url': data['avatar_url'],
      'rating': rating,
      'total_services': totalServices,
      'is_active': isActive,
      'is_available': isAvailable,
      'is_approved': isApproved,
      'specialty': specialty,
      'lat': lat,
      'lng': lng,
      'created_at':
          data['creado_en']?.toString() ?? DateTime.now().toIso8601String(),
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
      'account_disabled_reason': data['account_disabled_reason'] as String?,
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
      if (_looksLikeNetworkError(e)) throw _networkException();
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
      final profileRole = role == AppConstants.roleTechnician
          ? AppConstants.roleDriver
          : role;

      await _client.from(AppConstants.tableProfiles).upsert({
        'id': userId,
        'email': email,
        'nombre': name,
        'telefono': phone,
        'rol': profileRole,
        'activo': true,
      }, onConflict: 'id');

      if (role == AppConstants.roleTechnician) {
        await _client.from(AppConstants.tableTecnicos).upsert({
          'usuario_id': userId,
          'especialidad': specialty ?? '',
          'estado_verificacion': AppConstants.verificationPending,
          'disponible': false,
          'motivo_rechazo': null,
        }, onConflict: 'usuario_id');
      }

      return UserModel(
        id: userId,
        email: email,
        name: name,
        phone: phone,
        role: profileRole,
        specialty: specialty,
        rating: 0.0,
        totalServices: 0,
        isActive: true,
        isAvailable: false,
        isApproved: true,
        createdAt: DateTime.now(),
        verificationStatus: role == AppConstants.roleTechnician
            ? AppConstants.verificationPending
            : null,
      );
    } on core_exceptions.AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message);
    } on PostgrestException catch (e) {
      throw core_exceptions.ServerException(message: e.message);
    } catch (e) {
      if (_looksLikeNetworkError(e)) throw _networkException();
      throw core_exceptions.ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      if (kIsWeb) {
        await _client.auth.signInWithOAuth(OAuthProvider.google);
        return Completer<UserModel>().future;
      }

      // Android / iOS: Chrome Custom Tab → deep link → Supabase PKCE callback
      final completer = Completer<UserModel>();
      late StreamSubscription<AuthState> sub;

      sub = _client.auth.onAuthStateChange.listen((event) async {
        if (event.event == AuthChangeEvent.signedIn &&
            event.session != null &&
            !completer.isCompleted) {
          try {
            final user = await _ensureProfile(event.session!.user);
            completer.complete(user);
          } catch (e) {
            completer.completeError(
              core_exceptions.AuthException(message: e.toString()),
            );
          } finally {
            await sub.cancel();
          }
        }
      });

      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.autoresq.app://login-callback',
      );

      if (!launched) {
        await sub.cancel();
        throw const core_exceptions.AuthException(
            message: 'No se pudo abrir el navegador para Google');
      }

      return completer.future;
    } on core_exceptions.AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message);
    } on PostgrestException catch (e) {
      throw core_exceptions.ServerException(message: e.message);
    } catch (e) {
      if (_looksLikeNetworkError(e)) throw _networkException();
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
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.autoresq.app://reset-password',
      );
    } catch (e) {
      if (_looksLikeNetworkError(e)) throw _networkException();
      throw const core_exceptions.AuthException(
          message: 'No se pudo enviar el correo de recuperación');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw core_exceptions.AuthException(message: e.message);
    } catch (e) {
      if (_looksLikeNetworkError(e)) throw _networkException();
      throw core_exceptions.ServerException(message: e.toString());
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

      if (user.role == AppConstants.roleTechnician && user.specialty != null) {
        await _client.from(AppConstants.tableTecnicos).update({
          'especialidad': user.specialty,
        }).eq('usuario_id', user.id);
      }

      final fresh = await _fetchProfile(user.id);
      return UserModel(
        id: fresh.id,
        email: fresh.email,
        name: fresh.name,
        phone: fresh.phone,
        role: fresh.role,
        avatarUrl: fresh.avatarUrl,
        rating: fresh.rating,
        totalServices: fresh.totalServices,
        isActive: fresh.isActive,
        isAvailable: fresh.isAvailable,
        isApproved: fresh.isApproved,
        specialty: user.specialty,
        lat: fresh.lat,
        lng: fresh.lng,
        createdAt: fresh.createdAt,
        verificationStatus: fresh.verificationStatus,
        rejectionReason: fresh.rejectionReason,
        accountDisabledReason: fresh.accountDisabledReason,
      );
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
