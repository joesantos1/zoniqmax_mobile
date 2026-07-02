import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models.dart';
import '../../theme.dart';

/// Balança lógica — apenas a APRESENTAÇÃO das balanças (a resposta numérica
/// vem do GameNumpad, fora deste widget). Cada balança mostra os símbolos dos
/// dois pratos equilibrados.
class BalanceBoard extends StatelessWidget {
  const BalanceBoard({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final balancas = ((challenge.data['balancas'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < balancas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GamePanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: _Pan(
                      symbols: ((balancas[i]['esquerda'] as List?) ?? const [])
                          .map((e) => e.toString())
                          .toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(LucideIcons.scale,
                        size: 22, color: zon.onSurfaceMuted),
                  ),
                  Expanded(
                    child: _Pan(
                      symbols: ((balancas[i]['direita'] as List?) ?? const [])
                          .map((e) => e.toString())
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Prato da balança: os símbolos como chips + a barra do prato por baixo.
class _Pan extends StatelessWidget {
  const _Pan({required this.symbols});

  final List<String> symbols;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final s in symbols)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: zon.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: zon.outline, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(s,
                    style: AppText.bodyStrong
                        .copyWith(fontSize: 18, height: 1)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // barra do prato
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: zon.outline,
            borderRadius: BorderRadius.circular(Corners.pill),
          ),
        ),
      ],
    );
  }
}
