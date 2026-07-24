import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'src/api_client.dart';
import 'src/referral_links.dart';
import 'src/theme.dart';
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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _referralSub;
  String? _pendingReferralCode;

  @override
  void initState() {
    super.initState();
    _bootstrapReferralCode();
    _listenDeepLinks();
    _api.loadToken(); // dispara o load — HomeShell escuta isLoggedIn
  }

  @override
  void dispose() {
    _referralSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapReferralCode() async {
    final cached = await readPendingReferralCode();
    if (mounted) {
      setState(() => _pendingReferralCode = cached);
    }
  }

  Future<void> _listenDeepLinks() async {
    final initial = await _appLinks.getInitialLink();
    await _handleIncomingReferralUri(initial);
    _referralSub = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingReferralUri(uri);
    });
  }

  Future<void> _handleIncomingReferralUri(Uri? uri) async {
    if (uri == null || !isReferralUri(uri)) return;
    final code = extractReferralCodeFromUri(uri);
    if (code == null) return;

    await savePendingReferralCode(code);
    if (mounted) {
      setState(() => _pendingReferralCode = code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZonIQmax',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeShell(
        api: _api,
        initialReferralCode: _pendingReferralCode,
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
