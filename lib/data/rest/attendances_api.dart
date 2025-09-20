import 'package:dio/dio.dart';
import '../../config/rest_client.dart';

class AttendancesApi {
  Future<void> checkIn(int patientId, bool present) async {
    try {
      await rest.post(
        '/attendances',
        data: {
          'patientId': patientId,
          'date': DateTime.now().toIso8601String(),
          'present': present,
        },
      );
    } on DioException catch (e) {
      throw Exception('Error check-in: ${e.message}');
    }
  }
}
