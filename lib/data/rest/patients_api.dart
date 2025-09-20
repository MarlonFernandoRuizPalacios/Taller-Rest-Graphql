import 'dart:math';
import 'package:dio/dio.dart';
import '../../config/rest_client.dart';

class PatientsApi {
  /// Lista de pacientes (si el backend no está disponible, usa fallback local)
  Future<List<Map<String, dynamic>>> list() async {
    try {
      final r = await rest.get('/patients');
      return (r.data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return _fallbackPatients();
    }
  }

  /// Crear paciente
  /// - Si el POST falla (no hay JSON Server), simula creación local y devuelve el mapa.
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    try {
      final r = await rest.post('/patients', data: body);
      return r.data;
    } on DioException catch (_) {
      final map = Map<String, dynamic>.from(body);
      map['id'] = DateTime.now().millisecondsSinceEpoch; // id temporal
      return map;
    }
  }

  /// Actualizar paciente
  Future<void> update(int id, Map<String, dynamic> body) async {
    await rest.patch('/patients/$id', data: body);
  }

  /// Eliminar paciente
  Future<void> remove(int id) async {
    await rest.delete('/patients/$id');
  }
}

/* ----------------- Fallback local (sin backend) ----------------- */

String _randomDigits(Random rnd, int len) {
  const d = '0123456789';
  return List.generate(len, (_) => d[rnd.nextInt(10)]).join();
}

String _randomPhone(Random rnd) =>
    '3${rnd.nextInt(10)}${rnd.nextInt(10)}${10000000 + rnd.nextInt(90000000)}';

List<Map<String, dynamic>> _fallbackPatients() {
  final rnd = Random(42);
  const names = [
    'Camila',
    'Juan',
    'María',
    'Andrés',
    'Valentina',
    'Santiago',
    'Daniela',
    'Carlos',
    'Laura',
    'Felipe',
    'Diana',
    'Sebastián',
  ];
  const last = [
    'García',
    'Martínez',
    'Rodríguez',
    'López',
    'González',
    'Hernández',
    'Pérez',
    'Ramírez',
    'Torres',
    'Sánchez',
    'Castro',
    'Romero',
  ];

  return List.generate(10, (i) {
    final name =
        '${names[rnd.nextInt(names.length)]} ${names[rnd.nextInt(names.length)]} ${last[rnd.nextInt(last.length)]}';
    return {
      'id': i + 1,
      'name': name,
      // ✅ ahora es string de 10 dígitos; evita RangeError de nextInt grande
      'documentId': _randomDigits(rnd, 10),
      'age': 18 + rnd.nextInt(70),
      'sex': rnd.nextBool() ? 'F' : 'M',
      'phone': _randomPhone(rnd),
      'emergencyContact': _randomPhone(rnd),
      'address':
          'Calle ${1 + rnd.nextInt(120)} # ${1 + rnd.nextInt(100)}-${1 + rnd.nextInt(50)}, Barrio Centro, Pasto',
      'comorbidities': <String>[],
    };
  });
}
