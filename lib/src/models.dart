/// Modelos de dados espelhando as respostas da API.
library;

class AuthResult {
  final String token;
  final String userId;
  final String name;
  final String? nickname;
  final String email;

  AuthResult({
    required this.token,
    required this.userId,
    required this.name,
    required this.nickname,
    required this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthResult(
      token: json['token'] as String,
      userId: user['id'] as String,
      name: user['name'] as String,
      nickname: user['nickname'] as String?,
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

/// Território da grade hexagonal do mapa (endpoints /territories/map e /mine).
class MapTerritory {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final bool isCurrent;
  final String? cellKey;
  final String? customName;
  final String? color;
  final String? iconName;
  final String? backgroundUrl;
  final String? governorUserId;
  final String? governorName;
  final String? governorAvatarUrl;
  final DateTime? governorUpdatedAt;
  final DateTime? updatedAt;

  MapTerritory({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.isCurrent,
    required this.cellKey,
    required this.customName,
    required this.color,
    required this.iconName,
    required this.backgroundUrl,
    required this.governorUserId,
    required this.governorName,
    required this.governorAvatarUrl,
    required this.governorUpdatedAt,
    required this.updatedAt,
  });

  bool get isGoverned => governorUserId != null;
  String get displayName => (customName != null && customName!.isNotEmpty)
      ? customName!
      : name;

  /// Chave de cache: cellKey (identidade global da célula) ou o id como fallback.
  String get cacheKey => cellKey ?? id;

  /// Inicial do nome do governador (fallback quando não há foto).
  String get governorInitial =>
      (governorName != null && governorName!.isNotEmpty)
          ? governorName![0].toUpperCase()
          : '?';

  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory MapTerritory.fromJson(Map<String, dynamic> json) {
    return MapTerritory(
      id: json['id'] as String,
      name: json['name'] as String,
      centerLat: (json['centerLat'] as num).toDouble(),
      centerLng: (json['centerLng'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 2,
      isCurrent: json['isCurrent'] as bool? ?? false,
      cellKey: json['cellKey'] as String?,
      customName: json['customName'] as String?,
      color: json['color'] as String?,
      iconName: json['iconName'] as String?,
      backgroundUrl: json['backgroundUrl'] as String?,
      governorUserId: json['governorUserId'] as String?,
      governorName: json['governorName'] as String?,
      governorAvatarUrl: json['governorAvatarUrl'] as String?,
      governorUpdatedAt: _date(json['governorUpdatedAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusKm': radiusKm,
        'isCurrent': isCurrent,
        'cellKey': cellKey,
        'customName': customName,
        'color': color,
        'iconName': iconName,
        'backgroundUrl': backgroundUrl,
        'governorUserId': governorUserId,
        'governorName': governorName,
        'governorAvatarUrl': governorAvatarUrl,
        'governorUpdatedAt': governorUpdatedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

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
  final String? avatarUrl;
  final double effectiveInfluence;
  final List<String> classes;

  RankingEntry({
    required this.position,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.effectiveInfluence,
    required this.classes,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      position: json['position'] as int,
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      effectiveInfluence: (json['effectiveInfluence'] as num?)?.toDouble() ?? 0,
      classes: ((json['classes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ClassRankingEntry {
  final int position;
  final String userId;
  final String name;
  final String? avatarUrl;
  final double score;

  ClassRankingEntry({
    required this.position,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.score,
  });

  factory ClassRankingEntry.fromJson(Map<String, dynamic> json) {
    return ClassRankingEntry(
      position: json['position'] as int,
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TerritoryDetail {
  final String id;
  final String name;
  final String? customName;
  final String? color;
  final String? iconName;
  final String? backgroundUrl;
  final String? governorUserId;
  final List<RankingEntry> generalRanking;
  final Map<String, List<ClassRankingEntry>> rankingByClass;

  TerritoryDetail({
    required this.id,
    required this.name,
    required this.customName,
    required this.color,
    required this.iconName,
    required this.backgroundUrl,
    required this.governorUserId,
    required this.generalRanking,
    required this.rankingByClass,
  });

  String get displayName => (customName != null && customName!.isNotEmpty)
      ? customName!
      : name;

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
      customName: json['customName'] as String?,
      color: json['color'] as String?,
      iconName: json['iconName'] as String?,
      backgroundUrl: json['backgroundUrl'] as String?,
      governorUserId: json['governorUserId'] as String?,
      generalRanking: general,
      rankingByClass: byClass,
    );
  }
}

/// Item do histórico/extrato do jogador (desafio realizado ou bônus enviado).
class ActivityItem {
  final String kind; // 'attempt' | 'bonus_sent'
  final DateTime at;
  final String area;
  // attempt
  final String? challengeType;
  final bool? success;
  final double? score;
  final String? territory;
  // bonus_sent
  final int? bonusSeconds;
  final String? receiverName;
  final String? status;

  ActivityItem({
    required this.kind,
    required this.at,
    required this.area,
    this.challengeType,
    this.success,
    this.score,
    this.territory,
    this.bonusSeconds,
    this.receiverName,
    this.status,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        kind: json['kind'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        area: json['area'] as String,
        challengeType: json['challengeType'] as String?,
        success: json['success'] as bool?,
        score: (json['score'] as num?)?.toDouble(),
        territory: json['territory'] as String?,
        bonusSeconds: (json['bonusSeconds'] as num?)?.toInt(),
        receiverName: json['receiverName'] as String?,
        status: json['status'] as String?,
      );
}

/// Grupo do catálogo de desafios (área/tema/nível) com contagens de novos e
/// já resolvidos (modo revisão).
class ChallengeOption {
  final String area;
  final String? theme;
  final int difficulty;
  final int newCount; // ainda não resolvidos
  final int solvedCount; // já pontuados (revisão)

  ChallengeOption({
    required this.area,
    required this.theme,
    required this.difficulty,
    required this.newCount,
    required this.solvedCount,
  });

  factory ChallengeOption.fromJson(Map<String, dynamic> json) => ChallengeOption(
        area: json['area'] as String,
        theme: json['theme'] as String?,
        difficulty: (json['difficulty'] as num).toInt(),
        newCount: (json['newCount'] as num?)?.toInt() ?? 0,
        solvedCount: (json['solvedCount'] as num?)?.toInt() ?? 0,
      );
}

class Challenge {
  final String id;
  final String type;
  final String area;
  final String? theme;
  final int difficulty;
  final int baseTimeSeconds; // já inclui o bônus de mentoria, se houver
  final int bonusSeconds; // bônus de tempo aplicado (mentoria)
  final bool replay; // revisão: desafio já pontuado (tempo reduzido)
  final Map<String, dynamic> data;

  Challenge({
    required this.id,
    required this.type,
    required this.area,
    required this.theme,
    required this.difficulty,
    required this.baseTimeSeconds,
    required this.bonusSeconds,
    required this.replay,
    required this.data,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      type: json['type'] as String,
      area: json['area'] as String,
      theme: json['theme'] as String?,
      difficulty: json['difficulty'] as int,
      baseTimeSeconds: json['baseTimeSeconds'] as int,
      bonusSeconds: (json['bonusSeconds'] as num?)?.toInt() ?? 0,
      replay: json['replay'] as bool? ?? false,
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
    if (data['prompt'] is String) return data['prompt'] as String;
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
  final double penalty; // anti-chute: pontos de influência perdidos
  final bool guess; // detectado como chute
  final int bonusUsed; // mentoria: segundos de bônus aplicados

  AttemptResult({
    required this.success,
    required this.timedOut,
    required this.score,
    required this.area,
    required this.xpAwarded,
    required this.classScoreAwarded,
    required this.penalty,
    required this.guess,
    required this.bonusUsed,
  });

  factory AttemptResult.fromJson(Map<String, dynamic> json) {
    return AttemptResult(
      success: json['success'] as bool,
      timedOut: json['timedOut'] as bool,
      score: (json['score'] as num).toDouble(),
      area: json['area'] as String,
      xpAwarded: (json['xpAwarded'] as num? ?? 0).toDouble(),
      classScoreAwarded: (json['classScoreAwarded'] as num? ?? 0).toDouble(),
      penalty: (json['penalty'] as num? ?? 0).toDouble(),
      guess: json['guess'] as bool? ?? false,
      bonusUsed: (json['bonusUsed'] as num? ?? 0).toInt(),
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

class TerritoryParticipation {
  final String id;
  final String name;
  final String? customName;
  final double effectiveInfluence;
  final bool isGovernor;

  TerritoryParticipation({
    required this.id,
    required this.name,
    required this.customName,
    required this.effectiveInfluence,
    required this.isGovernor,
  });

  String get displayName => (customName != null && customName!.isNotEmpty)
      ? customName!
      : name;

  factory TerritoryParticipation.fromJson(Map<String, dynamic> json) {
    return TerritoryParticipation(
      id: json['id'] as String,
      name: json['name'] as String,
      customName: json['customName'] as String?,
      effectiveInfluence: (json['effectiveInfluence'] as num?)?.toDouble() ?? 0,
      isGovernor: json['isGovernor'] as bool? ?? false,
    );
  }
}

class ClassTotal {
  final String classType;
  final double score;
  ClassTotal({required this.classType, required this.score});

  factory ClassTotal.fromJson(Map<String, dynamic> json) => ClassTotal(
        classType: json['classType'] as String,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

class AttemptSummary {
  final String type;
  final String area;
  final bool success;
  final double scoreAwarded;
  final DateTime createdAt;

  AttemptSummary({
    required this.type,
    required this.area,
    required this.success,
    required this.scoreAwarded,
    required this.createdAt,
  });

  factory AttemptSummary.fromJson(Map<String, dynamic> json) => AttemptSummary(
        type: json['type'] as String,
        area: json['area'] as String,
        success: json['success'] as bool? ?? false,
        scoreAwarded: (json['scoreAwarded'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Perfil público de outro jogador (visto ao tocar no nome no ranking).
class PublicProfile {
  final String id;
  final String name;
  final String? nickname;
  final String? avatarUrl;
  final List<KnowledgeXp> knowledgeXp;
  final int totalAttempts;
  final int successfulAttempts;
  final List<TerritoryParticipation> territories;
  final List<ClassTotal> classTotals;
  final List<AttemptSummary> recentAttempts;

  PublicProfile({
    required this.id,
    required this.name,
    required this.nickname,
    required this.avatarUrl,
    required this.knowledgeXp,
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.territories,
    required this.classTotals,
    required this.recentAttempts,
  });

  /// Apelido quando houver; senão, o nome.
  String get displayName =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : name;

  double get accuracy =>
      totalAttempts > 0 ? (successfulAttempts / totalAttempts) * 100 : 0;
  double get totalXp => knowledgeXp.fold(0, (s, x) => s + x.xp);

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List<dynamic>? ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return PublicProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      knowledgeXp: list('knowledgeXp', KnowledgeXp.fromJson),
      totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
      successfulAttempts: (json['successfulAttempts'] as num?)?.toInt() ?? 0,
      territories: list('territories', TerritoryParticipation.fromJson),
      classTotals: list('classTotals', ClassTotal.fromJson),
      recentAttempts: list('recentAttempts', AttemptSummary.fromJson),
    );
  }
}

class Me {
  final String id;
  final String name;
  final String? nickname;
  final String email;
  final String? avatarUrl;
  final List<KnowledgeXp> knowledgeXp;
  final int totalAttempts;
  final int successfulAttempts;
  final List<TerritoryParticipation> territories;

  Me({
    required this.id,
    required this.name,
    required this.nickname,
    required this.email,
    required this.avatarUrl,
    required this.knowledgeXp,
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.territories,
  });

  /// Apelido quando houver; senão, o nome.
  String get displayName =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : name;

  /// Taxa de acerto em % (0 quando ainda não há tentativas).
  double get accuracy =>
      totalAttempts > 0 ? (successfulAttempts / totalAttempts) * 100 : 0;

  /// XP total (soma de todas as áreas).
  double get totalXp => knowledgeXp.fold(0, (s, x) => s + x.xp);

  int get governedCount => territories.where((t) => t.isGovernor).length;

  factory Me.fromJson(Map<String, dynamic> json) {
    final xp = (json['knowledgeXp'] as List<dynamic>? ?? [])
        .map((e) => KnowledgeXp.fromJson(e as Map<String, dynamic>))
        .toList();
    final terrs = (json['territories'] as List<dynamic>? ?? [])
        .map((e) => TerritoryParticipation.fromJson(e as Map<String, dynamic>))
        .toList();
    return Me(
      id: json['id'] as String,
      name: json['name'] as String,
      nickname: json['nickname'] as String?,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      knowledgeXp: xp,
      totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
      successfulAttempts: (json['successfulAttempts'] as num?)?.toInt() ?? 0,
      territories: terrs,
    );
  }
}
