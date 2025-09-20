import '../local/local_store.dart';

class AttendancesApi {
  Future<void> checkIn(int patientId, bool present) async {
    LocalStore.I.addAttendance(patientId, present);
  }
}
