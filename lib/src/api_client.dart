import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'models.dart';

/// Exceção com mensagem amigável vinda da API.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Cliente HTTP da API ZonIQmax. Gerencia o token JWT em armazenamento seguro.
class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'jwt_token';

  String? _token;

  Future<String?> loadToken() async {
    _token ??= await _storage.read(key: _tokenKey);
    return _token;
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> _headers({bool auth = false}) {
    final h = {'Content-Type': 'application/json'};
    if (auth && _token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = (body is Map && body['message'] is String)
        ? body['message'] as String
        : 'Erro ${res.statusCode}';
    throw ApiException(res.statusCode, msg);
  }

  // ---- Auth ----

  Future<AuthResult> register(String name, String email, String password) async {
    final res = await _client.post(
      _uri('/auth/register'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final result = AuthResult.fromJson(_decode(res) as Map<String, dynamic>);
    await _saveToken(result.token);
    return result;
  }

  Future<AuthResult> login(String email, String password) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final result = AuthResult.fromJson(_decode(res) as Map<String, dynamic>);
    await _saveToken(result.token);
    return result;
  }

  // ---- Territórios ----

  Future<List<Territory>> listTerritories() async {
    final res = await _client.get(_uri('/territories'), headers: _headers());
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => Territory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TerritoryDetail> getTerritory(String id) async {
    final res = await _client.get(_uri('/territories/$id'), headers: _headers());
    return TerritoryDetail.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Grade hexagonal de territórios ao redor de um ponto (base do mapa).
  Future<List<MapTerritory>> territoriesNear(
    double lat,
    double lng, {
    int rings = 2,
  }) async {
    final res = await _client.get(
      _uri('/territories/near?lat=$lat&lng=$lng&rings=$rings'),
      headers: _headers(),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => MapTerritory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adiciona pontos de uma classe no território (autenticado).
  Future<void> addScore(String territoryId, String classType, num delta) async {
    final res = await _client.post(
      _uri('/territories/$territoryId/score'),
      headers: _headers(auth: true),
      body: jsonEncode({'classType': classType, 'delta': delta}),
    );
    _decode(res);
  }

  // ---- Desafios ----

  Future<Challenge> nextChallenge({String? area}) async {
    final query = area != null ? '?area=$area' : '';
    final res = await _client.get(
      _uri('/challenges/next$query'),
      headers: _headers(auth: true),
    );
    return Challenge.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<AttemptResult> submitAttempt(
    String challengeId, {
    required Object answer,
    required int timeSpentSeconds,
    String? territoryId,
  }) async {
    final res = await _client.post(
      _uri('/challenges/$challengeId/attempt'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'answer': answer,
        'timeSpentSeconds': timeSpentSeconds,
        if (territoryId != null) 'territoryId': territoryId,
      }),
    );
    return AttemptResult.fromJson(_decode(res) as Map<String, dynamic>);
  }

  // ---- Duelos ----

  Future<Duel> createDuel({String? area, String? territoryId, String? challengeId}) async {
    final res = await _client.post(
      _uri('/duels'),
      headers: _headers(auth: true),
      body: jsonEncode({
        if (area != null) 'area': area,
        if (territoryId != null) 'territoryId': territoryId,
        if (challengeId != null) 'challengeId': challengeId,
      }),
    );
    return Duel.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<DuelAttemptResult> submitDuelAttempt(
    String duelId, {
    required Object answer,
    required int timeSpentSeconds,
  }) async {
    final res = await _client.post(
      _uri('/duels/$duelId/attempt'),
      headers: _headers(auth: true),
      body: jsonEncode({'answer': answer, 'timeSpentSeconds': timeSpentSeconds}),
    );
    return DuelAttemptResult.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Busca um desafio por id (sem a resposta) — usado no fluxo de duelo.
  Future<Challenge> getChallenge(String challengeId) async {
    final res = await _client.get(
      _uri('/challenges/$challengeId'),
      headers: _headers(auth: true),
    );
    return Challenge.fromJson(_decode(res) as Map<String, dynamic>);
  }

  // ---- Perfil ----

  Future<Me> me() async {
    final res = await _client.get(_uri('/me'), headers: _headers(auth: true));
    return Me.fromJson(_decode(res) as Map<String, dynamic>);
  }
}
