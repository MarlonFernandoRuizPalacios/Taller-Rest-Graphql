import 'dart:collection';

class LocalStore {
  LocalStore._();
  static final LocalStore I = LocalStore._();

  final Map<int, List<Map<String, dynamic>>> _detections = {};
  final Map<int, List<Map<String, dynamic>>> _attendances = {};

  UnmodifiableListView<Map<String, dynamic>> detectionsOf(int patientId) =>
      UnmodifiableListView(_detections[patientId] ?? const []);

  void addDetection({
    required int patientId,
    required String code,
    required String name,
    String? note,
  }) {
    final list = _detections.putIfAbsent(
      patientId,
      () => <Map<String, dynamic>>[],
    );
    list.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'patientId': patientId,
      'code': code,
      'name': name,
      'detectedAt': DateTime.now().toIso8601String(),
      'note': note,
    });
  }

  void addAttendance(int patientId, bool present) {
    final list = _attendances.putIfAbsent(
      patientId,
      () => <Map<String, dynamic>>[],
    );
    list.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'patientId': patientId,
      'date': DateTime.now().toIso8601String(),
      'present': present,
    });
  }

  UnmodifiableListView<Map<String, dynamic>> attendancesOf(int patientId) =>
      UnmodifiableListView(_attendances[patientId] ?? const []);

  static const Map<String, int> conditionWeights = {
    "I10": 15,
    "E11": 20,
    "J44": 25,
    "I25": 25,
    "C34": 35,
    "N18": 30,
    "Z88": 5,
    "F32": 10,
    "J45": 10,
    "E66": 10,
  };

  Map<String, dynamic> severityFor(Map<String, dynamic> patient) {
    int score = 0;
    final int age = (patient['age'] ?? 0) as int;
    if (age >= 80)
      score += 25;
    else if (age >= 65)
      score += 15;

    final conds = <String>{
      ...(patient['comorbidities'] as List? ?? const <String>[]),
    };
    for (final d in detectionsOf(patient['id'] as int)) {
      conds.add((d['code'] ?? '').toString());
    }
    for (final c in conds) {
      score += conditionWeights[c] ?? 5;
    }

    final att = attendancesOf(patient['id'] as int);
    if (att.isNotEmpty && att.first['present'] == false) score += 5;

    if (score > 100) score = 100;
    String level = "Baja";
    if (score >= 70)
      level = "Crítica";
    else if (score >= 40)
      level = "Moderada";
    return {'score': score, 'level': level};
  }

  List<Map<String, dynamic>> conditionsHistogram(
    List<Map<String, dynamic>> patients,
  ) {
    final Map<String, int> map = {};
    void add(String code) => map.update(code, (v) => v + 1, ifAbsent: () => 1);
    for (final p in patients) {
      for (final c in (p['comorbidities'] as List? ?? const [])) {
        add(c as String);
      }
      for (final d in detectionsOf(p['id'] as int)) {
        add(d['code'] as String);
      }
    }
    return map.entries.map((e) => {'code': e.key, 'count': e.value}).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  List<Map<String, dynamic>> severityDistribution(
    List<Map<String, dynamic>> patients,
  ) {
    int baja = 0, mod = 0, cri = 0;
    for (final p in patients) {
      final s = severityFor(p);
      if (s['level'] == 'Crítica')
        cri++;
      else if (s['level'] == 'Moderada')
        mod++;
      else
        baja++;
    }
    return [
      {'level': 'Baja', 'count': baja},
      {'level': 'Moderada', 'count': mod},
      {'level': 'Crítica', 'count': cri},
    ];
  }

  List<Map<String, dynamic>> criticalPatients(
    List<Map<String, dynamic>> patients, {
    int offset = 0,
    int limit = 10,
  }) {
    final withScore =
        patients
            .map((p) => {'p': p, 'score': severityFor(p)['score'] as int})
            .toList()
          ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return withScore
        .skip(offset)
        .take(limit)
        .map((e) => e['p'] as Map<String, dynamic>)
        .toList();
  }
}
