import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

/// Thrown when the backend returns a non-2xx response. [message] is the
/// backend's `detail` field (FastAPI error) when present, so the UI can show
/// exactly what went wrong (e.g. a 422 validation message).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin wrapper over `http` that prefixes [AppConfig.apiBaseUrl], encodes JSON,
/// and turns error responses into [ApiException]. All methods return the decoded
/// JSON body (Map or List), or null for empty (204) responses.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _jsonHeaders = {'Content-Type': 'application/json'};

  /// Bearer token for the signed-in user. Set by [AuthController] after a
  /// successful login and cleared on sign-out. It is shared across every
  /// [ApiClient] instance and attached as `Authorization: Bearer <token>` on
  /// every request, so the backend derives the acting user + role from it
  /// (instead of trusting client-supplied params).
  static String? authToken;

  /// Builds request headers, adding the Authorization header when signed in.
  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{if (extra != null) ...extra};
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  /// Absolute URL for a backend resource (e.g. a document download endpoint),
  /// suitable for opening in a browser / external viewer via url_launcher.
  String absoluteUrl(String path) => _uri(path).toString();

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _client.get(_uri(path, query), headers: _headers());
    return _decode(res);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await _client.post(
      _uri(path, query),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await _client.patch(
      _uri(path, query),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await _client.put(
      _uri(path, query),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await _client.delete(_uri(path), headers: _headers());
    _decode(res);
  }

  /// Fetches raw bytes (e.g. a document) for in-app preview, disk-cached.
  ///
  /// Document bytes are immutable (the download endpoints send a long
  /// Cache-Control), so we cache the file to disk keyed by URL — the first view
  /// downloads it, every later view (preview/share, this session or the next)
  /// is instant with no network call.
  Future<Uint8List> getBytes(String path) async {
    final url = _uri(path).toString();
    final file = await DefaultCacheManager().getSingleFile(url);
    return file.readAsBytes();
  }

  /// Multipart POST for file uploads: [fields] are form text fields and a single
  /// file is attached under [fileField]. Returns the decoded JSON body.
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filename,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers())
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));
    final res = await http.Response.fromStream(await _client.send(req));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok) {
      String detail = res.body;
      try {
        final parsed = jsonDecode(res.body);
        if (parsed is Map && parsed['detail'] != null) {
          detail = parsed['detail'].toString();
        }
      } catch (_) {/* keep raw body */}
      throw ApiException(res.statusCode, detail);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}
