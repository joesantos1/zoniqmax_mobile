import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _userIdKey = 'user_id';

  String? _token;
  String? _userId;

  /// Id do jogador autenticado (disponível após login/registro ou loadToken).
  String? get currentUserId => _userId;

  Future<String?> loadToken() async {
    _token ??= await _storage.read(key: _tokenKey);
    _userId ??= await _storage.read(key: _userIdKey);
    return _token;
  }

  Future<void> _saveSession(String token, String userId) async {
    _token = token;
    _userId = userId;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    // limpa o snapshot do mapa do usuário que saiu (evita vazar entre contas)
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        if (k.startsWith('map_snapshot_')) await prefs.remove(k);
      }
    } catch (_) {}
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

  Future<AuthResult> register(
    String name,
    String nickname,
    String email,
    String password,
  ) async {
    final res = await _client.post(
      _uri('/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'nickname': nickname,
        'email': email,
        'password': password,
      }),
    );
    final result = AuthResult.fromJson(_decode(res) as Map<String, dynamic>);
    await _saveSession(result.token, result.userId);
    return result;
  }

  /// Login por e-mail OU apelido.
  Future<AuthResult> login(String identifier, String password) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    final result = AuthResult.fromJson(_decode(res) as Map<String, dynamic>);
    await _saveSession(result.token, result.userId);
    return result;
  }

  /// Verifica se um apelido está disponível (formato válido + não usado).
  Future<bool> nicknameAvailable(String nickname) async {
    final res = await _client.get(
      _uri('/auth/nickname-available'
          '?nickname=${Uri.encodeQueryComponent(nickname)}'),
      headers: _headers(),
    );
    final body = _decode(res) as Map<String, dynamic>;
    return body['available'] == true;
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

  /// Base do mapa: zona atual + zonas governadas no viewport (bounds).
  /// Com [since] (ISO), retorna apenas o delta de zonas alteradas — refresh barato.
  Future<List<MapTerritory>> mapView({
    required double lat,
    required double lng,
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    String? since,
  }) async {
    final q = StringBuffer(
      '/territories/map?lat=$lat&lng=$lng'
      '&minLat=$minLat&minLng=$minLng&maxLat=$maxLat&maxLng=$maxLng',
    );
    if (since != null) q.write('&since=${Uri.encodeQueryComponent(since)}');
    final res = await _client.get(_uri(q.toString()), headers: _headers(auth: true));
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => MapTerritory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Zonas do jogador (governa ou tem influência) — sempre visíveis no mapa.
  Future<List<MapTerritory>> myZones() async {
    final res =
        await _client.get(_uri('/territories/mine'), headers: _headers(auth: true));
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

  // ---- Mentoria (bônus de tempo) ----

  /// Envia um bônus de tempo a um jogador do território (regras no servidor).
  Future<void> sendBonus(
    String receiverUserId,
    String area,
    int bonusSeconds,
  ) async {
    final res = await _client.post(
      _uri('/bonuses'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'receiverUserId': receiverUserId,
        'area': area,
        'bonusSeconds': bonusSeconds,
      }),
    );
    _decode(res);
  }

  // ---- Desafios ----

  Future<Challenge> nextChallenge({
    List<String>? areas,
    int? difficulty,
    List<String>? themes,
    bool includeSolved = false,
  }) async {
    final params = <String, String>{
      if (areas != null && areas.isNotEmpty) 'areas': areas.join(','),
      if (difficulty != null) 'difficulty': '$difficulty',
      if (themes != null && themes.isNotEmpty) 'themes': themes.join(','),
      if (includeSolved) 'includeSolved': 'true',
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final res = await _client.get(
      _uri('/challenges/next$query'),
      headers: _headers(auth: true),
    );
    return Challenge.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Inicia uma sessão de desafios — reinicia o streak anti-chute no servidor.
  Future<void> startChallengeSession() async {
    final res = await _client.post(
      _uri('/challenges/session'),
      headers: _headers(auth: true),
    );
    _decode(res);
  }

  /// Catálogo de desafios agrupados por área/tema/nível, com contagens de novos
  /// e já resolvidos (revisão) — o cliente decide o que mostrar.
  Future<List<ChallengeOption>> challengeCatalog() async {
    final res = await _client.get(
      _uri('/challenges/catalog'),
      headers: _headers(auth: true),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => ChallengeOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttemptResult> submitAttempt(
    String challengeId, {
    required Object answer,
    required int timeSpentSeconds,
    String? territoryId,
    double? userLat,
    double? userLng,
  }) async {
    final res = await _client.post(
      _uri('/challenges/$challengeId/attempt'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'answer': answer,
        'timeSpentSeconds': timeSpentSeconds,
        if (territoryId != null) 'territoryId': territoryId,
        if (userLat != null) 'userLat': userLat,
        if (userLng != null) 'userLng': userLng,
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

  /// Perfil público de outro jogador.
  /// Histórico público de um jogador (desafios + bônus enviados); opcionalmente
  /// filtrado por território.
  Future<List<ActivityItem>> playerHistory(
    String userId, {
    String? territoryId,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (territoryId != null) 'territoryId': territoryId,
    };
    final q = '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final res = await _client.get(
      _uri('/users/$userId/history$q'),
      headers: _headers(auth: true),
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PublicProfile> getPlayer(String userId) async {
    final res = await _client.get(
      _uri('/users/$userId'),
      headers: _headers(auth: true),
    );
    return PublicProfile.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> updateProfile({String? name, String? nickname}) async {
    final res = await _client.patch(
      _uri('/me/profile'),
      headers: _headers(auth: true),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (nickname != null) 'nickname': nickname,
      }),
    );
    _decode(res);
  }

  Future<void> changePassword(String current, String newPassword) async {
    final res = await _client.patch(
      _uri('/me/password'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'currentPassword': current,
        'newPassword': newPassword,
      }),
    );
    _decode(res);
  }

  /// Envia uma imagem ao Cloudinary (assinatura no servidor) e retorna a URL.
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final signRes = await _client.post(
      _uri('/me/avatar/sign'),
      headers: _headers(auth: true),
    );
    final sign = _decode(signRes) as Map<String, dynamic>;
    final cloudName = sign['cloudName'] as String;

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = sign['apiKey'].toString()
      ..fields['timestamp'] = sign['timestamp'].toString()
      ..fields['folder'] = sign['folder'].toString()
      ..fields['signature'] = sign['signature'].toString()
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(streamed.statusCode, 'Falha no upload da imagem');
    }
    return (jsonDecode(body) as Map<String, dynamic>)['secure_url'] as String;
  }

  /// Upload do avatar do jogador + salva a URL no perfil.
  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    final url = await uploadImage(bytes, filename);
    final patchRes = await _client.patch(
      _uri('/me/avatar'),
      headers: _headers(auth: true),
      body: jsonEncode({'avatarUrl': url}),
    );
    _decode(patchRes);
    return url;
  }

  /// Personaliza a zona (somente governador). Campos nulos não são alterados.
  Future<void> customizeTerritory(
    String territoryId, {
    String? customName,
    String? color,
    String? iconName,
    String? backgroundUrl,
  }) async {
    final res = await _client.patch(
      _uri('/territories/$territoryId/customize'),
      headers: _headers(auth: true),
      body: jsonEncode({
        if (customName != null) 'customName': customName,
        if (color != null) 'color': color,
        if (iconName != null) 'iconName': iconName,
        if (backgroundUrl != null) 'backgroundUrl': backgroundUrl,
      }),
    );
    _decode(res);
  }
}
