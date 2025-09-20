import '../local/local_store.dart';

class DetectionsApi {
  Future<List<Map<String, dynamic>>> byPatient(int patientId) async {
    return LocalStore.I.detectionsOf(patientId);
  }

  Future<Map<String, dynamic>> add({
    required int patientId,
    required String code,
    required String name,
    String? note,
  }) async {
    LocalStore.I.addDetection(
      patientId: patientId,
      code: code,
      name: name,
      note: note,
    );
    return Map<String, dynamic>.from(
      LocalStore.I.detectionsOf(patientId).first,
    );
  }
}
