import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models.dart';
import '../../theme.dart';

/// Anagrama: letras embaralhadas em blocos — toque para preencher os espaços e
/// formar a palavra a partir da dica; toque num espaço preenchido para devolver
/// a letra. Escreve em [answer] a string montada (maiúscula).
/// Renderiza o próprio enunciado (painel da dica) — está em _rendersOwnPrompt.
class AnagramGame extends StatefulWidget {
  const AnagramGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;

  @override
  State<AnagramGame> createState() => _AnagramGameState();
}

class _AnagramGameState extends State<AnagramGame> {
  late final String _letras;

  /// Cada espaço guarda o ÍNDICE da letra da bandeja usada (ou null) — assim
  /// letras repetidas são distinguíveis.
  late final List<int?> _slots;

  String get _dica => (widget.challenge.data['dica'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _letras =
        ((widget.challenge.data['letras'] as String?) ?? '').toUpperCase();
    _slots = List<int?>.filled(_letras.length, null);
    widget.answer.value = '';
  }

  Set<int> get _usedTray => _slots.whereType<int>().toSet();

  void _publish() {
    widget.answer.value =
        _slots.map((i) => i == null ? '' : _letras[i]).join();
  }

  /// Envia a letra da bandeja para o primeiro espaço vazio.
  void _pick(int trayIndex) {
    if (widget.locked || _usedTray.contains(trayIndex)) return;
    final empty = _slots.indexOf(null);
    if (empty < 0) return;
    GameHaptics.tap();
    setState(() {
      _slots[empty] = trayIndex;
      _publish();
    });
  }

  /// Devolve a letra do espaço para a bandeja.
  void _clearSlot(int slotIndex) {
    if (widget.locked || _slots[slotIndex] == null) return;
    GameHaptics.tap();
    setState(() {
      _slots[slotIndex] = null;
      _publish();
    });
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final n = _letras.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // painel da dica
        GamePanel(
          color: Color.alphaBlend(
              zon.info.withValues(alpha: 0.08), zon.surface),
          borderColor: zon.info.withValues(alpha: 0.35),
          shadow: false,
          child: Row(
            children: [
              Icon(LucideIcons.lightbulb, size: 18, color: zon.info),
              const SizedBox(width: 8),
              GameChip(
                  label: 'DICA', color: zon.info, mode: GameChipMode.tonal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_dica,
                    style: AppText.bodyStrong.copyWith(fontSize: 15)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // espaços da palavra
        LayoutBuilder(
          builder: (context, c) {
            const gap = 6.0;
            final size =
                ((c.maxWidth - gap * (n - 1)) / n).clamp(28.0, 44.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++)
                  Padding(
                    padding:
                        EdgeInsets.only(right: i == n - 1 ? 0 : gap),
                    child: GestureDetector(
                      onTap: () => _clearSlot(i),
                      child: Container(
                        width: size,
                        height: size + 6,
                        decoration: BoxDecoration(
                          color: _slots[i] != null
                              ? Color.alphaBlend(
                                  zon.brand.withValues(alpha: 0.10),
                                  zon.surface)
                              : zon.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            bottom: BorderSide(
                              color: _slots[i] != null
                                  ? zon.brand
                                  : zon.outline,
                              width: 3,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _slots[i] == null
                            ? null
                            : Text(
                                _letras[_slots[i]!],
                                style: AppText.numeric.copyWith(
                                  fontSize: size * 0.5,
                                  color: zon.onSurface,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        // bandeja de letras embaralhadas
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              Opacity(
                opacity: _usedTray.contains(i) ? 0.25 : 1,
                child: GamePressable(
                  onTap: widget.locked || _usedTray.contains(i)
                      ? null
                      : () => _pick(i),
                  haptic: false, // haptic disparado no _pick
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 44,
                    height: 46,
                    child: Center(
                      child: Text(
                        _letras[i],
                        style: AppText.numeric.copyWith(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
