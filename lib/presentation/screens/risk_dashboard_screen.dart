// lib/presentation/screens/risk_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../config/gql_client.dart';
import '../../data/gql/countries_queries.dart';
import '../../data/rest/patients_api.dart';
import '../../data/local/local_store.dart';

class RiskDashboardScreen extends StatefulWidget {
  const RiskDashboardScreen({super.key});
  @override
  State<RiskDashboardScreen> createState() => _RiskDashboardScreenState();
}

class _RiskDashboardScreenState extends State<RiskDashboardScreen> {
  final _patientsApi = PatientsApi();
  List<Map<String, dynamic>> _patients = [];
  bool offline = false;
  int limit = 8;

  // 👇 TIPADO CORRECTO
  List<Map<String, dynamic>> crit = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    _patients = await _patientsApi.list();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_patients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (offline) {
      // ---------- MODO LOCAL ----------
      final dist = LocalStore.I.severityDistribution(_patients);
      final hist = LocalStore.I.conditionsHistogram(_patients);
      final List<Map<String, dynamic>> critical = LocalStore.I.criticalPatients(
        _patients,
        limit: limit,
        offset: 0,
      );

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _TopStats(
              loading: false,
              dist: dist,
              hist: hist,
              onRefresh: _loadPatients,
            ),
            const SizedBox(height: 12),
            _CriticalListLocal(
              patients: crit.isEmpty ? critical : crit,
              onMore: () {
                final start = (crit.isEmpty ? critical.length : crit.length);
                final more = LocalStore.I.criticalPatients(
                  _patients,
                  offset: start,
                  limit: limit,
                );
                setState(() {
                  if (crit.isEmpty) crit = critical;
                  crit.addAll(more);
                });
              },
              onRefresh: () {
                setState(() => crit.clear());
                _loadPatients();
              },
            ),
          ],
        ),
      );
    }

    // ------------ GQL público (Countries) ------------
    final codes = _patients
        .map((p) => (p['nat'] ?? '').toString().toUpperCase())
        .where((c) => c.length == 2)
        .toSet()
        .toList();

    return GraphQLProvider(
      client: gqlClient,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Query(
              options: QueryOptions(
                document: gql(countriesByCodesQuery),
                variables: {'codes': codes},
                fetchPolicy: FetchPolicy.networkOnly,
              ),
              builder: (result, {refetch, fetchMore}) {
                if (result.isLoading) {
                  return const _TopStats(loading: true);
                }
                if (result.hasException) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => offline = true);
                  });
                  return const SizedBox.shrink();
                }

                final countries = (result.data?['countries'] as List? ?? []);
                final Map<String, String> codeToContinent = {
                  for (final c in countries)
                    (c['code'] as String):
                        (c['continent']?['name'] ?? 'Desconocido') as String,
                };
                final Map<String, int> byContinent = {};
                for (final p in _patients) {
                  final nat = (p['nat'] ?? '').toString().toUpperCase();
                  final cont = codeToContinent[nat] ?? 'Desconocido';
                  byContinent.update(cont, (v) => v + 1, ifAbsent: () => 1);
                }
                final distContinents = byContinent.entries
                    .map((e) => {'level': e.key, 'count': e.value})
                    .toList();

                final hist = LocalStore.I.conditionsHistogram(_patients);

                return _TopStats(
                  loading: false,
                  dist: distContinents,
                  hist: hist,
                  onRefresh: () => refetch?.call(),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Builder(
                builder: (_) {
                  final List<Map<String, dynamic>> initial = LocalStore.I
                      .criticalPatients(_patients, limit: limit, offset: 0);
                  final List<Map<String, dynamic>> data = crit.isEmpty
                      ? initial
                      : crit;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pacientes críticos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  setState(() => crit.clear());
                                },
                                child: const Text('Refrescar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () {
                                  final more = LocalStore.I.criticalPatients(
                                    _patients,
                                    offset: data.length,
                                    limit: limit,
                                  );
                                  setState(() => crit = [...data, ...more]);
                                },
                                child: const Text('Cargar más'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (_, i) {
                            final p = data[i];
                            final s = LocalStore.I.severityFor(p);
                            return ListTile(
                              title: Text(p['name'] ?? ''),
                              subtitle: Text(
                                'Nivel: ${s['level']}  •  País: ${(p['nat'] ?? '').toString().toUpperCase()}',
                              ),
                              trailing: Text('Score: ${s['score']}'),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopStats extends StatelessWidget {
  final bool loading;
  final List? dist;
  final List? hist;
  final VoidCallback? onRefresh;
  const _TopStats({
    required this.loading,
    this.dist,
    this.hist,
    this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(
        children: const [
          Expanded(
            child: _Card(child: Center(child: CircularProgressIndicator())),
          ),
          Expanded(child: _Card(child: SizedBox(height: 56))),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pacientes por continente (GraphQL)'),
                const SizedBox(height: 6),
                for (final b in dist ?? [])
                  Text('${b['level']}: ${b['count']}'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Condiciones (local)'),
                    IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final c in hist ?? []) Text('${c['code']}: ${c['count']}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Padding(padding: const EdgeInsets.all(12.0), child: child),
    );
  }
}

class _CriticalListLocal extends StatelessWidget {
  final List<Map<String, dynamic>> patients;
  final VoidCallback onMore;
  final VoidCallback onRefresh;
  const _CriticalListLocal({
    required this.patients,
    required this.onMore,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pacientes críticos (local)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: onRefresh,
                    child: const Text('Refrescar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onMore,
                    child: const Text('Cargar más'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: patients.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final p = patients[i];
                final s = LocalStore.I.severityFor(p);
                return ListTile(
                  title: Text(p['name'] ?? ''),
                  subtitle: Text(
                    'Nivel: ${s['level']}  •  País: ${(p['nat'] ?? '').toString().toUpperCase()}',
                  ),
                  trailing: Text('Score: ${s['score']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
