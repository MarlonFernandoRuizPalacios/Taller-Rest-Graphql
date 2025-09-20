import 'package:flutter/material.dart';

class PatientTile extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback? onPresent;
  final VoidCallback? onAbsent;

  const PatientTile({
    super.key,
    required this.patient,
    this.onPresent,
    this.onAbsent,
  });

  @override
  Widget build(BuildContext context) {
    final title = patient['name'] ?? '';
    final subtitle = '${patient['documentId']}  •  ${patient['phone'] ?? ''}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: onPresent,
              tooltip: 'Presente',
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: onAbsent,
              tooltip: 'Ausente',
            ),
          ],
        ),
      ),
    );
  }
}
