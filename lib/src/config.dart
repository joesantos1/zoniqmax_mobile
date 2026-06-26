/// Configuração do app.
///
/// Base URL da API ZonIQmax. Ajuste conforme o ambiente:
/// - Emulador Android: http://10.0.2.2:3000 (o host é 10.0.2.2 dentro do emulador)
/// - iOS Simulator / Desktop / Web: http://localhost:3000
/// - Dispositivo físico: http://<IP-da-sua-maquina>:3000
///
/// Pode ser sobrescrita em tempo de build com:
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
