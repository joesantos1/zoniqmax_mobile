import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_player.dart';

/// Tela de desafio solo (caminho Pesquisador). Busca um desafio, joga e mostra o resultado.
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.api,
    this.territoryId,
    this.area,
  });

  final ApiClient api;
  final String? territoryId;
  final String? area;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late Future<Challenge> _future;
  bool _submitting = false;
  AttemptResult? _result;

  @override
  void initState() {
    super.initState();
    _future = widget.api.nextChallenge(area: widget.area);
  }

  void _restart() {
    setState(() {
      _result = null;
      _submitting = false;
      _future = widget.api.nextChallenge(area: widget.area);
    });
  }

  Future<void> _submit(Challenge challenge, Object answer, int timeSpent) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.api.submitAttempt(
        challenge.id,
        answer: answer,
        timeSpentSeconds: timeSpent,
        territoryId: widget.territoryId,
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
      appBar: AppBar(title: const Text('DESAFIO')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _result != null
            ? _ResultView(result: _result!, onAgain: _restart)
            : FutureBuilder<Challenge>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorBox(message: '${snapshot.error}', onRetry: _restart);
                  }
                  final challenge = snapshot.data!;
                  return SingleChildScrollView(
                    child: ChallengePlayer(
                      challenge: challenge,
                      submitting: _submitting,
                      onSubmit: (answer, time) => _submit(challenge, answer, time),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onAgain});

  final AttemptResult result;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final ok = result.success;
    final color = ok ? AppColors.blue : AppColors.red;
    final title = ok
        ? 'ACERTOU!'
        : result.timedOut
            ? 'TEMPO ESGOTADO!'
            : 'ERROU!';

    return Center(
      child: ComicPanel(
        color: AppColors.paper,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.bolt : Icons.close, size: 64, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 16),
            _row('Pontuação', result.score.toStringAsFixed(0)),
            _row('XP (${result.area})', '+${result.xpAwarded.toStringAsFixed(0)}'),
            if (result.classScoreAwarded > 0)
              _row('Pesquisador', '+${result.classScoreAwarded.toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAgain, child: const Text('PRÓXIMO DESAFIO')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 24),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
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
