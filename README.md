# ZonIQmax — Mobile (Flutter)

App do ZonIQmax, consumindo a API em [`../api`](../api). O código Dart (telas, modelos, cliente HTTP) **já está escrito** em `lib/`. Falta apenas gerar as pastas de plataforma (Android/iOS), que dependem do Flutter SDK instalado.

## Pré-requisito

Instale o **Flutter SDK** (https://docs.flutter.dev/get-started/install) e confirme:

```bash
flutter --version
flutter doctor
```

## Rodar o app

```bash
cd mobile

# 1. Gera as pastas de plataforma SEM sobrescrever lib/ e pubspec.yaml já existentes
flutter create .

# 2. Baixa as dependências (http, flutter_secure_storage)
flutter pub get

# 3. Sobe a API em outro terminal (ver ../api/README.md): npm run dev

# 4. Roda o app apontando para a API
#    - Emulador Android: o host da máquina é 10.0.2.2 (já é o default)
flutter run

#    - Dispositivo físico / outro host: informe a base URL
flutter run --dart-define=API_BASE_URL=http://SEU_IP:3000
```

> A base URL padrão é `http://10.0.2.2:3000` (emulador Android). Para iOS Simulator/desktop use `http://localhost:3000`. Veja [lib/src/config.dart](lib/src/config.dart).

## Estrutura

```
lib/
  main.dart                       entrada; decide login vs territórios pelo token salvo
  src/
    config.dart                   base URL da API (--dart-define=API_BASE_URL=...)
    models.dart                   Territory, TerritoryDetail, rankings, AuthResult
    api_client.dart               HTTP + JWT em flutter_secure_storage
    screens/
      login_screen.dart           login / cadastro
      territories_screen.dart     lista de territórios (mapa simplificado do MVP)
      territory_detail_screen.dart ranking geral (Governador) + por classe
```

## Telas implementadas (loop do MVP — seção 13 do doc)

- ✅ **Login / Cadastro** — email + senha, token persistido.
- ✅ **Territórios** — lista os territórios da API; pull-to-refresh; logout.
- ✅ **Detalhe do território** — ranking geral (com 👑 Governador) e líderes por classe.

## Próximas telas (a implementar)

- Mapa real com hexágonos (flutter_map / google_maps_flutter) usando lat/lng.
- Atividades: duelo cognitivo e desafio (consumindo `/challenges` e `/duels`).
- Perfil: XP por área e prestígio (`/me`).
