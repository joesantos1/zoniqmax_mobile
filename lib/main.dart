import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'src/api_client.dart';
import 'src/theme.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_shell.dart';

void main() {
  runApp(const ZonIQmaxApp());
}

class ZonIQmaxApp extends StatefulWidget {
  const ZonIQmaxApp({super.key});

  @override
  State<ZonIQmaxApp> createState() => _ZonIQmaxAppState();
}

class _ZonIQmaxAppState extends State<ZonIQmaxApp> {
  final ApiClient _api = ApiClient();
  late final Future<String?> _tokenFuture = _api.loadToken();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZonIQmax',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: FutureBuilder<String?>(
        future: _tokenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _BootScreen();
          }
          final hasToken = snapshot.data != null;
          return hasToken ? HomeShell(api: _api) : LoginScreen(api: _api);
        },
      ),
    );
  }
}

/// Tela de boot com a marca — handoff suave a partir do splash nativo laranja.
class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BrandColors.orange,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(LucideIcons.hexagon, size: 88, color: BrandColors.white),
                Text(
                  'Z',
                  style: TextStyle(
                    fontFamily: AppText.family,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: BrandColors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: BrandColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
