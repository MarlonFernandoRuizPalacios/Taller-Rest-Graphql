import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

class PatientsApi {
  static List<Map<String, dynamic>>? _cache;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://randomuser.me',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<List<Map<String, dynamic>>> list() async {
    if (_cache != null) return _cache!;
    try {
      final r = await _dio.get(
        '/api/',
        queryParameters: {'results': 20, 'nat': 'us,gb,es,mx,br,co'},
      );
      final results = (r.data['results'] as List).cast<Map<String, dynamic>>();
      final rnd = Random();
      int id = 1;
      final mapped = results.map((u) {
        final name = '${uc(u['name']['first'])} ${uc(u['name']['last'])}';
        final doc = randomDigits(rnd, 10);
        final gender =
            (u['gender'] ?? '').toString().toLowerCase().startsWith('f')
            ? 'F'
            : 'M';
        final phone = (u['cell'] ?? u['phone'] ?? '').toString();
        final emerg = phone.replaceAll(RegExp(r'[^0-9]'), '') + '9';
        final loc = u['location'];
        final street = loc?['street'];
        final addr =
            '${street?['name'] ?? 'Calle'} ${street?['number'] ?? ''}, '
            '${loc?['city'] ?? ''}, ${loc?['state'] ?? ''}';
        final age = (u['dob']?['age'] ?? 30) as int;
        final all = [
          'I10',
          'E11',
          'J44',
          'I25',
          'C34',
          'N18',
          'Z88',
          'F32',
          'J45',
          'E66',
        ];
        final k = rnd.nextInt(3);
        final com = List.generate(k, (_) => all[rnd.nextInt(all.length)]);
        return {
          'id': id++,
          'name': name,
          'documentId': doc,
          'age': age,
          'sex': gender,
          'phone': phone,
          'emergencyContact': emerg,
          'address': addr,
          'comorbidities': com,
          'nat': (u['nat'] ?? '').toString().toUpperCase(), // ej 'US','ES','CO'
        };
      }).toList();
      _cache = mapped;
      return _cache!;
    } catch (_) {
      // Fallback: asset local
      final raw = await rootBundle.loadString('assets/patients.txt');
      final data = jsonDecode(raw) as List;
      _cache = data.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['nat'] ??= 'CO';
        return m;
      }).toList();
      return _cache!;
    }
  }

  // Solo lectura (requisito: API pública)
  Future<Map<String, dynamic>> create(Map<String, dynamic> _) async =>
      throw UnsupportedError(
        'Creación deshabilitada (solo lectura desde API pública)',
      );
  Future<void> update(int id, Map<String, dynamic> _) async =>
      throw UnsupportedError(
        'Edición deshabilitada (solo lectura desde API pública)',
      );
  Future<void> remove(int id) async => throw UnsupportedError(
    'Eliminación deshabilitada (solo lectura desde API pública)',
  );
}

/* helpers */
String uc(String s) => s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
String randomDigits(Random rnd, int len) {
  const d = '0123456789';
  return List.generate(len, (_) => d[rnd.nextInt(10)]).join();
}
