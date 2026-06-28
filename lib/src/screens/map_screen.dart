import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_screen.dart';

/// Aba Mapa: mapa 2D (OSM) com a localização real do jogador. Mostra a zona atual
/// e as zonas governadas. Toque numa zona abre a aba Território (via callback).
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.api,
    this.onCurrentZone,
    this.onOpenTerritory,
    this.refreshSignal = 0,
  });

  final ApiClient api;

  /// Chamado quando a zona atual do jogador é determinada.
  final void Function(MapTerritory)? onCurrentZone;

  /// Chamado ao tocar numa zona (abre a aba Território).
  final void Function(MapTerritory)? onOpenTerritory;

  /// Incrementado externamente para forçar uma atualização do mapa (ex.: após
  /// personalizar uma zona). Reaproveita a localização em cache (sem re-disparar GPS).
  final int refreshSignal;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _fallback = LatLng(-23.55052, -46.633308); // São Paulo

  final MapController _mapController = MapController();
  LatLng? _userLocation;
  List<MapTerritory> _territories = [];
  bool _loading = true;
  bool _usedFallback = false;
  String? _error;

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MapScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshSignal != old.refreshSignal) _refresh();
  }

  Future<LatLng> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _usedFallback = true;
        return _fallback;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _usedFallback = true;
        return _fallback;
      }
      final pos = await Geolocator.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      _usedFallback = true;
      return _fallback;
    }
  }

  /// Busca os territórios para uma localização (sem GPS). Atualiza estado e notifica
  /// a zona atual. Centralização inicial vem de `initialCenter`.
  Future<void> _fetchTerritories(LatLng location) async {
    final territories = await widget.api.territoriesNear(
      location.latitude,
      location.longitude,
      rings: 2,
    );
    if (!mounted) return;
    setState(() {
      _userLocation = location;
      _territories = territories;
    });
    final cur = _currentZone;
    if (cur != null) widget.onCurrentZone?.call(cur);
  }

  /// Carga inicial: adquire o GPS (lento) e busca os territórios.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await _determinePosition();
      await _fetchTerritories(location);
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Falha ao carregar o mapa: $e';
          _loading = false;
        });
      }
    }
  }

  /// Atualização rápida: reaproveita a localização em cache (sem GPS).
  Future<void> _refresh() async {
    final loc = _userLocation;
    if (loc == null) return _load();
    setState(() => _refreshing = true);
    try {
      await _fetchTerritories(loc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao atualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openTerritory(MapTerritory t) => widget.onOpenTerritory?.call(t);

  void _startChallenge(MapTerritory t) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChallengeScreen(api: widget.api, territoryId: t.id),
        ))
        .then((_) => _load());
  }

  /// Zona onde o jogador está: a marcada como atual pelo servidor (ou, em último
  /// caso, a mais próxima do jogador).
  MapTerritory? get _currentZone {
    if (_territories.isEmpty) return null;
    for (final t in _territories) {
      if (t.isCurrent) return t;
    }
    final loc = _userLocation;
    if (loc == null) return null;
    MapTerritory? nearest;
    double best = double.infinity;
    for (final t in _territories) {
      final d = distanceKm(loc, LatLng(t.centerLat, t.centerLng));
      if (d < best) {
        best = d;
        nearest = t;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }

    final center = _userLocation ?? _fallback;
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 13),
          children: [
            // Basemap claro e minimalista (CartoDB Positron): ruas + nomes,
            // sem a poluição de lojas/POIs do OSM padrão — mais leve e legível.
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.zoniqmax.app',
              maxZoom: 19,
            ),
            PolygonLayer(
              polygons: _territories.map((t) {
                final governed = t.isGoverned;
                // cor personalizada do governador, se houver
                final base = t.color != null
                    ? AppColors.zoneColor(t.color)
                    : (governed ? AppColors.red : AppColors.orange);
                return Polygon(
                  points: hexagonVertices(
                    LatLng(t.centerLat, t.centerLng),
                    t.radiusKm,
                  ),
                  color: base.withValues(alpha: governed ? 0.28 : 0.18),
                  borderColor: base,
                  borderStrokeWidth: t.isCurrent ? 4 : (governed ? 3.5 : 2),
                );
              }).toList(),
            ),
            MarkerLayer(
              markers: [
                for (final t in _territories)
                  Marker(
                    point: LatLng(t.centerLat, t.centerLng),
                    width: 52,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => _openTerritory(t),
                      child: t.isGoverned
                          ? _GovernorBadge(territory: t)
                          : Icon(
                              t.iconName != null
                                  ? zoneIcon(t.iconName)
                                  : (t.isCurrent
                                      ? LucideIcons.mapPin
                                      : LucideIcons.hexagon),
                              color: t.color != null
                                  ? AppColors.zoneColor(t.color)
                                  : AppColors.orange,
                              size: t.isCurrent ? 30 : 26,
                            ),
                    ),
                  ),
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(
          right: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xAAFFFFFF)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                '© OpenStreetMap · CARTO',
                style: TextStyle(fontSize: 9, color: AppColors.ink),
              ),
            ),
          ),
        ),
        if (_usedFallback)
          Positioned(
            left: 12,
            right: 12,
            top: topPad + 8,
            child: const ComicPanel(
              color: AppColors.orange,
              padding: EdgeInsets.all(10),
              child: Text(
                'GPS indisponível — mostrando uma área padrão. Permita a localização para ver seus territórios.',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
          ),
        // botões de atualizar e recentralizar (área segura no topo)
        Positioned(
          right: 12,
          top: topPad + (_usedFallback ? 80 : 12),
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'refresh',
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.paper,
                onPressed: _refreshing ? null : _refresh,
                child: _refreshing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.paper),
                      )
                    : const Icon(LucideIcons.refreshCw, size: 18),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.ink,
                onPressed: _userLocation == null
                    ? null
                    : () => _mapController.move(_userLocation!, 13),
                child: const Icon(LucideIcons.locateFixed, size: 18),
              ),
            ],
          ),
        ),
        if (_currentZone != null) _buildZoneCta(_currentZone!),
      ],
    );
  }

  /// Painel fixo no rodapé com a zona atual e a ação principal: iniciar desafios
  /// para subir influência. Destaca quando o jogador ainda não é o governador.
  Widget _buildZoneCta(MapTerritory zone) {
    final iAmGovernor = zone.governorUserId != null &&
        zone.governorUserId == widget.api.currentUserId;
    final String status;
    if (iAmGovernor) {
      status = '👑 Você governa esta zona — defenda sua posição!';
    } else if (zone.isGoverned) {
      status = 'Governada por ${zone.governorName}. Dispute o domínio!';
    } else {
      status = 'Zona livre — seja o primeiro a dominá-la!';
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: ComicPanel(
        color: AppColors.paper,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.mapPin, color: AppColors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Você está em ${zone.displayName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(status, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _startChallenge(zone),
                    child: Text(
                      iAmGovernor ? 'DEFENDER (DESAFIOS)' : 'INICIAR DESAFIOS',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _openTerritory(zone),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ink, width: 2),
                    foregroundColor: AppColors.ink,
                  ),
                  child: const Text('VER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar do governador no centro do hexágono: foto (se houver) ou inicial do nome,
/// com contorno HQ e uma coroa indicando domínio.
class _GovernorBadge extends StatelessWidget {
  const _GovernorBadge({required this.territory});

  final MapTerritory territory;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = territory.governorAvatarUrl != null &&
        territory.governorAvatarUrl!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.crown, color: AppColors.red, size: 15),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 2.5),
            image: hasPhoto
                ? DecorationImage(
                    image: NetworkImage(territory.governorAvatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: hasPhoto
              ? null
              : Text(
                  territory.governorInitial,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ],
    );
  }
}
