import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';

/// Teclado numérico do jogo (substitui o teclado do sistema em desafios de
/// resposta numérica). Manipula o [controller] diretamente, então o parse e o
/// fluxo de submissão do ChallengePlayer ficam intocados.
class GameNumpad extends StatelessWidget {
  const GameNumpad({
    super.key,
    required this.controller,
    this.enabled = true,
    this.allowDecimal = true,
    this.allowNegative = true,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool allowDecimal;
  final bool allowNegative;

  void _append(String ch) {
    final t = controller.text;
    if (ch == ',' && (t.isEmpty || t.contains(','))) return;
    controller.text = t + ch;
  }

  void _backspace() {
    final t = controller.text;
    if (t.isNotEmpty) controller.text = t.substring(0, t.length - 1);
  }

  void _toggleSign() {
    final t = controller.text;
    controller.text = t.startsWith('-') ? t.substring(1) : '-$t';
  }

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap,
        {IconData? icon,
        VoidCallback? onLongPress,
        bool accent = false,
        int flex = 1}) {
      final zon = context.zon;
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: GestureDetector(
            onLongPress: enabled ? onLongPress : null,
            child: GamePressable(
              onTap: enabled ? onTap : null,
              faceColor: accent
                  ? Color.alphaBlend(
                      zon.brand.withValues(alpha: 0.10), zon.surface)
                  : zon.surface,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 50,
                child: Center(
                  child: icon != null
                      ? Icon(icon,
                          size: 20,
                          color: enabled
                              ? zon.onSurface
                              : zon.onSurfaceMuted)
                      : Text(
                          label,
                          style: AppText.numeric.copyWith(
                            fontSize: 20,
                            color: enabled
                                ? zon.onSurface
                                : zon.onSurfaceMuted,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget spacer() => const Expanded(child: SizedBox.shrink());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          key('1', () => _append('1')),
          key('2', () => _append('2')),
          key('3', () => _append('3')),
          key('⌫', _backspace,
              icon: LucideIcons.delete,
              onLongPress: () => controller.clear(),
              accent: true),
        ]),
        Row(children: [
          key('4', () => _append('4')),
          key('5', () => _append('5')),
          key('6', () => _append('6')),
          if (allowNegative)
            key('−', _toggleSign, accent: true)
          else
            spacer(),
        ]),
        Row(children: [
          key('7', () => _append('7')),
          key('8', () => _append('8')),
          key('9', () => _append('9')),
          if (allowDecimal)
            key(',', () => _append(','), accent: true)
          else
            spacer(),
        ]),
        Row(children: [
          spacer(),
          key('0', () => _append('0'), flex: 2),
          spacer(),
        ]),
      ],
    );
  }
}
