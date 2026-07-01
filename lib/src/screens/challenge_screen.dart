import 'dart:async';
import 'dart:math' as math;
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      // respeita os recortes do sistema (status bar / barra de navegação)
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Escolha o nível',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (int d = 1; d <= 5; d++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _changeDifficulty(d);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: d == _difficulty
                              ? AppColors.orange
                              : AppColors.paperDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: d == _difficulty
                                ? AppColors.orange
                                : AppColors.line,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$d',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: d == _difficulty
                                ? AppColors.white
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                _changeDifficulty(null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _difficulty == null
                      ? AppColors.orange
                      : AppColors.paperDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _difficulty == null ? AppColors.orange : AppColors.line,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Qualquer nível',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color:
                        _difficulty == null ? AppColors.white : AppColors.muted,
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
        // anti-chute: acumula strikes/penalidade da sessão
        if (struck) {
          _guessStrikes++;
          _penaltyTotal += result.penalty;
        }
      });
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
      body: Column(
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
            onTapGuess: _expandBadge,
          ),
          // quadro completo só enquanto expandido (some após 5s → fica só o chip)
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
                  resultBanner:
                      _result != null ? _ResultBanner(result: _result!) : null,
                  onNext: _restart,
                  onSubmit: (answer, time) => _submit(challenge, answer, time),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Header compacto: XP total + taxa de acerto (linha única) e barra fina de ranking.
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
  final VoidCallback onTapGuess;

  @override
  Widget build(BuildContext context) {
    final hasTarget = aboveName != null && aboveInfluence > 0;
    final progress =
        hasTarget ? (myInfluence / aboveInfluence).clamp(0.0, 1.0) : 0.0;
    final gap = (aboveInfluence - myInfluence).clamp(0, double.infinity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.zap, color: AppColors.orange, size: 16),
              const SizedBox(width: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: totalXp),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (_, v, __) => Text(
                  '${v.round()} XP',
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              // anti-chute: ícone + "xN" ao lado do XP total
              if (guessStrikes > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onTapGuess,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.shieldAlert,
                            size: 13, color: AppColors.white),
                        const SizedBox(width: 3),
                        Text('x$guessStrikes',
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              const Icon(LucideIcons.target, color: AppColors.green, size: 15),
              const SizedBox(width: 4),
              Text(
                attempts == 0 ? '—' : '${accuracy.round()}% acerto',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          if (showRanking) ...[
            const SizedBox(height: 6),
            if (isLeader)
              const Text('👑 Você lidera este território!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
            else if (hasTarget) ...[
              Text(
                'Faltam ${gap.ceil()} de influência p/ ultrapassar 👤$aboveName',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: AppColors.paperDark,
                    color: AppColors.red,
                  ),
                ),
              ),
            ] else
              const Text('Jogue para entrar no ranking!',
                  style: TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// Badge completo de aviso anti-chute: aparece ao ser acionado e recolhe após
/// 5s, deixando só o chip "xN" ao lado do XP (no header).
class _AntiGuessBadge extends StatelessWidget {
  const _AntiGuessBadge({required this.strikes, required this.penaltyTotal});

  final int strikes;
  final double penaltyTotal;

  @override
  Widget build(BuildContext context) {
    final atRisk = strikes >= 2; // 2+ chutes = risco alto
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: atRisk ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.red.withValues(alpha: atRisk ? 0.7 : 0.4),
            width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldAlert, size: 20, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atRisk
                      ? 'EM RISCO — pare de chutar!'
                      : 'Anti-chute ativado',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.red),
                ),
                Text(
                  penaltyTotal > 0
                      ? 'Você já perdeu ${penaltyTotal.toStringAsFixed(0)} de influência. Responda com calma para parar de perder.'
                      : 'Respostas rápidas e erradas penalizam sua influência.',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink),
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
                color: AppColors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('x$strikes',
                  style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner de resultado inline, com animação de entrada (pop / shake).
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.success;
    final color = ok ? AppColors.green : AppColors.red;
    final title = ok
        ? 'ACERTOU!'
        : result.timedOut
            ? 'TEMPO ESGOTADO!'
            : 'ERROU!';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final dx = ok ? 0.0 : math.sin(t * math.pi * 3) * 8 * (1 - t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        );
      },
      child: ComicPanel(
        color: AppColors.white,
        child: Row(
          children: [
            Icon(ok ? LucideIcons.partyPopper : LucideIcons.x,
                size: 36, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ok
                        ? '+${result.score.toStringAsFixed(0)} pts · +${result.xpAwarded.toStringAsFixed(0)} XP (${result.area})'
                        : 'Nada de pontos desta vez.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (ok && result.classScoreAwarded > 0)
                    Text(
                      '+${result.classScoreAwarded.toStringAsFixed(0)} Pesquisador no território',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (result.penalty > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.triangleAlert,
                              size: 14, color: AppColors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Anti-chute: −${result.penalty.toStringAsFixed(0)} influência. Pare de chutar!',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.red),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (result.guess)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Evite chutar — respostas rápidas e erradas penalizam!',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
