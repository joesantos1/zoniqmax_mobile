import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'ranking_tab.dart';
import 'territory_tab.dart';

/// Shell principal com BottomNavigationBar: Mapa, Território, Ranking, Perfil.
/// Mantém a "zona ativa" (atual do mapa ou a tocada) para as abas Território/Ranking.
/// Gerencia estado de autenticação: guest pode ver mapa/territórios/rankings/perfis
/// públicos; ações que exigem identidade redirecionam ao login.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.api,
    this.initialReferralCode,
  });

  final ApiClient api;

  /// Código de indicação pendente (deep link), repassado ao LoginScreen.
  final String? initialReferralCode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _mapVersion = 0;
  MapTerritory? _active;

  // Presença: zona onde o jogador está fisicamente + sua localização real.
  MapTerritory? _currentZone;
  String? get _currentZoneId => _currentZone?.id;
  LatLng? _currentLocation;

  bool _isLoggedIn = false;
  StreamSubscription<String?>? _tokenSub;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await widget.api.loadToken();
    if (mounted) {
      setState(() => _isLoggedIn = widget.api.isLoggedIn);
    }
  }

  void _setActive(MapTerritory t, {bool open = false}) {
    setState(() {
      _active = t;
      if (open) _index = 1;
    });
  }

  void _onCurrentZone(MapTerritory t, LatLng location) {
    setState(() {
      _currentZone = t;
      _currentLocation = location;
    });
    if (_active == null) _setActive(t);
  }

  bool get _viewingOther =>
      _active != null && _active!.id != _currentZoneId;

  void _backToCurrent() {
    if (_currentZone != null) {
      _setActive(_currentZone!);
    } else {
      setState(() => _index = 0);
    }
  }

  void _onTerritoryChanged() => setState(() => _mapVersion++);

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
    _mapVersion++; // dispara refresh do mapa (agora com myZones)
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          api: widget.api,
          initialReferralCode: widget.initialReferralCode,
        ),
      ),
    );
    if (result == true && mounted) _onLoginSuccess();
  }

  /// Redireciona ao login; após autenticar, executa [then] (ex.: abrir desafio).
  Future<void> _requireLogin(VoidCallback? then) async {
    if (_isLoggedIn) {
      then?.call();
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          api: widget.api,
          initialReferralCode: widget.initialReferralCode,
        ),
      ),
    );
    if (result == true && mounted) {
      _onLoginSuccess();
      then?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          MapScreen(
            api: widget.api,
            refreshSignal: _mapVersion,
            isLoggedIn: _isLoggedIn,
            onRequireLogin: () => _requireLogin(null),
            onCurrentZone: _onCurrentZone,
            onOpenTerritory: (t) => _setActive(t, open: true),
          ),
          TerritoryTab(
            key: ValueKey('terr-${_active?.id}'),
            api: widget.api,
            territoryId: _active?.id,
            isPresent: _active?.id != null && _active?.id == _currentZoneId,
            isLoggedIn: _isLoggedIn,
            userLat: _currentLocation?.latitude,
            userLng: _currentLocation?.longitude,
            onRequireLogin: () => _requireLogin(null),
            onChanged: _onTerritoryChanged,
            onBackToCurrent: _viewingOther ? _backToCurrent : null,
          ),
          RankingTab(
            key: ValueKey('rank-${_active?.id}'),
            api: widget.api,
            territoryId: _active?.id,
            onBackToCurrent: _viewingOther ? _backToCurrent : null,
          ),
          _isLoggedIn
              ? ProfileScreen(api: widget.api)
              : _GuestProfilePlaceholder(onLogin: _openLogin),
        ],
      ),
      bottomNavigationBar: GameNavBar(
        selectedIndex: _index,
        onSelected: (i) => setState(() {
          if (i == 0 && _index != 0) _mapVersion++;
          _index = i;
        }),
        items: const [
          GameNavItem(icon: LucideIcons.map, label: 'Mapa'),
          GameNavItem(icon: LucideIcons.hexagon, label: 'Território'),
          GameNavItem(icon: LucideIcons.trophy, label: 'Ranking'),
          GameNavItem(icon: LucideIcons.user, label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Placeholder exibido na aba Perfil quando o visitante não está autenticado.
class _GuestProfilePlaceholder extends StatelessWidget {
  const _GuestProfilePlaceholder({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: zon.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.user, size: 36, color: zon.brand),
              ),
              const SizedBox(height: 24),
              Text(
                'Faça login para acessar seu perfil',
                textAlign: TextAlign.center,
                style: AppText.title.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Acumule XP, dispute territórios, enfrente duelos e acompanhe seu progresso.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: zon.onSurfaceMuted),
              ),
              const SizedBox(height: 24),
              GameButton(
                label: 'ENTRAR',
                icon: LucideIcons.logIn,
                expanded: true,
                onPressed: onLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
