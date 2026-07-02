import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../theme.dart';
import 'games/anagram_game.dart';
import 'games/association_game.dart';
import 'games/balance_game.dart';
import 'games/decision_game.dart';
import 'games/memory_game.dart';
import 'games/ordering_game.dart';
import 'games/precision_game.dart';
import 'games/puzzle_game.dart';
import 'games/true_false_game.dart';
import 'games/word_search_game.dart';

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
  /// Tipos de resposta numérica: usam o GameNumpad em vez do teclado do sistema.
  static const _numpadTypes = {
    'CALCULO_MENTAL',
    'SEQUENCIA_LOGICA',
    'BALANCA_LOGICA',
  };

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
      // tique tátil nos últimos 5 segundos (sem alterar a lógica de tempo)
      if (!_submitted && _secondsLeft > 0 && _secondsLeft <= 5) {
        GameHaptics.tick();
      }
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
      case 'ORDENACAO_RAPIDA':
      case 'REACAO_PRECISAO':
      case 'VERDADEIRO_FALSO':
      case 'CACA_PALAVRAS':
        return _answer.value ?? <dynamic>[];
      case 'ASSOCIACAO_VISUAL':
      case 'MINI_PUZZLE':
        return _answer.value ?? <String, String>{};
      case 'TOMADA_DECISAO':
        return _answer.value ?? -1;
      case 'ANAGRAMA':
        return _answer.value ?? '';
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
      widget.challenge.type == 'MINI_PUZZLE' ||
      widget.challenge.type == 'ASSOCIACAO_VISUAL' ||
      widget.challenge.type == 'VERDADEIRO_FALSO' ||
      widget.challenge.type == 'CACA_PALAVRAS';

  /// Tipos cujo widget de jogo renderiza o próprio enunciado estilizado
  /// (o painel `_prompt()` padrão é pulado).
  bool get _rendersOwnPrompt =>
      widget.challenge.type == 'TOMADA_DECISAO' ||
      widget.challenge.type == 'ANAGRAMA';

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
                if (!_rendersOwnPrompt) ...[
                  _prompt(),
                  const SizedBox(height: 20),
                ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GameChip(
                  label: challenge.area,
                  color: areaColor(challenge.area),
                  icon: areaIcon(challenge.area),
                  mode: GameChipMode.tonal),
              GameChip(
                  label: 'NÍVEL ${challenge.difficulty}',
                  color: AppColors.brown,
                  mode: GameChipMode.tonal),
              if (challenge.theme != null && challenge.theme!.isNotEmpty)
                GameChip(
                    label: challenge.theme!,
                    color: AppColors.orange,
                    mode: GameChipMode.tonal),
              if (challenge.replay)
                const GameChip(
                    label: 'REVISÃO · ½ tempo',
                    color: AppColors.red,
                    icon: LucideIcons.repeat),
              if (challenge.bonusSeconds > 0)
                GameChip(
                    label: 'BÔNUS +${challenge.bonusSeconds}s',
                    color: AppColors.green,
                    icon: LucideIcons.gift),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TimerRing(
          totalSeconds: challenge.baseTimeSeconds,
          secondsLeft: _secondsLeft,
          running: !_submitted && !widget.answered && !widget.submitting,
        ),
      ],
    );
  }

  Widget _prompt() {
    return GamePanel(
      child: Text(
        widget.challenge.prompt,
        style: AppText.headline.copyWith(fontSize: 21),
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
      case 'REACAO_PRECISAO':
        return PrecisionGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
        );
      case 'VERDADEIRO_FALSO':
        return TrueFalseGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
          onComplete: () {
            if (!_submitted) _submit();
          },
        );
      case 'CACA_PALAVRAS':
        return WordSearchGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
          onComplete: () {
            if (!_submitted) _submit();
          },
        );
      case 'ANAGRAMA':
        return AnagramGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
        );
      case 'TOMADA_DECISAO':
        return DecisionGame(
          challenge: widget.challenge,
          answer: _answer,
          locked: locked,
        );
      case 'BALANCA_LOGICA':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalanceBoard(challenge: widget.challenge),
            const SizedBox(height: 8),
            _numericAnswerArea(locked),
          ],
        );
    }

    final options = widget.challenge.options;
    if (options != null) {
      final zon = context.zon;
      const letters = 'ABCDEFGH';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(options.length, (i) {
          final selected = _selectedOption == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GamePressable(
              onTap: locked ? null : () => setState(() => _selectedOption = i),
              faceColor: selected
                  ? Color.alphaBlend(
                      zon.brand.withValues(alpha: 0.12), zon.surface)
                  : zon.surface,
              borderColor: selected ? zon.brand : zon.outline,
              edgeColor: selected ? zon.brandEdge : zon.neutralEdge,
              borderWidth: selected ? 2.5 : 2,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected ? zon.brand : zon.surfaceAlt,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i < letters.length ? letters[i] : '${i + 1}',
                      style: AppText.label.copyWith(
                        color:
                            selected ? zon.onBrand : zon.onSurfaceMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      options[i],
                      style: AppText.bodyStrong.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    }
    if (_numpadTypes.contains(widget.challenge.type)) {
      return _numericAnswerArea(locked);
    }
    return TextField(
      controller: _textCtrl,
      enabled: !locked,
      autofocus: true,
      style: AppText.bodyStrong.copyWith(fontSize: 18),
      decoration: const InputDecoration(
        labelText: 'Sua resposta',
        hintText: 'Digite aqui (ex.: 32 ou A, B, C)',
      ),
      onSubmitted: locked ? null : (_) => _submit(),
    );
  }

  /// Resposta numérica: display da resposta + numpad do jogo (sem teclado do
  /// sistema). O texto vai para o mesmo [_textCtrl] — parse e submissão iguais.
  Widget _numericAnswerArea(bool locked) {
    final zon = context.zon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GamePanel(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (context, value, _) => Text(
              value.text.isEmpty ? '—' : value.text,
              textAlign: TextAlign.center,
              style: AppText.numeric.copyWith(
                fontSize: 28,
                color: value.text.isEmpty
                    ? zon.onSurfaceMuted
                    : zon.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GameNumpad(controller: _textCtrl, enabled: !locked),
      ],
    );
  }

  Widget _bottomButton(bool answered) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GameButton(
          label: answered ? 'PRÓXIMO' : 'RESPONDER',
          icon: answered ? LucideIcons.arrowRight : null,
          variant: answered
              ? GameButtonVariant.success
              : GameButtonVariant.primary,
          size: GameButtonSize.lg,
          expanded: true,
          loading: widget.submitting,
          onPressed: answered
              ? widget.onNext
              : (widget.submitting ? null : () => _submit()),
        ),
      ),
    );
  }
}
