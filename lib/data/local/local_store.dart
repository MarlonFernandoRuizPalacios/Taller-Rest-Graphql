import 'dart:collection';

/// Almacen local en memoria para funcionar sin servidores.
/// Guarda detecciones y asistencias; expone helpers para estadísticas.
class LocalStore {
  LocalStore._();
  static final LocalStore I = LocalStore._();

  // detecciones por pacienteId
  final Map<int, List<Map<String, dynamic>>> _detections = {};
  // asistencias por pacienteId
  final Map<int, List<Map<String, dynamic>>> _attendances = {};

  UnmodifiableListView<Map<String, dynamic>> detectionsOf(int patientId) {
    return UnmodifiableListView(_detections[patientId] ?? const []);
  }

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

  UnmodifiableListView<Map<String, dynamic>> attendancesOf(int patientId) {
    return UnmodifiableListView(_attendances[patientId] ?? const []);
  }

  // ---------- Cálculo de severidad local ----------
  static const Map<String, int> conditionWeights = {
    "I10": 15, // Hipertensión
    "E11": 20, // Diabetes tipo 2
    "J44": 25, // EPOC
    "I25": 25, // Cardiopatía isquémica
    "C34": 35, // Cáncer pulmón (antecedente)
    "N18": 30, // Enfermedad renal crónica
    "Z88": 5, // Alergia penicilina
    "F32": 10, // Depresión
    "J45": 10, // Asma
    "E66": 10, // Obesidad
  };

  Map<String, dynamic> severityFor(Map<String, dynamic> patient) {
    int score = 0;
    final int age = (patient['age'] ?? 0) as int;
    if (age >= 80)
      score += 25;
    else if (age >= 65)
      score += 15;

    final Set<String> conds = {
      ...(patient['comorbidities'] as List? ?? const <String>[]),
    };

    // + detecciones locales
    for (final d in detectionsOf(patient['id'] as int)) {
      conds.add((d['code'] ?? '').toString());
    }
    for (final c in conds) {
      score += conditionWeights[c] ?? 5;
    }

    // ausencia reciente aumenta levemente
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

  // Histograma de condiciones (comorbilidades + detecciones locales)
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

  // Distribución por nivel de severidad
  List<Map<String, dynamic>> severityDistribution(
    List<Map<String, dynamic>> patients,
  ) {
    int baja = 0, mod = 0, cri = 0;
    for (final p in patients) {
      final s = severityFor(p);
      switch (s['level']) {
        case 'Crítica':
          cri++;
          break;
        case 'Moderada':
          mod++;
          break;
        default:
          baja++;
      }
    }
    return [
      {'level': 'Baja', 'count': baja},
      {'level': 'Moderada', 'count': mod},
      {'level': 'Crítica', 'count': cri},
    ];
  }

  // Ordena pacientes por score desc y pagina
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
    final sliced = withScore
        .skip(offset)
        .take(limit)
        .map((e) => e['p'] as Map<String, dynamic>)
        .toList();
    return sliced;
  }
}
