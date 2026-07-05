import 'package:flutter/material.dart';

import '../theme.dart';

/// Caixas de código estilo 2FA: exibem os dígitos do [controller]
/// (preenchido pelo GameNumpad), com a posição atual destacada.
class CodeBoxes extends StatelessWidget {
  const CodeBoxes({super.key, required this.controller, this.length = 6});

  final TextEditingController controller;
  final int length;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == length - 1 ? 0 : 8),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 42,
                  height: 52,
                  decoration: BoxDecoration(
                    color: i < text.length
                        ? Color.alphaBlend(
                            zon.brand.withValues(alpha: 0.10), zon.surface)
                        : zon.surfaceAlt,
                    borderRadius: BorderRadius.circular(Corners.sm),
                    border: Border.all(
                      color: i == text.length
                          ? zon.brand // próxima posição a digitar
                          : (i < text.length ? zon.brand : zon.outline),
                      width: i == text.length ? 2.5 : 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    i < text.length ? text[i] : '',
                    style: AppText.numeric.copyWith(fontSize: 22),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
