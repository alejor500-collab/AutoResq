import 'package:autoresq/features/emergency/data/models/emergency_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmergencyModel assignment selection', () {
    test('does not expose a technician after the assignment is rejected', () {
      final emergency = EmergencyModel.fromJson({
        'id': 'emergency-1',
        'usuario_id': 'driver-1',
        'descripcion': 'Vehiculo detenido',
        'estado': 'pendiente',
        'fecha': '2026-06-06T12:00:00.000Z',
        'asignaciones': [
          {
            'id': 'assignment-1',
            'tecnico_id': 'technician-1',
            'estado': 'rechazada',
            'fecha_asignacion': '2026-06-06T12:05:00.000Z',
            'tecnicos': {
              'id': 'technician-1',
              'usuario_id': 'technician-user-1',
              'especialidad': 'general_assistance',
              'usuarios': {
                'id': 'technician-user-1',
                'nombre': 'Tecnico cancelado',
              },
            },
          },
        ],
      });

      expect(emergency.estado, 'pendiente');
      expect(emergency.hasTechnician, isFalse);
      expect(emergency.tecnicoId, isNull);
      expect(emergency.asignacionEstado, isNull);
    });

    test('keeps exposing an active technician', () {
      final emergency = EmergencyModel.fromJson({
        'id': 'emergency-2',
        'usuario_id': 'driver-1',
        'descripcion': 'Problema electrico',
        'estado': 'en_proceso',
        'fecha': '2026-06-06T12:00:00.000Z',
        'asignaciones': [
          {
            'id': 'assignment-2',
            'tecnico_id': 'technician-2',
            'estado': 'en_ruta',
            'fecha_asignacion': '2026-06-06T12:05:00.000Z',
          },
        ],
      });

      expect(emergency.hasTechnician, isTrue);
      expect(emergency.tecnicoId, 'technician-2');
      expect(emergency.asignacionEstado, 'en_ruta');
    });

    test('prefers a current assignment over an older rejected one', () {
      final emergency = EmergencyModel.fromJson({
        'id': 'emergency-3',
        'usuario_id': 'driver-1',
        'descripcion': 'Llanta averiada',
        'estado': 'en_proceso',
        'fecha': '2026-06-06T12:00:00.000Z',
        'asignaciones': [
          {
            'id': 'assignment-rejected',
            'tecnico_id': 'technician-old',
            'estado': 'rechazada',
            'fecha_asignacion': '2026-06-06T12:10:00.000Z',
          },
          {
            'id': 'assignment-active',
            'tecnico_id': 'technician-current',
            'estado': 'aceptada',
            'fecha_asignacion': '2026-06-06T12:15:00.000Z',
          },
        ],
      });

      expect(emergency.tecnicoId, 'technician-current');
      expect(emergency.asignacionEstado, 'aceptada');
    });
  });
}
