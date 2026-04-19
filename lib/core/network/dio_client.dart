import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;

  DioClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Log request in debug
          // debugPrint('→ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // debugPrint('← ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  factory DioClient() {
    _instance ??= DioClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  // ─── OpenAI ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> analyzeEmergency(String problem) async {
    try {
      final response = await _dio.post(
        '${AppConstants.openAiBaseUrl}/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
          },
        ),
        data: {
          'model': AppConstants.openAiModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Eres un experto en mecánica automotriz. Clasifica el problema y responde SOLO con JSON válido.',
            },
            {
              'role': 'user',
              'content':
                  'Clasifica este problema automotriz como Mecánica, Eléctrica u Otro. '
                  'Responde solo JSON: {"tipo": "...", "sugerencia": "...", "descripcion_breve": "..."}. '
                  'Problema: $problem',
            },
          ],
          'max_tokens': 200,
          'temperature': 0.3,
        },
      );

      final content =
          response.data['choices'][0]['message']['content'] as String;
      // Extract JSON from response
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}') + 1;
      if (jsonStart == -1 || jsonEnd == 0) {
        throw const ServerException(message: 'Respuesta de IA inválida');
      }
      final jsonStr = content.substring(jsonStart, jsonEnd);
      // Parse manually to avoid import of dart:convert here
      return _parseSimpleJson(jsonStr);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException(message: 'Tiempo de espera agotado');
      }
      throw ServerException(
        message: e.message ?? 'Error al analizar con IA',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Nominatim (reverse geocoding) ────────────────────────────────────────
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        '${AppConstants.nominatimUrl}/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'jsonv2',
          'accept-language': 'es',
        },
        options: Options(
          headers: {
            'User-Agent': 'AutoResQ/1.0 (autoresq@example.com)',
          },
        ),
      );
      final data = response.data as Map<String, dynamic>;
      return data['display_name'] as String? ?? 'Ubicación desconocida';
    } catch (_) {
      return 'Riobamba, Ecuador';
    }
  }

  /// Minimal JSON parser for {"key": "value"} structures
  Map<String, dynamic> _parseSimpleJson(String json) {
    final result = <String, dynamic>{};
    final cleaned = json.replaceAll('{', '').replaceAll('}', '');
    final pairs = cleaned.split(',');
    for (final pair in pairs) {
      final colonIdx = pair.indexOf(':');
      if (colonIdx == -1) continue;
      var key = pair.substring(0, colonIdx).trim().replaceAll('"', '');
      var value = pair.substring(colonIdx + 1).trim().replaceAll('"', '');
      result[key] = value;
    }
    return result;
  }
}
