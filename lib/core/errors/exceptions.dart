class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException({this.message = 'Error del servidor', this.statusCode});
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'Sin conexión a internet'});
}

class AuthException implements Exception {
  final String message;
  const AuthException({this.message = 'Error de autenticación'});
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException({this.message = 'Recurso no encontrado'});
}

class PermissionException implements Exception {
  final String message;
  const PermissionException({this.message = 'Sin permiso'});
}

class LocationException implements Exception {
  final String message;
  const LocationException({this.message = 'No se pudo obtener la ubicación'});
}

class CacheException implements Exception {
  final String message;
  const CacheException({this.message = 'Error de almacenamiento'});
}
