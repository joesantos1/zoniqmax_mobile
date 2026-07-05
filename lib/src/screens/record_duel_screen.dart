import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_player.dart';

/// Duelo Quebra de Recordes: o desafiante joga rodada a rodada contra os
/// recordes do defensor. Header com VS + placar + dots das rodadas, painel do
/// recorde com barra de potencial ao vivo, e o ChallengePlayer para jogar.
/// Sessão única: sair no meio conta como derrota (o servidor resolve).
class RecordDuelScreen extends StatefulWidget {
  const RecordDuelScreen({
    super.key,
    required this.api,
    required this.initialDuel,
  });

  final ApiClient api;
  final RecordDuel initialDuel;

  @override
  State<RecordDuelScreen> createState() => _RecordDuelScreenState();
}

class _RecordDuelScreenState extends State<RecordDuelScreen> {
  late RecordDuel _duel = widget.initialDuel;

  /// Desafio/ordem da rodada EM JOGO (fica congelado enquanto o resultado é
  /// exibido — o _duel já aponta para a próxima rodada após o submit).
  late Challenge? _roundChallenge = widget.initialDuel.currentChallenge;
  late int _roundOrder = widget.initialDuel.currentRound;

  RecordRoundResult? _lastResult;
  bool _submitting = false;
  bool _finished = false;
  int _confettiTick = 0;

  RecordDuelRound? get _currentRoundInfo {
    for (final r in _duel.rounds) {
      if (r.order == _roundOrder) return r;
    }
    return null;
  }

  bool get _iWon => _duel.status == 'VITORIA_DESAFIANTE';

