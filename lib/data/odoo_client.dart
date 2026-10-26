import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where and how to reach an Odoo 19 server.
class OdooConfig {
  const OdooConfig({required this.baseUrl, required this.db, required this.apiKey});

  /// Normalised, without a trailing slash: `https://odoo.example.com`.
  final String baseUrl, db, apiKey;

  /// Adds `https://` when no scheme is given and drops trailing slashes.
  static String normaliseUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(u)) u = 'https://$u';
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  String get host => Uri.tryParse(baseUrl)?.host ?? baseUrl;
}

/// A failed call: the server said no, or it could not be reached.
class OdooException implements Exception {
  const OdooException(this.message, {this.status, this.network = false});

  final String message;

  /// HTTP status, when the server answered.
  final int? status;

  /// True when there was no answer at all (offline, DNS, timeout). Retrying later may work.
  final bool network;

  bool get isAuth => status == 401 || status == 403;

  @override
  String toString() => 'OdooException(${status ?? (network ? 'network' : '-')}): $message';
}

/// Calls Odoo's JSON-2 external API: `POST /json/2/<model>/<method>` with a
/// bearer API key. Arguments go in the JSON body by name; `ids` selects the
/// records a method runs on.
class OdooClient {
  OdooClient(this.config, {http.Client? client, this.timeout = const Duration(seconds: 20)}) : _http = client ?? http.Client();

  final OdooConfig config;
  final Duration timeout;
  final http.Client _http;

  Future<dynamic> call(String model, String method, {List<int>? ids, Map<String, Object?> args = const {}}) async {
    final uri = Uri.parse('${config.baseUrl}/json/2/$model/$method');
    final body = jsonEncode({'ids': ?ids, ...args});
    final http.Response res;
    try {
      res = await _http
          .post(uri, body: body, headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'bearer ${config.apiKey}',
            if (config.db.isNotEmpty) 'X-Odoo-Database': config.db,
          })
          .timeout(timeout);
    } on TimeoutException {
      throw const OdooException('The server took too long to answer.', network: true);
    } on http.ClientException catch (e) {
      throw OdooException('Could not reach the server: ${e.message}', network: true);
    } on FormatException {
      throw const OdooException('The server address is not valid.');
    } catch (e) {
      // dart:io's SocketException and friends, without importing dart:io (web-safe).
      throw OdooException('Could not reach the server: $e', network: true);
    }

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        throw OdooException('The server sent something that is not Odoo JSON. Check the address.', status: res.statusCode);
      }
    }
    throw OdooException(_errorMessage(res.statusCode, text), status: res.statusCode);
  }

  static String _errorMessage(int status, String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String && (j['message'] as String).isNotEmpty) return j['message'] as String;
    } on FormatException {
      // Not JSON; fall through to the generic text.
    }
    return switch (status) {
      401 => 'The API key was rejected.',
      403 => 'This API key is not allowed to do that.',
      404 => 'Odoo was not found at that address, or it is not version 19 (no /json/2 API).',
      _ => 'Odoo returned an error ($status).',
    };
  }

  void close() => _http.close();
}
