import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// GraphQL público (Countries)
const _gqlUrl = String.fromEnvironment(
  'GQL_URL',
  defaultValue: 'https://countries.trevorblades.com/',
);

final ValueNotifier<GraphQLClient> gqlClient = ValueNotifier<GraphQLClient>(
  GraphQLClient(
    link: HttpLink(_gqlUrl),
    cache: GraphQLCache(store: InMemoryStore()),
  ),
);
