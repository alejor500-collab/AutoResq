class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException({this.message = 'Error del servidor', this.statusCode});

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'Sin conexión a internet'});

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  const AuthException({this.message = 'Error de autenticación'});

  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException({this.message = 'Recurso no encontrado'});

  @override
  String toString() => message;
}

class PermissionException implements Exception {
  final String message;
  const PermissionException({this.message = 'Sin permiso'});

  @override
  String toString() => message;
}

class LocationException implements Exception {
  final String message;
  const LocationException({this.message = 'No se pudo obtener la ubicación'});

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;
  const CacheException({this.message = 'Error de almacenamiento'});

  @override
  String toString() => message;
}
