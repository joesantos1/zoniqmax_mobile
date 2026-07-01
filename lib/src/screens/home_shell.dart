import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'ranking_tab.dart';
import 'territory_tab.dart';

/// Shell principal com BottomNavigationBar: Mapa, Território, Ranking, Perfil.
/// Mantém a "zona ativa" (atual do mapa ou a tocada) para as abas Território/Ranking.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _mapVersion = 0; // incrementado para forçar atualização do mapa
  MapTerritory? _active;

  // Presença: zona onde o jogador está fisicamente + sua localização real.
  MapTerritory? _currentZone;
  String? get _currentZoneId => _currentZone?.id;
  LatLng? _currentLocation;

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

  /// Está vendo um território DIFERENTE da sua zona atual?
  bool get _viewingOther =>
      _active != null && _active!.id != _currentZoneId;

  void _backToCurrent() {
    if (_currentZone != null) {
      _setActive(_currentZone!);
    } else {
      setState(() => _index = 0); // sem zona atual conhecida → volta ao mapa
    }
  }

  void _onTerritoryChanged() => setState(() => _mapVersion++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          MapScreen(
            api: widget.api,
            refreshSignal: _mapVersion,
            onCurrentZone: _onCurrentZone,
            onOpenTerritory: (t) => _setActive(t, open: true),
          ),
          TerritoryTab(
            key: ValueKey('terr-${_active?.id}'),
            api: widget.api,
            territoryId: _active?.id,
            isPresent: _active?.id != null && _active?.id == _currentZoneId,
            userLat: _currentLocation?.latitude,
            userLng: _currentLocation?.longitude,
            onChanged: _onTerritoryChanged,
            onBackToCurrent: _viewingOther ? _backToCurrent : null,
          ),
          RankingTab(
            key: ValueKey('rank-${_active?.id}'),
            api: widget.api,
            territoryId: _active?.id,
            onBackToCurrent: _viewingOther ? _backToCurrent : null,
          ),
          ProfileScreen(api: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          // ao (re)abrir a aba do mapa, dispara um refresh incremental barato
          if (i == 0 && _index != 0) _mapVersion++;
          _index = i;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.map), label: 'Mapa'),
          NavigationDestination(
              icon: Icon(LucideIcons.hexagon), label: 'Território'),
          NavigationDestination(
              icon: Icon(LucideIcons.trophy), label: 'Ranking'),
          NavigationDestination(icon: Icon(LucideIcons.user), label: 'Perfil'),
        ],
      ),
    );
  }
}
