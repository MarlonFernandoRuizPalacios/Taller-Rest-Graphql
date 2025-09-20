import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../config/gql_client.dart';
import '../../data/gql/queries.dart';
import '../../data/rest/patients_api.dart';
import '../../data/local/local_store.dart';

class RiskDashboardScreen extends StatefulWidget {
  const RiskDashboardScreen({super.key});
  @override
  State<RiskDashboardScreen> createState() => _RiskDashboardScreenState();
}

class _RiskDashboardScreenState extends State<RiskDashboardScreen> {
  int limit = 8;
  List crit = [];
  bool offline = false; // si GQL falla, pasamos a modo local
  final _patientsApi = PatientsApi();
  List<Map<String, dynamic>> _patients = [];

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
    if (offline) {
      // ---------- MODO LOCAL ----------
      final dist = LocalStore.I.severityDistribution(_patients);
      final hist = LocalStore.I.conditionsHistogram(_patients);
      final critical = LocalStore.I.criticalPatients(
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
              patients: critical,
              onMore: () {
                final more = LocalStore.I.criticalPatients(
                  _patients,
                  offset: crit.length,
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

    // ---------- INTENTAR GQL; si falla → offline = true ----------
    return GraphQLProvider(
      client: gqlClient,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Query(
              options: QueryOptions(
                document: gql(distQuery),
                fetchPolicy: FetchPolicy.networkOnly,
              ),
              builder: (result, {refetch, fetchMore}) {
                if (result.isLoading) {
                  return const _TopStats(loading: true);
                }
                if (result.hasException) {
                  // Cambia a modo local
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => offline = true);
                  });
                  return const SizedBox.shrink();
                }
                final dist =
                    result.data?['severityDistribution'] as List? ?? [];
                final hist = result.data?['conditionsHistogram'] as List? ?? [];
                return _TopStats(
                  loading: false,
                  dist: dist,
                  hist: hist,
                  onRefresh: () => refetch?.call(),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Query(
                options: QueryOptions(
                  document: gql(criticalQuery),
                  variables: {'limit': limit, 'offset': 0},
                  fetchPolicy: FetchPolicy.networkOnly,
                ),
                builder: (res, {refetch, fetchMore}) {
                  if (res.isLoading && (res.data == null)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (res.hasException) {
                    // Cambia a modo local
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => offline = true);
                    });
                    return const SizedBox.shrink();
                  }
                  final first = (res.data?['criticalPatients'] as List?) ?? [];
                  final data = crit.isEmpty ? first : crit;

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
                                  refetch?.call();
                                },
                                child: const Text('Refrescar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () async {
                                  final fm = fetchMore;
                                  if (fm == null) return;
                                  final r = await fm(
                                    FetchMoreOptions(
                                      variables: {
                                        'limit': limit,
                                        'offset': data.length,
                                      },
                                      updateQuery: (prevData, newData) {
                                        final a = List.of(
                                          (prevData?['criticalPatients']
                                                  as List?) ??
                                              [],
                                        );
                                        final b =
                                            (newData?['criticalPatients']
                                                as List?) ??
                                            [];
                                        return {
                                          'criticalPatients': [...a, ...b],
                                        };
                                      },
                                    ),
                                  );
                                  setState(
                                    () => crit =
                                        (r.data?['criticalPatients']
                                            as List?) ??
                                        [],
                                  );
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
                            final sev = p['severity'];
                            final level = sev?['level'] ?? '—';
                            final score = sev?['score']?.toString() ?? '—';
                            return ListTile(
                              title: Text(p['name'] ?? ''),
                              subtitle: Text('Nivel: $level'),
                              trailing: Text('Score: $score'),
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
                const Text('Severidad'),
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
                    const Text('Condiciones'),
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

// ---------- Lista crítica local ----------
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
                  subtitle: Text('Nivel: ${s['level']}'),
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