  Future<void> _submit(Object answer, int timeSpent) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.api.submitRecordRound(
        _duel.id,
        _roundOrder,
        answer: answer,
        timeSpentSeconds: timeSpent,
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _duel = result.duel;
        _submitting = false;
      });
      if (result.won) {
        GameHaptics.correct();
      } else {
        GameHaptics.wrong();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Falha de conexão. Toque em RESPONDER para tentar de novo.'),
      ));
    }
  }

  void _next() {
    if (_duel.inProgress) {
      setState(() {
        _roundOrder = _duel.currentRound;
        _roundChallenge = _duel.currentChallenge;
        _lastResult = null;
      });
    } else {
      setState(() => _finished = true);
      if (_iWon) {
        GameHaptics.conquest();
        setState(() => _confettiTick++);
      }
    }
  }

  Future<void> _confirmLeave() async {
    if (!_duel.inProgress) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonar o duelo?'),
        content: const Text(
            'Sair agora conta como DERROTA — o defensor fica com os pontos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar jogando')),
          GameButton(
            label: 'SAIR',
            variant: GameButtonVariant.danger,
            size: GameButtonSize.sm,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_duel.inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quebra de Recordes'),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _confirmLeave,
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _header(),
                Expanded(child: _finished ? _finalView() : _roundView()),
              ],
            ),
            Positioned.fill(
              child: ConfettiBurst(
                play: _confettiTick == 0 ? null : _confettiTick,
                origin: const Alignment(0, -0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// VS + placar + dots das rodadas.
  Widget _header() {
    final zon = context.zon;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _playerBadge(_duel.challenger, zon.brand, 'Você'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: zon.onSurface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('VS',
                          style: AppText.caption
                              .copyWith(color: zon.surface, fontSize: 12)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_duel.challengerWins} × ${_duel.defenderWins}',
                      style: AppText.numeric.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              _playerBadge(_duel.defender, zon.info, _duel.defender.name),
            ],
          ),
          const SizedBox(height: 8),
          // dots das rodadas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final r in _duel.rounds)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: r.wonByChallenger == null
                        ? Colors.transparent
                        : (r.wonByChallenger! ? zon.success : zon.danger),
                    border: Border.all(
                      color: r.order == _roundOrder && _duel.inProgress
                          ? zon.brand
                          : (r.wonByChallenger == null
                              ? zon.outline
                              : Colors.transparent),
                      width: r.order == _roundOrder && _duel.inProgress
                          ? 2.5
                          : 2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playerBadge(DuelPlayer p, Color ring, String label) {
    final zon = context.zon;
    return Column(
      children: [
        AvatarRing(
          imageUrl: p.avatarUrl,
          initial: p.name.isNotEmpty ? p.name[0] : '?',
          size: 48,
          ringColor: ring,
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: zon.onSurfaceMuted),
          ),
        ),
      ],
    );
  }

  /// Rodada atual: painel do recorde + ChallengePlayer.
  Widget _roundView() {
    final challenge = _roundChallenge;
    final round = _currentRoundInfo;
    if (challenge == null || round == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final answered = _lastResult != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: _PotentialBar(
            key: ValueKey<int>(_roundOrder),
            targetScore: round.targetScore,
            difficulty: challenge.difficulty,
            baseTimeSeconds: challenge.baseTimeSeconds,
            defenderName: _duel.defender.name,
            running: !answered && !_submitting,
          ),
        ),
        Expanded(
          child: ChallengePlayer(
            key: ValueKey<int>(_roundOrder),
            challenge: challenge,
            submitting: _submitting,
            answered: answered,
            resultBanner: answered ? _roundResultBanner(_lastResult!) : null,
            onNext: _next,
            onSubmit: _submit,
          ),
        ),
      ],
    );
  }

  Widget _roundResultBanner(RecordRoundResult r) {
    final title = r.won
        ? 'RECORDE QUEBRADO!'
        : r.timedOut
            ? 'TEMPO ESGOTADO!'
            : r.success
                ? 'O recorde resiste…'
                : 'ERROU!';
    return ResultCard(
      success: r.won,
      title: title,
      subtitle:
          'Você ${r.score.toStringAsFixed(0)} × ${r.targetScore.toStringAsFixed(0)} ${_duel.defender.name}',
    );
  }

  /// Tela final: resultado do duelo + resumo das recompensas.
  Widget _finalView() {
    final zon = context.zon;
    final won = _iWon;
    // espelho das fórmulas do servidor (recordDuels.service.ts) — só exibição
    final conquistador = won ? 15 * _duel.challengerWins + 40 : 0;
    final xp = won ? 5 * _duel.challengerWins : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResultCard(
              success: won,
              title: won ? 'VITÓRIA! 👑' : 'Os recordes resistiram…',
              subtitle: won
                  ? 'Você quebrou os recordes de ${_duel.defender.name} '
                      'por ${_duel.challengerWins} × ${_duel.defenderWins}!'
                  : '${_duel.defender.name} defendeu por '
                      '${_duel.defenderWins} × ${_duel.challengerWins}. '
                      'A revanche abre à meia-noite!',
              extra: [
                if (won)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+$conquistador Conquistador no território · +$xp XP',
                      style: AppText.label.copyWith(color: zon.successEdge),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            GameButton(
              label: 'VOLTAR',
              icon: LucideIcons.arrowLeft,
              variant:
                  won ? GameButtonVariant.primary : GameButtonVariant.secondary,
              expanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de potencial ao vivo: o score que o jogador AINDA pode fazer decai a
/// cada segundo em direção à linha do recorde do defensor. Ticker próprio de
/// 1s (independente do ChallengePlayer — desvio de ~1s é aceitável, é só
/// feedback visual). Verde acima do recorde, vermelho abaixo.
class _PotentialBar extends StatefulWidget {
  const _PotentialBar({
    super.key,
    required this.targetScore,
    required this.difficulty,
    required this.baseTimeSeconds,
    required this.defenderName,
    required this.running,
  });

  final double targetScore;
  final int difficulty;
  final int baseTimeSeconds;
  final String defenderName;
  final bool running;

  @override
  State<_PotentialBar> createState() => _PotentialBarState();
}

class _PotentialBarState extends State<_PotentialBar> {
  Timer? _timer;
  int _elapsed = 0;

  int get _base => 10 * widget.difficulty;
  int get _max => 2 * _base;

  /// Espelho da fórmula do servidor: score = base × (1 + restante/permitido).
  int get _potential {
    final allowed = widget.baseTimeSeconds;
    if (allowed <= 0 || _elapsed >= allowed) return 0;
    final speedRatio = (allowed - _elapsed) / allowed;
    return (_base * (1 + speedRatio)).round();
  }

  @override
  void initState() {
    super.initState();
    if (widget.running) _start();
  }

  @override
  void didUpdateWidget(_PotentialBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.running && oldWidget.running) _timer?.cancel();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= widget.baseTimeSeconds) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final potential = _potential;
    final above = potential > widget.targetScore;
    final color = above ? zon.success : zon.danger;

    return GamePanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.trophy, size: 14, color: zon.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Recorde de ${widget.defenderName}: '
                  '${widget.targetScore.toStringAsFixed(0)} XP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
              ),
              Text(
                '$potential XP',
                style: AppText.numeric.copyWith(fontSize: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // barra do potencial com o marcador do recorde por cima
          LayoutBuilder(
            builder: (context, c) {
              final markerX =
                  (widget.targetScore / _max).clamp(0.0, 1.0) * c.maxWidth;
              return SizedBox(
                height: 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GameProgressBar(
                        value: _max == 0 ? 0 : potential / _max,
                        color: color,
                        height: 12,
                      ),
                    ),
                    Positioned(
                      left: markerX - 1.5,
                      top: -2,
                      bottom: -2,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: zon.onSurface,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            above
                ? 'Responda certo agora para quebrar o recorde!'
                : 'O potencial caiu abaixo do recorde…',
            style: AppText.caption.copyWith(color: zon.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
