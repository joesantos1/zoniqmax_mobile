import 'package:flutter/services.dart';

/// Feedback tátil do jogo — mapeia eventos de gameplay para haptics nativos.
/// Tudo fire-and-forget: nunca bloqueia UI nem lança erro em devices sem motor.
abstract final class GameHaptics {
  /// Toque em botões/opções.
  static void tap() {
    HapticFeedback.selectionClick();
  }

  /// Resposta correta / peça encaixada.
  static void correct() {
    HapticFeedback.lightImpact();
  }

  /// Resposta errada / par incorreto.
  static void wrong() {
    HapticFeedback.mediumImpact();
  }

  /// Tempo esgotado.
  static void timeout() {
    HapticFeedback.mediumImpact();
  }

  /// Tique dos últimos segundos do timer.
  static void tick() {
    HapticFeedback.selectionClick();
  }

  /// Celebração (streak, jogo completo): "duplo baque".
  static Future<void> celebrate() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
  }

  /// Conquista de território / vitória em duelo.
  static Future<void> conquest() => celebrate();
}
