import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Error del servidor']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión a internet']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Error de autenticación']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso no encontrado']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Sin permiso para esta acción']);
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'No se pudo obtener la ubicación']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Datos inválidos']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Error de almacenamiento local']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Error desconocido']);
}
