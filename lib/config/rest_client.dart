import 'package:dio/dio.dart';

// 10.0.2.2 para emulador Android; en iOS Simulator usa http://localhost
const _baseUrl = String.fromEnvironment(
  'REST_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

final rest = Dio(
  BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 8),
  ),
);
