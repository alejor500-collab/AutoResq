import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, AppUser>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? specialty,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> sendPasswordReset(String email);

  Future<Either<Failure, AppUser?>> getCurrentUser();

  Future<Either<Failure, AppUser>> updateProfile(AppUser user);

  Stream<AppUser?> get authStateChanges;
}
