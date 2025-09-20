// lib/config/gql_client.dart
import 'package:flutter/foundation.dart'; // <- ESTE import faltaba
import 'package:graphql_flutter/graphql_flutter.dart';

const _gqlUrl = String.fromEnvironment(
  'GQL_URL',
  defaultValue: 'http://10.0.2.2:4000/graphql',
);

final ValueNotifier<GraphQLClient> gqlClient = ValueNotifier<GraphQLClient>(
  GraphQLClient(
    link: HttpLink(_gqlUrl),
    cache: GraphQLCache(store: InMemoryStore()),
  ),
);
