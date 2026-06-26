import 'dart:async';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Widget que "joga" um desafio: mostra o enunciado, coleta a resposta e
/// controla o cronômetro. Ao submeter (manual ou por timeout), chama [onSubmit]
/// com a resposta e o tempo gasto em segundos.
class ChallengePlayer extends StatefulWidget {
  const ChallengePlayer({
    super.key,
    required this.challenge,
    required this.onSubmit,
    this.submitting = false,
  });

  final Challenge challenge;
  final bool submitting;
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
    super.dispose();
  }

  /// Converte a entrada de texto na resposta apropriada (número, lista ou string).
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

    final options = widget.challenge.options;
    final Object answer = options != null
        ? (_selectedOption ?? -1)
        : _parseTextAnswer(_textCtrl.text);

    final timeSpent = timedOut
        ? widget.challenge.baseTimeSeconds + 1 // garante timeout no servidor
        : (widget.challenge.baseTimeSeconds - _secondsLeft).clamp(0, 99999);

    widget.onSubmit(answer, timeSpent);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final options = challenge.options;
    final total = challenge.baseTimeSeconds;
    final progress = total == 0 ? 0.0 : (_secondsLeft / total).clamp(0.0, 1.0);
    final lowTime = _secondsLeft <= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ComicTag(label: challenge.area, color: AppColors.blue),
            const SizedBox(width: 8),
            ComicTag(label: 'NÍVEL ${challenge.difficulty}', color: AppColors.brown),
            const Spacer(),
            Text(
              '${_secondsLeft < 0 ? 0 : _secondsLeft}s',
              style: TextStyle(
                fontWeight: FontWeight.w900,
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
        const SizedBox(height: 20),
        ComicPanel(
          color: AppColors.paper,
          child: Text(
            challenge.prompt,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 20),
        if (options != null)
          ...List.generate(options.length, (i) {
            final selected = _selectedOption == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ComicPanel(
                color: selected ? AppColors.orange : AppColors.white,
                onTap: widget.submitting ? null : () => setState(() => _selectedOption = i),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        options[i],
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
        else
          TextField(
            controller: _textCtrl,
            enabled: !widget.submitting,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Sua resposta',
              hintText: 'Digite aqui (ex.: 32 ou A, B, C)',
            ),
            onSubmitted: (_) => _submit(),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.submitting ? null : () => _submit(),
          child: widget.submitting
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                )
              : const Text('RESPONDER'),
        ),
      ],
    );
  }
}
