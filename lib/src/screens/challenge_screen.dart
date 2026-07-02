import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_player.dart';

/// Tela de desafio solo (caminho Pesquisador). Resolve desafios aleatórios para
/// ganhar influência no território. Mostra XP total (animado) e o progresso para
/// a próxima posição no ranking. Resultado inline + "PRÓXIMO".
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.api,
    this.territoryId,
    this.areas,
    this.themes,
    this.initialDifficulty = 1,
    this.includeSolved = false,
    this.userLat,
    this.userLng,
  });

  final ApiClient api;
  final String? territoryId;

  /// Áreas e temas escolhidos (vazio/null = todos). Nível inicial (null = qualquer).
  final List<String>? areas;
  final List<String>? themes;
  final int? initialDifficulty;

  /// Inclui desafios já pontuados (modo revisão: tempo reduzido em 50%).
  final bool includeSolved;

  /// Localização do jogador, exigida para pontuar num território (regra de presença).
  final double? userLat;
  final double? userLng;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late Future<Challenge> _future;
  int? _difficulty; // null = qualquer nível
  int _round = 0;
  bool _submitting = false;
  AttemptResult? _result;

  // streak de acertos da sessão (UI pura — sem efeito nas mecânicas)
  int _streak = 0;
  int _confettiTick = 0; // incrementa a cada acerto para disparar o confete

  // anti-chute (sessão): quantos chutes detectados e total de influência perdida
  int _guessStrikes = 0;
  double _penaltyTotal = 0;
  bool _badgeExpanded = false; // quadro completo (some após 5s → só o ícone)
  Timer? _badgeTimer;

  // estatísticas do header
  double _totalXp = 0;
  double _accuracy = 0;
  int _attempts = 0;
  bool _isLeader = false;
  String? _aboveName;
  double _myInf = 0;
  double _aboveInf = 0;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.initialDifficulty;
    _future = _fetch();
    _loadStats();
  }

  Future<Challenge> _fetch() => widget.api.nextChallenge(
        areas: widget.areas,
        difficulty: _difficulty,
        themes: widget.themes,
        includeSolved: widget.includeSolved,
      );

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  /// Mostra o quadro completo do anti-chute e agenda o recolhimento (5s → só ícone).
  void _expandBadge() {
    setState(() => _badgeExpanded = true);
    _badgeTimer?.cancel();
    _badgeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _badgeExpanded = false);
    });
  }

  void _collapseBadge() {
    _badgeTimer?.cancel();
    setState(() => _badgeExpanded = false);
  }

  Future<void> _loadStats() async {
    try {
      final me = await widget.api.me();
      final total = me.knowledgeXp.fold<double>(0, (s, x) => s + x.xp);
      final accuracy = me.accuracy;
      final attempts = me.totalAttempts;

      String? aboveName;
      double myInf = 0, aboveInf = 0;
      bool leader = false;

      if (widget.territoryId != null) {
        final t = await widget.api.getTerritory(widget.territoryId!);
        final ranking = t.generalRanking;
        final myId = widget.api.currentUserId;
        final idx = ranking.indexWhere((e) => e.userId == myId);
        if (idx == 0) {
          leader = true;
          myInf = ranking[0].effectiveInfluence;
        } else if (idx > 0) {
          myInf = ranking[idx].effectiveInfluence;
          aboveName = ranking[idx - 1].name;
          aboveInf = ranking[idx - 1].effectiveInfluence;
        } else if (ranking.isNotEmpty) {
          // ainda fora do ranking: alvo é o último colocado
          aboveName = ranking.last.name;
          aboveInf = ranking.last.effectiveInfluence;
        }
      }

      if (!mounted) return;
      setState(() {
        _totalXp = total;
        _accuracy = accuracy;
        _attempts = attempts;
        _aboveName = aboveName;
        _myInf = myInf;
        _aboveInf = aboveInf;
        _isLeader = leader;
      });
    } catch (_) {
      // header é secundário — falha silenciosa
    }
  }

  void _restart() {
    setState(() {
      _result = null;
      _submitting = false;
      _round++;
      _future = _fetch();
    });
  }

  void _changeDifficulty(int? d) {
    if (d == _difficulty) return;
    setState(() => _difficulty = d);
    _restart();
  }

  Future<void> _showLevelPicker() async {
    final zon = context.zon;
    await showModalBottomSheet<void>(
      context: context,
      // respeita os recortes do sistema (status bar / barra de navegação);
      // forma e cor vêm do bottomSheetTheme (radius 24)
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: zon.outline,
                    borderRadius: BorderRadius.circular(Corners.pill),
                  ),
                ),
              ),
              const Text('Escolha o nível', style: AppText.title),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (int d = 1; d <= 5; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GamePressable(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _changeDifficulty(d);
                          },
                          faceColor:
                              d == _difficulty ? zon.brand : zon.surface,
                          borderColor:
                              d == _difficulty ? zon.brand : zon.outline,
                          edgeColor: d == _difficulty
                              ? zon.brandEdge
                              : zon.neutralEdge,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              '$d',
                              style: AppText.numeric.copyWith(
                                fontSize: 20,
                                color: d == _difficulty
                                    ? zon.onBrand
                                    : zon.onSurfaceMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GamePressable(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _changeDifficulty(null);
                },
                faceColor: _difficulty == null ? zon.brand : zon.surface,
                borderColor: _difficulty == null ? zon.brand : zon.outline,
                edgeColor:
                    _difficulty == null ? zon.brandEdge : zon.neutralEdge,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Qualquer nível',
                    style: AppText.bodyStrong.copyWith(
                      color: _difficulty == null
                          ? zon.onBrand
                          : zon.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(Challenge challenge, Object answer, int timeSpent) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.api.submitAttempt(
        challenge.id,
        answer: answer,
        timeSpentSeconds: timeSpent,
        territoryId: widget.territoryId,
        userLat: widget.userLat,
        userLng: widget.userLng,
      );
      if (!mounted) return;
      final struck = result.guess || result.penalty > 0;
      setState(() {
        _result = result;
        _submitting = false;
        _totalXp += result.xpAwarded; // sobe na hora
        _streak = result.success ? _streak + 1 : 0;
        if (result.success) _confettiTick++;
        // anti-chute: acumula strikes/penalidade da sessão
        if (struck) {
          _guessStrikes++;
          _penaltyTotal += result.penalty;
        }
      });
      // game feel: haptics conforme o resultado (+ celebração em streak)
      if (result.success) {
        if (_streak >= 3) {
          GameHaptics.celebrate();
        } else {
          GameHaptics.correct();
        }
      } else if (result.timedOut) {
        GameHaptics.timeout();
      } else {
        GameHaptics.wrong();
      }
      if (struck) _expandBadge(); // mostra o quadro completo por 5s
      _loadStats(); // reconcilia XP e atualiza o ranking
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // falha de rede (ex.: conexão perdida) — destrava o botão p/ tentar de novo
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Falha de conexão. Toque em RESPONDER para tentar de novo.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DESAFIO'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _showLevelPicker,
              icon: const Icon(LucideIcons.gauge, size: 18),
              label: Text(_difficulty == null ? 'Nível: todos' : 'Nível $_difficulty',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _StatsHeader(
                totalXp: _totalXp,
                accuracy: _accuracy,
                attempts: _attempts,
                isLeader: _isLeader,
                aboveName: _aboveName,
                myInfluence: _myInf,
                aboveInfluence: _aboveInf,
                showRanking: widget.territoryId != null,
                guessStrikes: _guessStrikes,
                streak: _streak,
                onTapGuess: _expandBadge,
              ),
              // quadro completo só enquanto expandido (some após 5s → só o chip)
              if (_guessStrikes > 0 && _badgeExpanded)
                GestureDetector(
                  onTap: _collapseBadge,
                  child: _AntiGuessBadge(
                      strikes: _guessStrikes, penaltyTotal: _penaltyTotal),
                ),
              Expanded(
                child: FutureBuilder<Challenge>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorBox(
                          message: '${snapshot.error}', onRetry: _restart);
                    }
                    final challenge = snapshot.data!;
                    return ChallengePlayer(
                      key: ValueKey(_round),
                      challenge: challenge,
                      submitting: _submitting,
                      answered: _result != null,
                      resultBanner: _result != null
                          ? _ResultBanner(result: _result!, streak: _streak)
                          : null,
                      onNext: _restart,
                      onSubmit: (answer, time) =>
                          _submit(challenge, answer, time),
                    );
                  },
                ),
              ),
            ],
          ),
          // confete celebratório sobre a tela (RepaintBoundary interno,
          // dirigido por controller — não custa nada quando parado)
          Positioned.fill(
            child: ConfettiBurst(
              play: _confettiTick == 0 ? null : _confettiTick,
              origin: const Alignment(0, -0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header compacto: XP total (animado), streak da sessão, taxa de acerto e a
/// barra fina de progresso no ranking do território.
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.totalXp,
    required this.accuracy,
    required this.attempts,
    required this.isLeader,
    required this.aboveName,
    required this.myInfluence,
    required this.aboveInfluence,
    required this.showRanking,
    required this.guessStrikes,
    required this.streak,
    required this.onTapGuess,
  });

  final double totalXp;
  final double accuracy;
  final int attempts;
  final bool isLeader;
  final String? aboveName;
  final double myInfluence;
  final double aboveInfluence;
  final bool showRanking;
  final int guessStrikes; // anti-chute: nº de chutes na sessão (0 = oculto)
  final int streak; // acertos seguidos na sessão (mostra chama a partir de 2)
  final VoidCallback onTapGuess;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final hasTarget = aboveName != null && aboveInfluence > 0;
    final progress =
        hasTarget ? (myInfluence / aboveInfluence).clamp(0.0, 1.0) : 0.0;
    final gap = (aboveInfluence - myInfluence).clamp(0, double.infinity);
    // amigável no 1º deslize; vermelho só com reincidência
    final guessColor = guessStrikes >= 2 ? zon.danger : zon.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, color: zon.xp, size: 16),
              const SizedBox(width: 4),
              XpCounter(
                value: totalXp.round(),
                suffix: ' XP',
                duration: const Duration(milliseconds: 600),
                style: AppText.numeric.copyWith(fontSize: 16),
              ),
              if (streak >= 2) ...[
                const SizedBox(width: 10),
                StreakFlame(count: streak, size: 18),
              ],
              // anti-chute: ícone + "xN" ao lado do XP total
              if (guessStrikes > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onTapGuess,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: guessColor,
                      borderRadius: BorderRadius.circular(Corners.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.timerReset,
                            size: 13, color: zon.onBrand),
                        const SizedBox(width: 3),
                        Text('x$guessStrikes',
                            style: AppText.caption
                                .copyWith(color: zon.onBrand, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(LucideIcons.target, color: zon.successEdge, size: 15),
              const SizedBox(width: 4),
              Text(
                attempts == 0 ? '—' : '${accuracy.round()}% acerto',
                style: AppText.bodyStrong.copyWith(fontSize: 15),
              ),
            ],
          ),
          if (showRanking) ...[
            const SizedBox(height: 6),
            if (isLeader)
              const Align(
                alignment: Alignment.centerLeft,
                child: GameChip(
                  label: 'Você lidera este território!',
                  icon: LucideIcons.crown,
                  color: BrandColors.greenBright,
                  mode: GameChipMode.tonal,
                ),
              )
            else if (hasTarget) ...[
              Text(
                'Faltam ${gap.ceil()} de influência p/ ultrapassar $aboveName',
                style: AppText.caption.copyWith(color: zon.onSurfaceMuted),
              ),
              const SizedBox(height: 4),
              GameProgressBar(value: progress, color: zon.danger, height: 8),
            ] else
              Text('Jogue para entrar no ranking!',
                  style:
                      AppText.caption.copyWith(color: zon.onSurfaceMuted)),
          ],
        ],
      ),
    );
  }
}

