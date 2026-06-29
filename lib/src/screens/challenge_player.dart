import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../theme.dart';
import 'games/association_game.dart';
import 'games/memory_game.dart';
import 'games/ordering_game.dart';
import 'games/puzzle_game.dart';

/// Widget que "joga" um desafio: enunciado, coleta da resposta e cronômetro.
/// O botão de ação fica FIXO no rodapé (grande, fácil de tocar):
///  - antes de responder: "RESPONDER" → chama [onSubmit];
///  - depois de responder ([answered] = true): mostra [resultBanner] inline e o
///    botão vira "PRÓXIMO" → chama [onNext] (sem trocar de tela / sem refresh).
class ChallengePlayer extends StatefulWidget {
  const ChallengePlayer({
    super.key,
    required this.challenge,
    required this.onSubmit,
    this.submitting = false,
    this.answered = false,
    this.resultBanner,
    this.onNext,
  });

  final Challenge challenge;
  final bool submitting;
  final bool answered;
  final Widget? resultBanner;
  final VoidCallback? onNext;
  final void Function(Object answer, int timeSpentSeconds) onSubmit;

  @override
  State<ChallengePlayer> createState() => _ChallengePlayerState();
}

class _ChallengePlayerState extends State<ChallengePlayer> {
  Timer? _timer;
  late int _secondsLeft;
  int? _selectedOption;
  final _textCtrl = TextEditingController();
  bool _submitted = false;

  /// Resposta estruturada dos jogos interativos (ordenação, associação, memória).
  final ValueNotifier<Object?> _answer = ValueNotifier<Object?>(null);

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.challenge.baseTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) _submit(timedOut: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textCtrl.dispose();
    _answer.dispose();
    super.dispose();
  }

  /// Reúne a resposta conforme o tipo do desafio.
  Object _gatherAnswer() {
    switch (widget.challenge.type) {
      case 'MEMORIA_VISUAL':
        return _answer.value ?? <dynamic>[];
      case 'ORDENACAO_RAPIDA':
        return _answer.value ?? <dynamic>[];
      case 'ASSOCIACAO_VISUAL':
      case 'MINI_PUZZLE':
        return _answer.value ?? <String, String>{};
      default:
        final options = widget.challenge.options;
        if (options != null) return _selectedOption ?? -1;
        return _parseTextAnswer(_textCtrl.text);
    }
  }

  Object _parseTextAnswer(String raw) {
    final t = raw.trim();
    final asInt = int.tryParse(t);
    if (asInt != null) return asInt;
    final asNum = num.tryParse(t.replaceAll(',', '.'));
    if (asNum != null) return asNum;
    if (t.contains(',')) {
      return t.split(',').map((e) {
        final s = e.trim();
        return int.tryParse(s) ?? s;
      }).toList();
    }
    return t;
  }

  void _submit({bool timedOut = false}) {
    if (_submitted) return;
    _submitted = true;
    _timer?.cancel();

    final Object answer = _gatherAnswer();

    final timeSpent = timedOut
        ? widget.challenge.baseTimeSeconds + 1
        : (widget.challenge.baseTimeSeconds - _secondsLeft).clamp(0, 99999);

    widget.onSubmit(answer, timeSpent);
  }

  /// Tipos que ocupam toda a área visível (sem rolagem).
  bool get _fillsViewport =>
      widget.challenge.type == 'MEMORIA_VISUAL' ||
      widget.challenge.type == 'MINI_PUZZLE';

  @override
  Widget build(BuildContext context) {
    final answered = widget.answered;

    if (_fillsViewport) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: (answered && widget.resultBanner != null)
                ? widget.resultBanner!
                : _timerHeader(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _answerArea(answered),
            ),
          ),
          _bottomButton(answered),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (answered && widget.resultBanner != null) ...[
                  widget.resultBanner!,
                  const SizedBox(height: 16),
                ] else
                  _timerHeader(),
                const SizedBox(height: 16),
                _prompt(),
                const SizedBox(height: 20),
                _answerArea(answered),
              ],
            ),
          ),
        ),
        _bottomButton(answered),
      ],
    );
  }

  Widget _timerHeader() {
    final challenge = widget.challenge;
    final total = challenge.baseTimeSeconds;
    final progress = total == 0 ? 0.0 : (_secondsLeft / total).clamp(0.0, 1.0);
    final lowTime = _secondsLeft <= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ComicTag(label: challenge.area, color: AppColors.blue),
                  ComicTag(
                      label: 'NÍVEL ${challenge.difficulty}',
                      color: AppColors.brown),
                  if (challenge.theme != null && challenge.theme!.isNotEmpty)
                    ComicTag(label: challenge.theme!, color: AppColors.orange),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_secondsLeft < 0 ? 0 : _secondsLeft}s',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: lowTime ? AppColors.red : AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.paperDark,
            color: lowTime ? AppColors.red : AppColors.orange,
          ),
        ),
      ],
    );
  }

  Widget _prompt() {
    return ComicPanel(
      color: AppColors.paper,
      child: Text(
        widget.challenge.prompt,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _answerArea(bool answered) {
    final locked = answered || widget.submitting;

    switch (widget.challenge.type) {
      case 'MEMORIA_VISUAL':
        return MemoryGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
          onComplete: () {
            if (!_submitted) _submit();
          },
        );
      case 'ORDENACAO_RAPIDA':
        return OrderingGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
        );
      case 'ASSOCIACAO_VISUAL':
        return AssociationGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
        );
      case 'MINI_PUZZLE':
        return PuzzleGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
        );
    }

    final options = widget.challenge.options;
    if (options != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(options.length, (i) {
          final selected = _selectedOption == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ComicPanel(
              color: selected ? AppColors.orange : AppColors.white,
              onTap: locked ? null : () => setState(() => _selectedOption = i),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? LucideIcons.circleDot
                        : LucideIcons.circle,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      options[i],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    }
    return TextField(
      controller: _textCtrl,
      enabled: !locked,
      autofocus: true,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        labelText: 'Sua resposta',
        hintText: 'Digite aqui (ex.: 32 ou A, B, C)',
      ),
      onSubmitted: locked ? null : (_) => _submit(),
    );
  }

  Widget _bottomButton(bool answered) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 22),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            onPressed: answered
                ? widget.onNext
                : (widget.submitting ? null : () => _submit()),
            child: widget.submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.ink),
                  )
                : Text(answered ? 'PRÓXIMO ▶' : 'RESPONDER'),
          ),
        ),
      ),
    );
  }
}
