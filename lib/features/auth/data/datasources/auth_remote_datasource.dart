import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/technician_specialties.dart';
import '../../../../core/errors/exceptions.dart' as core_exceptions;
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> loginWithGoogle({
    String? role,
    String? specialty,
  });
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
  static const _googleRedirectTo = 'com.autoresq.app://login-callback';
  static const _googleWebClientId =
      '362021637892-ta4rii3kafr7l8p2en8khst5f9ipeik4.apps.googleusercontent.com';

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

  String? _normalizeSpecialtyCode(String? rawValue) {
    final trimmed = rawValue?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final normalized = TechnicianSpecialties.normalizeCode(trimmed);
    if (normalized != null) return normalized;
    throw const core_exceptions.AuthException(
      message: 'Selecciona una especialidad tecnica valida.',
    );
  }

  bool get _usesNativeGoogleSignIn =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  GoogleSignIn _buildGoogleSignIn() {
    return GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: _googleWebClientId,
    );
  }

  Future<UserModel> _loginWithNativeGoogle({
    String? role,
    String? specialty,
  }) async {
    final googleSignIn = _buildGoogleSignIn();

    // Start an interactive flow without revoking the OAuth client authorization.
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const core_exceptions.AuthException(
        message: 'Inicio de sesion con Google cancelado.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null || idToken.isEmpty) {
      throw const core_exceptions.AuthException(
        message: 'Google no devolvio un ID token valido.',
      );
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw const core_exceptions.AuthException(
        message: 'Google no devolvio un access token valido.',
      );
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw const core_exceptions.AuthException(
        message: 'No se pudo completar el acceso con Google.',
      );
    }

    return _ensureProfile(
      user,
      role: role,
      specialty: specialty,
    );
  }

  Future<UserModel> _loginWithBrowserGoogle({
    String? role,
    String? specialty,
  }) async {
    final completer = Completer<UserModel>();
    late final StreamSubscription<AuthState> subscription;

    subscription = _client.auth.onAuthStateChange.listen((event) async {
      final user = event.session?.user;
      if (user == null || completer.isCompleted) return;
      try {
        completer.complete(
          await _ensureProfile(
            user,
            role: role,
            specialty: specialty,
          ),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _googleRedirectTo,
      );
      if (!launched) {
        throw const core_exceptions.AuthException(
          message: 'No se pudo abrir Google para iniciar sesion.',
        );
      }

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw const core_exceptions.AuthException(
            message: 'No se completo el inicio con Google. Intenta nuevamente.',
          );
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  String? _metadataString(User supabaseUser, List<String> keys) {
    final meta = supabaseUser.userMetadata ?? {};
    for (final key in keys) {
      final value = meta[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _isGoogleUser(User supabaseUser) {
    final provider = supabaseUser.appMetadata['provider']?.toString();
    if (provider == 'google') return true;
    final providers = supabaseUser.appMetadata['providers'];
    return providers is List && providers.contains('google');
  }

  Future<void> _syncGoogleProfileMetadata(
    User supabaseUser, {
    String? role,
  }) async {
    if (!_isGoogleUser(supabaseUser)) return;

    final email = supabaseUser.email ?? '';
    final emailName = email.contains('@') ? email.split('@').first : email;
    final displayName = _metadataString(supabaseUser, const [
      'nombre',
      'full_name',
      'name',
    ]);
    final avatarUrl = _metadataString(supabaseUser, const [
      'avatar_url',
      'picture',
    ]);
    final profileRole = role == AppConstants.roleTechnician
        ? AppConstants.roleDriver
        : role ?? AppConstants.roleDriver;

    final existing = await _client
        .from(AppConstants.tableProfiles)
        .select('nombre, avatar_url')
        .eq('id', supabaseUser.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from(AppConstants.tableProfiles).upsert({
        'id': supabaseUser.id,
        'email': email,
        'nombre': displayName ?? emailName,
        'telefono': '',
        'rol': profileRole,
        'activo': true,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'creado_en': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      return;
    }

    final currentName = existing['nombre']?.toString().trim() ?? '';
    final currentAvatar = existing['avatar_url']?.toString().trim() ?? '';
    final updates = <String, dynamic>{'email': email};
    if (displayName != null &&
        (currentName.isEmpty || currentName == emailName)) {
      updates['nombre'] = displayName;
    }
    if (avatarUrl != null && currentAvatar.isEmpty) {
      updates['avatar_url'] = avatarUrl;
    }
    if (updates.length > 1 || updates['email'] != null) {
      await _client
          .from(AppConstants.tableProfiles)
          .update(updates)
          .eq('id', supabaseUser.id);
    }
  }

  Future<void> _ensureTechnicianApplication({
    required String userId,
    String? specialty,
  }) async {
    final normalizedSpecialty = _normalizeSpecialtyCode(specialty) ??
        TechnicianSpecialties.generalAssistance;
    final existing = await _client
        .from(AppConstants.tableTecnicos)
        .select('id, estado_verificacion')
        .eq('usuario_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _client.from(AppConstants.tableTecnicos).insert({
        'usuario_id': userId,
        'especialidad': normalizedSpecialty,
        'estado_verificacion': AppConstants.verificationPending,
        'disponible': false,
        'motivo_rechazo': null,
      });
      return;
    }

    final status = existing['estado_verificacion']?.toString();
    if (status != AppConstants.verificationApproved) {
      await _client.from(AppConstants.tableTecnicos).update({
        'especialidad': normalizedSpecialty,
        'estado_verificacion': AppConstants.verificationPending,
        'disponible': false,
        'motivo_rechazo': null,
      }).eq('usuario_id', userId);

      await _client
          .from(AppConstants.tableProfiles)
          .update({'rol': AppConstants.roleDriver}).eq('id', userId);
    }
  }

  /// Fetches the profile row. If it doesn't exist (e.g. first OAuth login and
  /// the DB trigger hasn't run), it creates the row from auth user metadata
  /// so the app never treats an authenticated user as unauthenticated.
  Future<UserModel> _ensureProfile(
    User supabaseUser, {
    String? role,
    String? specialty,
  }) async {
    await _syncGoogleProfileMetadata(supabaseUser, role: role);
    if (role == AppConstants.roleTechnician) {
      await _ensureTechnicianApplication(
        userId: supabaseUser.id,
        specialty: specialty,
      );
    }
    try {
      return await _fetchProfile(supabaseUser.id);
    } on PostgrestException {
      final email = supabaseUser.email ?? '';
      final avatarUrl = _metadataString(
        supabaseUser,
        const ['avatar_url', 'picture'],
      );
      await _client.from(AppConstants.tableProfiles).upsert({
        'id': supabaseUser.id,
        'email': email,
        'nombre': _metadataString(supabaseUser, const [
              'nombre',
              'full_name',
              'name',
            ]) ??
            (email.contains('@') ? email.split('@').first : email),
        'telefono': '',
        'rol': AppConstants.roleDriver,
        'activo': true,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'creado_en': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      return _fetchProfile(supabaseUser.id);
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
      'specialty': TechnicianSpecialties.normalizeCode(specialty) ?? specialty,
      'lat': lat,
      'lng': lng,
      'created_at':
          data['creado_en']?.toString() ?? DateTime.now().toIso8601String(),
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
        'account_disabled_reason': data['account_disabled_reason'] as String?,
        'preferred_payment_method':
            data['preferred_payment_method'] as String?,
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
          'especialidad': _normalizeSpecialtyCode(specialty) ??
              TechnicianSpecialties.generalAssistance,
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
        specialty: _normalizeSpecialtyCode(specialty) ?? specialty,
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
    } on PlatformException catch (e) {
      final details = '${e.code} ${e.message} ${e.details}'.toLowerCase();
      if (details.contains('sign_in_failed') &&
          (details.contains('apiexception: 10') ||
              details.contains('developer_error'))) {
        throw const core_exceptions.AuthException(
          message:
              'Google rechazó la configuración Android. Verifica el paquete, la huella SHA-1 y que los clientes Android y Web pertenezcan al mismo proyecto de Google Cloud.',
        );
      }
      throw core_exceptions.AuthException(
        message: e.message ?? 'No se pudo iniciar sesión con Google.',
      );
    } catch (e) {
      if (_looksLikeNetworkError(e)) throw _networkException();
      throw core_exceptions.ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> loginWithGoogle({
    String? role,
    String? specialty,
  }) async {
    try {
      final existingUser = _client.auth.currentUser;
      if (existingUser != null) {
        return _ensureProfile(
          existingUser,
          role: role,
          specialty: specialty,
        );
      }

      if (_usesNativeGoogleSignIn) {
        return _loginWithNativeGoogle(role: role, specialty: specialty);
      }
      return _loginWithBrowserGoogle(role: role, specialty: specialty);
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
    if (_usesNativeGoogleSignIn) {
      try {
        await _buildGoogleSignIn().signOut();
      } catch (_) {
        // Supabase logout must still complete if Google session cleanup fails.
      }
    }
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
        message: 'No se pudo enviar el correo de recuperación',
      );
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
        'telefono': user.phone,
        'avatar_url': user.avatarUrl,
        'preferred_payment_method': user.preferredPaymentMethod,
      }).eq('id', user.id);

      if (user.role == AppConstants.roleTechnician && user.specialty != null) {
        await _client.from(AppConstants.tableTecnicos).update({
          'especialidad': _normalizeSpecialtyCode(user.specialty) ??
              TechnicianSpecialties.generalAssistance,
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
        preferredPaymentMethod: fresh.preferredPaymentMethod,
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
