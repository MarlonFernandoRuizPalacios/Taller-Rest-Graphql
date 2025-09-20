import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'presentation/app.dart';
import 'config/gql_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Si usas InMemoryStore, no necesitas initHiveForFlutter()
  runApp(GraphQLProvider(client: gqlClient, child: const MyApp()));
}