/// Badge completo de aviso anti-chute: aparece ao ser acionado e recolhe após
/// 5s, deixando só o chip "xN" ao lado do XP (no header).
/// Tom de coaching (laranja da marca) no 1º deslize; vermelho só com 2+.
class _AntiGuessBadge extends StatelessWidget {
  const _AntiGuessBadge({required this.strikes, required this.penaltyTotal});

  final int strikes;
  final double penaltyTotal;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final atRisk = strikes >= 2; // 2+ chutes = risco alto
    final tone = atRisk ? zon.danger : zon.warning;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: atRisk ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(Corners.sm),
        border: Border.all(
            color: tone.withValues(alpha: atRisk ? 0.7 : 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(atRisk ? LucideIcons.shieldAlert : LucideIcons.timerReset,
              size: 20, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atRisk
                      ? 'Em risco — respire e responda com calma!'
                      : 'Calma aí! Respostas no capricho valem mais.',
                  style: AppText.label.copyWith(color: tone),
                ),
                Text(
                  penaltyTotal > 0
                      ? 'Você já perdeu ${penaltyTotal.toStringAsFixed(0)} de influência. Sem pressa: pensar antes vale mais pontos.'
                      : 'Respostas rápidas e erradas penalizam sua influência.',
                  style: AppText.caption.copyWith(color: zon.onSurface),
                ),
              ],
            ),
          ),
          if (strikes > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(Corners.pill),
              ),
              child: Text('x$strikes',
                  style: AppText.caption
                      .copyWith(color: zon.onBrand, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner de resultado inline — celebração no acerto (pop + XP contando),
/// apoio no erro (shake gentil + copy amigável).
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, this.streak = 0});

  final AttemptResult result;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final ok = result.success;
    final title = ok
        ? (streak >= 3 ? 'ACERTOU! $streak seguidas! 🔥' : 'ACERTOU!')
        : result.timedOut
            ? 'TEMPO ESGOTADO!'
            : 'QUASE!';
    final subtitle = ok
        ? '+${result.score.toStringAsFixed(0)} pts em ${result.area}'
        : 'Sem pontos desta vez — bora pra próxima! 💪';

    return ResultCard(
      success: ok,
      title: title,
      subtitle: subtitle,
      xp: ok ? result.xpAwarded.round() : null,
      extra: [
        if (ok && result.classScoreAwarded > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+${result.classScoreAwarded.toStringAsFixed(0)} Pesquisador no território',
              style: AppText.caption.copyWith(color: zon.onSurfaceMuted),
            ),
          ),
        if (result.penalty > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(LucideIcons.timerReset, size: 14, color: zon.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Anti-chute: −${result.penalty.toStringAsFixed(0)} influência. Com calma vale mais!',
                    style: AppText.caption.copyWith(color: zon.warning),
                  ),
                ),
              ],
            ),
          )
        else if (result.guess)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sem pressa — respostas pensadas valem mais pontos.',
              style: AppText.caption.copyWith(color: zon.warning),
            ),
          ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.cloudOff,
      title: 'Ops, algo deu errado',
      message: message,
      action: GameButton(
        label: 'TENTAR DE NOVO',
        icon: LucideIcons.refreshCw,
        onPressed: onRetry,
      ),
    );
  }
}
