import 'package:flutter/material.dart';
import '../../data/rest/patients_api.dart';
import '../../data/rest/attendances_api.dart';
import '../widgets/patient_tile.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _patientsApi = PatientsApi();
  final _attApi = AttendancesApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await _patientsApi.list();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _checkIn(Map<String, dynamic> p, bool present) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(present ? 'Marcado Presente' : 'Marcado Ausente')),
    );
    await _attApi.checkIn(p['id'] as int, present);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_items.isEmpty) return const Center(child: Text('Sin pacientes'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final p = _items[i];
          return PatientTile(
            patient: p,
            onPresent: () => _checkIn(p, true),
            onAbsent: () => _checkIn(p, false),
          );
        },
      ),
    );
  }
}
