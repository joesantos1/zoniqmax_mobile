/// Modelos de dados espelhando as respostas da API.
library;

class AuthResult {
  final String token;
  final String userId;
  final String name;
  final String email;

  AuthResult({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthResult(
      token: json['token'] as String,
      userId: user['id'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
    );
  }
}

class Territory {
  final String id;
  final String name;
  final String type;
  final double centerLat;
  final double centerLng;

  Territory({
    required this.id,
    required this.name,
    required this.type,
    required this.centerLat,
    required this.centerLng,
  });

  factory Territory.fromJson(Map<String, dynamic> json) {
    return Territory(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'hexagono',
      centerLat: (json['centerLat'] as num).toDouble(),
      centerLng: (json['centerLng'] as num).toDouble(),
    );
  }
}

/// Território da grade hexagonal do mapa (endpoint /territories/near).
class MapTerritory {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final String? governorUserId;

  MapTerritory({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.governorUserId,
  });

  factory MapTerritory.fromJson(Map<String, dynamic> json) {
    return MapTerritory(
      id: json['id'] as String,
      name: json['name'] as String,
      centerLat: (json['centerLat'] as num).toDouble(),
      centerLng: (json['centerLng'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 3,
      governorUserId: json['governorUserId'] as String?,
    );
  }

  /// Converte para Territory (usado ao abrir o detalhe).
  Territory toTerritory() => Territory(
        id: id,
        name: name,
        type: 'hexagono',
        centerLat: centerLat,
        centerLng: centerLng,
      );
}

class RankingEntry {
  final int position;
  final String userId;
  final String name;
  final double effectiveInfluence;

  RankingEntry({
    required this.position,
    required this.userId,
    required this.name,
    required this.effectiveInfluence,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      position: json['position'] as int,
      userId: json['userId'] as String,
      name: json['name'] as String,
      effectiveInfluence: (json['effectiveInfluence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ClassRankingEntry {
  final int position;
  final String userId;
  final String name;
  final double score;

  ClassRankingEntry({
    required this.position,
    required this.userId,
    required this.name,
    required this.score,
  });

  factory ClassRankingEntry.fromJson(Map<String, dynamic> json) {
    return ClassRankingEntry(
      position: json['position'] as int,
      userId: json['userId'] as String,
      name: json['name'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TerritoryDetail {
  final String id;
  final String name;
  final String? governorUserId;
  final List<RankingEntry> generalRanking;
  final Map<String, List<ClassRankingEntry>> rankingByClass;

  TerritoryDetail({
    required this.id,
    required this.name,
    required this.governorUserId,
    required this.generalRanking,
    required this.rankingByClass,
  });

  factory TerritoryDetail.fromJson(Map<String, dynamic> json) {
    final general = (json['generalRanking'] as List<dynamic>? ?? [])
        .map((e) => RankingEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final byClassRaw =
        json['rankingByClass'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final byClass = <String, List<ClassRankingEntry>>{};
    byClassRaw.forEach((key, value) {
      byClass[key] = (value as List<dynamic>)
          .map((e) => ClassRankingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    return TerritoryDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      governorUserId: json['governorUserId'] as String?,
      generalRanking: general,
      rankingByClass: byClass,
    );
  }
}

class Challenge {
  final String id;
  final String type;
  final String area;
  final int difficulty;
  final int baseTimeSeconds;
  final Map<String, dynamic> data;

  Challenge({
    required this.id,
    required this.type,
    required this.area,
    required this.difficulty,
    required this.baseTimeSeconds,
    required this.data,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      type: json['type'] as String,
      area: json['area'] as String,
      difficulty: json['difficulty'] as int,
      baseTimeSeconds: json['baseTimeSeconds'] as int,
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  /// Opções de múltipla escolha, se o desafio for desse formato (ex.: QUIZ).
  List<String>? get options {
    final raw = data['opcoes'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return null;
  }

  /// Enunciado a exibir (pergunta, expressão ou sequência).
  String get prompt {
    if (data['pergunta'] is String) return data['pergunta'] as String;
    if (data['expressao'] is String) return 'Quanto é ${data['expressao']}?';
    if (data['sequencia'] is List) {
      return 'Complete a sequência: ${(data['sequencia'] as List).join(', ')}, ?';
    }
    return 'Resolva o desafio';
  }
}

class AttemptResult {
  final bool success;
  final bool timedOut;
  final double score;
  final String area;
  final double xpAwarded;
  final double classScoreAwarded;

  AttemptResult({
    required this.success,
    required this.timedOut,
    required this.score,
    required this.area,
    required this.xpAwarded,
    required this.classScoreAwarded,
  });

  factory AttemptResult.fromJson(Map<String, dynamic> json) {
    return AttemptResult(
      success: json['success'] as bool,
      timedOut: json['timedOut'] as bool,
      score: (json['score'] as num).toDouble(),
      area: json['area'] as String,
      xpAwarded: (json['xpAwarded'] as num? ?? 0).toDouble(),
      classScoreAwarded: (json['classScoreAwarded'] as num? ?? 0).toDouble(),
    );
  }
}

class Duel {
  final String id;
  final String challengeId;
  final String status;
  final String challengerId;
  final String? opponentId;
  final double? challengerScore;
  final double? opponentScore;
  final String? winnerId;

  Duel({
    required this.id,
    required this.challengeId,
    required this.status,
    required this.challengerId,
    required this.opponentId,
    required this.challengerScore,
    required this.opponentScore,
    required this.winnerId,
  });

  factory Duel.fromJson(Map<String, dynamic> json) {
    return Duel(
      id: json['id'] as String,
      challengeId: json['challengeId'] as String,
      status: json['status'] as String,
      challengerId: json['challengerId'] as String,
      opponentId: json['opponentId'] as String?,
      challengerScore: (json['challengerScore'] as num?)?.toDouble(),
      opponentScore: (json['opponentScore'] as num?)?.toDouble(),
      winnerId: json['winnerId'] as String?,
    );
  }
}

class DuelAttemptResult {
  final double yourScore;
  final bool success;
  final bool timedOut;
  final bool resolved;
  final String? winnerId;

  DuelAttemptResult({
    required this.yourScore,
    required this.success,
    required this.timedOut,
    required this.resolved,
    required this.winnerId,
  });

  factory DuelAttemptResult.fromJson(Map<String, dynamic> json) {
    return DuelAttemptResult(
      yourScore: (json['yourScore'] as num).toDouble(),
      success: json['success'] as bool,
      timedOut: json['timedOut'] as bool,
      resolved: json['resolved'] as bool,
      winnerId: json['winnerId'] as String?,
    );
  }
}

class KnowledgeXp {
  final String area;
  final double xp;
  KnowledgeXp({required this.area, required this.xp});

  factory KnowledgeXp.fromJson(Map<String, dynamic> json) {
    return KnowledgeXp(
      area: json['area'] as String,
      xp: (json['xp'] as num).toDouble(),
    );
  }
}

class Me {
  final String id;
  final String name;
  final String email;
  final List<KnowledgeXp> knowledgeXp;

  Me({
    required this.id,
    required this.name,
    required this.email,
    required this.knowledgeXp,
  });

  factory Me.fromJson(Map<String, dynamic> json) {
    final xp = (json['knowledgeXp'] as List<dynamic>? ?? [])
        .map((e) => KnowledgeXp.fromJson(e as Map<String, dynamic>))
        .toList();
    return Me(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      knowledgeXp: xp,
    );
  }
}
