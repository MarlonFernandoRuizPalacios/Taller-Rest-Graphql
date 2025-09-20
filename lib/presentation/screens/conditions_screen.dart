import 'package:flutter/material.dart';
import '../../data/rest/patients_api.dart';
import '../../data/rest/detections_api.dart';

class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key});
  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  final _patientsApi = PatientsApi();
  final _detApi = DetectionsApi();
  List<Map<String, dynamic>> patients = [];
  Map<int, List<Map<String, dynamic>>> cache = {};
  bool loading = true;
  String? error;
  int? selectedId;

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      patients = await _patientsApi.list();
      selectedId = patients.isNotEmpty ? patients.first['id'] as int : null;
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => loading = false);
    }
    if (selectedId != null) _loadDetections(selectedId!);
  }

  Future<void> _loadDetections(int pid) async {
    final list = await _detApi.byPatient(pid);
    setState(() => cache[pid] = list);
  }

  Future<void> _addDetection(int pid) async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _DetectionDialog(),
    );
    if (data != null) {
      try {
        await _detApi.add(
          patientId: pid,
          code: data['code']!,
          name: data['name']!,
          note: data['note'],
        );
        await _loadDetections(pid);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text('Error: $error'));
    if (patients.isEmpty) return const Center(child: Text('Sin pacientes'));

    final pid = selectedId!;
    final dets = cache[pid] ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: pid,
                  isExpanded: true,
                  items: [
                    for (final p in patients)
                      DropdownMenuItem(
                        value: p['id'] as int,
                        child: Text(p['name']),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => selectedId = v);
                      _loadDetections(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _addDetection(pid),
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: dets.isEmpty
              ? const Center(child: Text('Sin detecciones'))
              : ListView.separated(
                  itemCount: dets.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final d = dets[i];
                    return ListTile(
                      title: Text('${d['code']} – ${d['name']}'),
                      subtitle: Text(
                        'Detectado: ${d['detectedAt']}\n${d['note'] ?? ''}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DetectionDialog extends StatefulWidget {
  const _DetectionDialog();
  @override
  State<_DetectionDialog> createState() => _DetectionDialogState();
}

class _DetectionDialogState extends State<_DetectionDialog> {
  final _form = GlobalKey<FormState>();
  final code = TextEditingController();
  final name = TextEditingController();
  final note = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva detección'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: code,
              decoration: const InputDecoration(
                labelText: 'Código (ICD-10 p. ej. I10)',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextFormField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Nota'),
            ),
          ],
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
                'code': code.text.trim(),
                'name': name.text.trim().isEmpty
                    ? code.text.trim()
                    : name.text.trim(),
                'note': note.text.trim(),
              });
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
