import 'package:dio/dio.dart';
import '../../config/rest_client.dart';
import '../local/local_store.dart';

class DetectionsApi {
  Future<List<Map<String, dynamic>>> byPatient(int patientId) async {
    try {
      final r = await rest.get(
        '/detections',
        queryParameters: {'patientId': patientId},
      );
      return (r.data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // 🔁 Fallback local
      return LocalStore.I.detectionsOf(patientId);
    }
  }

  Future<Map<String, dynamic>> add({
    required int patientId,
    required String code,
    required String name,
    String? note,
  }) async {
    try {
      final r = await rest.post(
        '/detections',
        data: {
          'patientId': patientId,
          'code': code,
          'name': name,
          'detectedAt': DateTime.now().toIso8601String(),
          'note': note,
        },
      );
      return r.data;
    } on DioException catch (_) {
      // 🔁 Sin backend: guarda en memoria
      LocalStore.I.addDetection(
        patientId: patientId,
        code: code,
        name: name,
        note: note,
      );
      // devolvemos el último insertado
      final last = LocalStore.I.detectionsOf(patientId).first;
      return Map<String, dynamic>.from(last);
    }
  }
}
