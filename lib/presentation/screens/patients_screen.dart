import 'package:flutter/material.dart';
import '../../data/rest/patients_api.dart';
import '../../data/rest/attendances_api.dart';
import '../widgets/patient_tile.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  static _PatientsScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<_PatientsScreenState>();

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

  void createPatient() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PatientDialog(),
    );
    if (data != null) {
      try {
        final created = await _patientsApi.create(data);
        // ✅ Inserta en memoria para verlo al instante (sirve con o sin backend)
        setState(() => _items.insert(0, created));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _edit(Map<String, dynamic> p) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PatientDialog(initial: p),
    );
    if (data != null) {
      try {
        await _patientsApi.update(p['id'] as int, data);
        final idx = _items.indexWhere((e) => e['id'] == p['id']);
        if (idx != -1) {
          setState(() => _items[idx] = {..._items[idx], ...data});
        }
      } catch (e) {
        // ✅ Si no hay backend, actualiza local para no bloquear entrega
        final idx = _items.indexWhere((e) => e['id'] == p['id']);
        if (idx != -1) {
          setState(() => _items[idx] = {..._items[idx], ...data});
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Actualizado localmente: $e')));
      }
    }
  }

  void _remove(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar paciente'),
        content: Text('¿Eliminar a ${p['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _patientsApi.remove(p['id'] as int);
        setState(() => _items.removeWhere((e) => e['id'] == p['id']));
      } catch (e) {
        // ✅ Sin backend: elimina localmente
        setState(() => _items.removeWhere((e) => e['id'] == p['id']));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Eliminado localmente: $e')));
      }
    }
  }

  Future<void> _checkIn(Map<String, dynamic> p, bool present) async {
    // Optimistic UI: mensaje inmediato
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(present ? 'Marcado Presente' : 'Marcado Ausente')),
    );
    try {
      await _attApi.checkIn(p['id'] as int, present);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error check-in: $e')));
    }
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
            onEdit: () => _edit(p),
            onDelete: () => _remove(p),
          );
        },
      ),
    );
  }
}

class _PatientDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _PatientDialog({this.initial});
  @override
  State<_PatientDialog> createState() => _PatientDialogState();
}

class _PatientDialogState extends State<_PatientDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name, doc, phone, emerg, addr, age;
  String sex = 'F';

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?['name']);
    doc = TextEditingController(text: widget.initial?['documentId']);
    phone = TextEditingController(text: widget.initial?['phone']);
    emerg = TextEditingController(text: widget.initial?['emergencyContact']);
    addr = TextEditingController(text: widget.initial?['address']);
    age = TextEditingController(text: widget.initial?['age']?.toString());
    sex = widget.initial?['sex'] ?? 'F';
  }

  @override
  void dispose() {
    name.dispose();
    doc.dispose();
    phone.dispose();
    emerg.dispose();
    addr.dispose();
    age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nuevo paciente' : 'Editar paciente',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: doc,
                decoration: const InputDecoration(labelText: 'Documento'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: age,
                      decoration: const InputDecoration(labelText: 'Edad'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < 0) ? 'Inválida' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: sex,
                      items: const [
                        DropdownMenuItem(value: 'F', child: Text('F')),
                        DropdownMenuItem(value: 'M', child: Text('M')),
                      ],
                      onChanged: (v) => setState(() => sex = v ?? 'F'),
                      decoration: const InputDecoration(labelText: 'Sexo'),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextFormField(
                controller: emerg,
                decoration: const InputDecoration(
                  labelText: 'Contacto de emergencia',
                ),
              ),
              TextFormField(
                controller: addr,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, {
                'name': name.text.trim(),
                'documentId': doc.text.trim(),
                'age': int.parse(age.text.trim()),
                'sex': sex,
                'phone': phone.text.trim(),
                'emergencyContact': emerg.text.trim(),
                'address': addr.text.trim(),
                'comorbidities': <String>[],
              });
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
