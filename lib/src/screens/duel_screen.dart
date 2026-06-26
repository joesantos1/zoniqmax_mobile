import 'package:flutter/material.dart';

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
      setState(() => _result = result);
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _result != null
            ? _DuelResultView(result: _result!, duelId: _duel!.id, onAgain: _restart)
            : FutureBuilder<Challenge>(
                future: _setup,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _restart, child: const Text('Tentar de novo')),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    child: ChallengePlayer(
                      challenge: snapshot.data!,
                      submitting: _submitting,
                      onSubmit: _submit,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _DuelResultView extends StatelessWidget {
  const _DuelResultView({
    required this.result,
    required this.duelId,
    required this.onAgain,
  });

  final DuelAttemptResult result;
  final String duelId;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final waiting = !result.resolved;
    final color = waiting ? AppColors.orange : AppColors.red;
    final title = waiting ? 'AGUARDANDO OPONENTE' : 'DUELO RESOLVIDO';

    return Center(
      child: ComicPanel(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(waiting ? Icons.hourglass_top : Icons.sports_kabaddi, size: 64, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 16),
            Text('Sua pontuação: ${result.yourScore.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            if (waiting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const Text(
                      'Outro jogador precisa entrar neste duelo para resolvê-lo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'ID do duelo:\n$duelId',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.brown),
                    ),
                  ],
                ),
              )
            else
              Text(
                result.winnerId == null ? 'Empate!' : 'Vencedor definido pela maior pontuação.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAgain, child: const Text('NOVO DUELO')),
          ],
        ),
      ),
    );
  }
}
