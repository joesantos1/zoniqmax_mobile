import 'package:flutter/material.dart';

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
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final hasToken = snapshot.data != null;
          return hasToken ? HomeShell(api: _api) : LoginScreen(api: _api);
        },
      ),
    );
  }
}
