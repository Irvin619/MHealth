import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String webBaseUrl = 'http://127.0.0.1:8000/api';
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';
  static const String _tokenKey = 'auth_token';

  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

  static String get _defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorBaseUrl;
    }
    return webBaseUrl;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(_uri(path), headers: await _headers());
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, String>> _headers() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/${path.replaceFirst('/', '')}');

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'The server returned an invalid response.',
        response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(decoded), response.statusCode);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  String _errorMessage(Object? response) {
    if (response is Map<String, dynamic>) {
      final errors = response['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }
      }
      final message = response['message'];
      if (message != null) {
        return message.toString();
      }
    }
    return 'Request failed. Please try again.';
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

List<Map<String, dynamic>> responseItems(Map<String, dynamic> response) {
  final Object? value =
      response['data'] ?? response['summaries'] ?? response['messages'];
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  if (value is Map<String, dynamic> && value['data'] is List) {
    return (value['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return [];
}
