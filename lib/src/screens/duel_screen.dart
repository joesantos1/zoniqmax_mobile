import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_player.dart';

/// Tela de duelo cognitivo (caminho Conquistador).
/// Cria um duelo, o jogador atual joga como desafiante e vê o resultado.
/// O duelo só resolve quando um segundo jogador também tenta (1v1 assíncrono).
class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    required this.api,
    this.territoryId,
    this.area,
  });

  final ApiClient api;
  final String? territoryId;
  final String? area;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  late Future<Challenge> _setup;
  Duel? _duel;
  bool _submitting = false;
  DuelAttemptResult? _result;
  int _confettiTick = 0; // incrementa na vitória para disparar o confete

  @override
  void initState() {
    super.initState();
    _setup = _createAndLoad();
  }

  Future<Challenge> _createAndLoad() async {
    final duel = await widget.api.createDuel(
      area: widget.area,
      territoryId: widget.territoryId,
    );
    _duel = duel;
    return widget.api.getChallenge(duel.challengeId);
  }

  void _restart() {
    setState(() {
      _result = null;
      _submitting = false;
      _duel = null;
      _setup = _createAndLoad();
    });
  }

  /// O duelo resolveu com vitória do jogador atual?
  bool _isWin(DuelAttemptResult r) =>
      r.resolved &&
      r.winnerId != null &&
      r.winnerId == widget.api.currentUserId;

  Future<void> _submit(Object answer, int timeSpent) async {
    final duel = _duel;
    if (duel == null) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.api.submitDuelAttempt(
        duel.id,
        answer: answer,
        timeSpentSeconds: timeSpent,
      );
      if (!mounted) return;
      final won = _isWin(result);
      setState(() {
        _result = result;
        if (won) _confettiTick++;
      });
      // game feel: vibração de conquista na vitória, baque curto na derrota
      if (won) {
        GameHaptics.conquest();
      } else if (result.resolved && result.winnerId != null) {
        GameHaptics.wrong();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DUELO')),
      body: Stack(
        children: [
          _result != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: _DuelResultView(
                    result: _result!,
                    duelId: _duel!.id,
                    won: _isWin(_result!),
                    onAgain: _restart,
                  ),
                )
              : FutureBuilder<Challenge>(
                  future: _setup,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return EmptyState(
                        icon: LucideIcons.cloudOff,
                        color: context.zon.danger,
                        title: 'Ops, o duelo não começou',
                        message: '${snapshot.error}',
                        action: GameButton(
                          label: 'TENTAR DE NOVO',
                          icon: LucideIcons.refreshCw,
                          onPressed: _restart,
                        ),
                      );
                    }
                    return ChallengePlayer(
                      challenge: snapshot.data!,
                      submitting: _submitting,
                      onSubmit: _submit,
                    );
                  },
                ),
          // confete celebratório sobre a tela (só dispara na vitória)
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

class _DuelResultView extends StatelessWidget {
  const _DuelResultView({
    required this.result,
    required this.duelId,
    required this.won,
    required this.onAgain,
  });

  final DuelAttemptResult result;
  final String duelId;
  final bool won;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final waiting = !result.resolved;
    final draw = result.resolved && result.winnerId == null;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // placar VS: você x oponente
            GamePanel(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _Duelist(
                      label: 'Você',
                      initial: 'V',
                      ringColor: zon.brand,
                      score: result.yourScore.toStringAsFixed(0),
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: zon.onSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Text('VS',
                        style: AppText.title.copyWith(color: zon.surface)),
                  ),
                  Expanded(
                    child: _Duelist(
                      label: 'Oponente',
                      initial: '?',
                      ringColor: waiting ? zon.onSurfaceMuted : zon.info,
                      score: '—',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            if (waiting) ...[
              GameChip(
                label: 'Aguardando oponente…',
                icon: LucideIcons.hourglass,
                color: zon.warning,
                mode: GameChipMode.tonal,
              ),
              const SizedBox(height: Space.lg),
              GamePanel(
                color: Color.alphaBlend(
                    zon.info.withValues(alpha: 0.10), zon.surface),
                borderColor: zon.info.withValues(alpha: 0.45),
                shadow: false,
                child: Column(
                  children: [
                    const Text(
                      'Outro jogador precisa entrar neste duelo para resolvê-lo. '
                      'Sua pontuação já está guardada!',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                    const SizedBox(height: Space.sm),
                    SelectableText(
                      'ID do duelo:\n$duelId',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(color: zon.territory),
                    ),
                  ],
                ),
              ),
            ] else
              ResultCard(
                success: won || draw,
                title: won
                    ? 'Você venceu o duelo!'
                    : (draw ? 'Empate!' : 'Não foi dessa vez…'),
                subtitle: won
                    ? 'Sua pontuação falou mais alto. Que vitória!'
                    : (draw
                        ? 'Pontuações iguais — ninguém levou esta.'
                        : 'O oponente pontuou mais. Bora pra revanche?'),
              ),
            const SizedBox(height: Space.xl),
            GameButton(
              label: 'NOVO DUELO',
              icon: LucideIcons.swords,
              expanded: true,
              onPressed: onAgain,
            ),
          ],
        ),
      ),
    );
  }
}

/// Coluna de um duelista no placar: avatar + rótulo + pontuação.
class _Duelist extends StatelessWidget {
  const _Duelist({
    required this.label,
    required this.initial,
    required this.ringColor,
    required this.score,
  });

  final String label;
  final String initial;
  final Color ringColor;
  final String score;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Column(
      children: [
        AvatarRing(initial: initial, size: 64, ringColor: ringColor),
        const SizedBox(height: Space.sm),
        Text(label,
            style: AppText.caption.copyWith(color: zon.onSurfaceMuted)),
        const SizedBox(height: 2),
        Text(score, style: AppText.numeric.copyWith(fontSize: 20)),
      ],
    );
  }
}
