import 'package:flutter/material.dart';

/// Escala tipográfica do jogo — Nunito (bundled), pesada e arredondada.
/// Cores não são definidas aqui: herdam do DefaultTextStyle/tema ou são
/// aplicadas no ponto de uso via `copyWith(color: ...)`.
abstract final class AppText {
  static const family = 'Nunito';

  /// Números grandes de destaque (contadores hero).
  static const display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1.15,
  );

  /// Títulos de tela / perguntas de desafio.
  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// Títulos de seção e cartões.
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.4,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Timers, XP, placares — dígitos tabulares para não "dançar" ao contar.
  static const numeric = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
