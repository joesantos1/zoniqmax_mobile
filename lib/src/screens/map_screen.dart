import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_screen.dart';

/// Aba Mapa: mapa 2D (CartoDB) com a localização real do jogador. Carrega as zonas
/// por região visível (viewport) + as zonas do jogador, com cache por célula,
/// refresh incremental (delta `since`) e snapshot para abrir instantâneo.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.api,
    this.onCurrentZone,
    this.onOpenTerritory,
    this.refreshSignal = 0,
  });

  final ApiClient api;

  /// Chamado quando a zona atual do jogador é determinada (com a localização real).
  final void Function(MapTerritory zone, LatLng location)? onCurrentZone;

  /// Chamado ao tocar numa zona (abre a aba Território).
  final void Function(MapTerritory)? onOpenTerritory;

  /// Incrementado externamente (customização de zona OU seleção da aba do mapa)
  /// para disparar um refresh incremental barato — sem re-acionar o GPS.
  final int refreshSignal;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _fallback = LatLng(-23.55052, -46.633308); // São Paulo
  static const String _snapshotKey = 'map_snapshot_v1';
  static const double _boundsPadDeg = 0.03; // ~3 km de folga no viewport

  final MapController _mapController = MapController();
  LatLng? _userLocation;
  LatLng _initialCenter = _fallback;

  /// Cache de territórios por célula (cellKey) — fonte do render.
  final Map<String, MapTerritory> _byCell = {};
  String? _cursor; // maior updatedAt visto (delta `since`)
  MapTerritory? _currentZone;

  /// Vértices do hexágono memoizados por célula (centro+raio são fixos).
  final Map<String, List<LatLng>> _vertexCache = {};

  bool _loading = true;
  bool _usedFallback = false;
  bool _refreshing = false;
  String? _error;
  Timer? _debounce;

  List<MapTerritory> get _territories => _byCell.values.toList(growable: false);

  /// Move a câmera com segurança (após o frame; ignora se o mapa ainda não montou).
  void _centerOn(LatLng target, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(target, zoom);
      } catch (_) {}
    });
  }

  @override
  void initState() {
    super.initState();
    _hydrate().then((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MapScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshSignal != old.refreshSignal) _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ---- Localização ----

  Future<LatLng> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _usedFallback = true;
        return _lastKnownOr(_fallback);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _usedFallback = true;
        return _lastKnownOr(_fallback);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // timeout/erro: usa a última posição conhecida (não trava)
      return _lastKnownOr(_fallback, markFallback: true);
    }
  }

  Future<LatLng> _lastKnownOr(LatLng fb, {bool markFallback = false}) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
    } catch (_) {}
    if (markFallback) _usedFallback = true;
    return fb;
  }

  // ---- Carga / refresh ----

  /// Carga inicial: GPS (com timeout) → viewport completo + minhas zonas.
  Future<void> _load() async {
    setState(() {
      if (_byCell.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final location = await _determinePosition();
      _initialCenter = location;
      await _fetchViewport(location, _boundsAround(location), full: true);
      await _fetchMine();
      if (mounted) setState(() => _loading = false);
      _centerOn(location, 13);
      _persist();
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

  /// Refresh incremental (delta) reaproveitando a localização e o viewport atuais.
  Future<void> _refresh() async {
    final loc = _userLocation;
    if (loc == null) return _load();
    setState(() => _refreshing = true);
    try {
      await _fetchViewport(loc, _currentBounds() ?? _boundsAround(loc),
          full: false);
      _persist();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao atualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Re-adquire o GPS (jogador se deslocou), recarrega a região e recentraliza.
  Future<void> _recenterFresh() async {
    setState(() => _refreshing = true);
    try {
      final loc = await _determinePosition();
      _initialCenter = loc;
      await _fetchViewport(loc, _boundsAround(loc), full: true);
      await _fetchMine();
      _centerOn(loc, 15);
      _persist();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao localizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Busca as zonas do viewport. `full=true` reconcilia remoções (zonas que
  /// perderam governador) substituindo a fatia governada dentro dos limites.
  Future<void> _fetchViewport(
    LatLng location,
    ({double minLat, double minLng, double maxLat, double maxLng}) b, {
    required bool full,
  }) async {
    final list = await widget.api.mapView(
      lat: location.latitude,
      lng: location.longitude,
      minLat: b.minLat,
      minLng: b.minLng,
      maxLat: b.maxLat,
      maxLng: b.maxLng,
      since: full ? null : _cursor,
    );
    if (!mounted) return;
    setState(() {
      _userLocation = location;
      if (full) _removeGovernedWithin(b);
      _mergeAll(list);
    });
    final cur = _currentZone;
    if (cur != null) widget.onCurrentZone?.call(cur, location);
  }

  Future<void> _fetchMine() async {
    try {
      final mine = await widget.api.myZones();
      if (!mounted) return;
      setState(() => _mergeAll(mine));
    } catch (_) {
      // minhas zonas são secundárias — falha silenciosa
    }
  }

  /// Após um desafio: atualiza só a célula atual (sem mexer no zoom/posição).
  Future<void> _refreshCurrentCell() async {
    final loc = _userLocation;
    if (loc == null) return;
    try {
      final list = await widget.api.mapView(
        lat: loc.latitude,
        lng: loc.longitude,
        minLat: loc.latitude - 0.001,
        minLng: loc.longitude - 0.001,
        maxLat: loc.latitude + 0.001,
        maxLng: loc.longitude + 0.001,
      );
      if (!mounted) return;
      setState(() => _mergeAll(list));
      _persist();
    } catch (_) {}
  }

  // ---- Cache helpers ----

  void _mergeAll(List<MapTerritory> list) {
    for (final t in list) {
      _byCell[t.cacheKey] = t;
      _vertexCache.remove(t.cacheKey); // invalida (centro pode ter mudado? não, mas seguro)
      final iso = t.updatedAt?.toIso8601String();
      if (iso != null && (_cursor == null || iso.compareTo(_cursor!) > 0)) {
        _cursor = iso;
      }
    }
    _recomputeCurrentZone();
  }

  /// Remove zonas GOVERNADAS dentro do viewport (exceto a atual) antes de um
  /// refresh completo — assim zonas que perderam governador somem do mapa.
  void _removeGovernedWithin(
      ({double minLat, double minLng, double maxLat, double maxLng}) b) {
    _byCell.removeWhere((_, t) =>
        t.isGoverned &&
        !t.isCurrent &&
        t.centerLat >= b.minLat &&
        t.centerLat <= b.maxLat &&
        t.centerLng >= b.minLng &&
        t.centerLng <= b.maxLng);
  }

  void _recomputeCurrentZone() {
    MapTerritory? cur;
    for (final t in _byCell.values) {
      if (t.isCurrent) {
        cur = t;
        break;
      }
    }
    // fallback: mais próxima da localização (uma vez só, barato)
    if (cur == null && _userLocation != null && _byCell.isNotEmpty) {
      double best = double.infinity;
      for (final t in _byCell.values) {
        final d = distanceKm(_userLocation!, LatLng(t.centerLat, t.centerLng));
        if (d < best) {
          best = d;
          cur = t;
        }
      }
    }
    _currentZone = cur;
  }

  List<LatLng> _verticesFor(MapTerritory t) => _vertexCache.putIfAbsent(
        t.cacheKey,
        () => hexagonVertices(LatLng(t.centerLat, t.centerLng), t.radiusKm),
      );

  ({double minLat, double minLng, double maxLat, double maxLng}) _boundsAround(
      LatLng c) {
    const pad = 0.06; // ~6 km de raio na carga inicial
    return (
      minLat: c.latitude - pad,
      minLng: c.longitude - pad,
      maxLat: c.latitude + pad,
      maxLng: c.longitude + pad,
    );
  }

  ({double minLat, double minLng, double maxLat, double maxLng})?
      _currentBounds() {
    try {
      final b = _mapController.camera.visibleBounds;
      return (
        minLat: b.south - _boundsPadDeg,
        minLng: b.west - _boundsPadDeg,
        maxLat: b.north + _boundsPadDeg,
        maxLng: b.east + _boundsPadDeg,
      );
    } catch (_) {
      return null; // câmera ainda não montada
    }
  }

  // ---- Snapshot (cold start instantâneo) ----

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_snapshotKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cells = (data['cells'] as List?) ?? const [];
      for (final e in cells) {
        final t = MapTerritory.fromJson(e as Map<String, dynamic>);
        _byCell[t.cacheKey] = t;
      }
      _cursor = data['cursor'] as String?;
      final c = data['center'] as Map<String, dynamic>?;
      if (c != null) {
        _initialCenter = LatLng(
          (c['lat'] as num).toDouble(),
          (c['lng'] as num).toDouble(),
        );
      }
      _recomputeCurrentZone();
      if (mounted && _byCell.isNotEmpty) setState(() => _loading = false);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // limita o snapshot para não crescer indefinidamente
      final cells = _byCell.values.take(300).map((t) => t.toJson()).toList();
      final c = _userLocation ?? _initialCenter;
      await prefs.setString(
        _snapshotKey,
        jsonEncode({
          'cells': cells,
          'cursor': _cursor,
          'center': {'lat': c.latitude, 'lng': c.longitude},
        }),
      );
    } catch (_) {}
  }

  /// Rótulo relativo curto ("há 5 min", "há 2 h", "há 3 d") ou null.
  String? _agoLabel(DateTime? t) {
    if (t == null) return null;
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    return 'há ${d.inDays} d';
  }

  // ---- Navegação ----

  void _openTerritory(MapTerritory t) => widget.onOpenTerritory?.call(t);

  void _startChallenge(MapTerritory t) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChallengeScreen(
            api: widget.api,
            territoryId: t.id,
            userLat: _userLocation?.latitude,
            userLng: _userLocation?.longitude,
          ),
        ))
        .then((_) => _refreshCurrentCell()); // não recarrega tudo (preserva zoom)
  }

  /// Reage ao pan/zoom: ao assentar, recarrega as zonas da nova região (debounce).
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final loc = _userLocation;
      final b = _currentBounds();
      if (loc == null || b == null) return;
      _fetchViewport(loc, b, full: true).then((_) => _persist());
    });
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _byCell.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _byCell.isEmpty) {
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

    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _initialCenter,
            initialZoom: 13,
            onPositionChanged: _onPositionChanged,
          ),
          children: [
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
                final base = t.color != null
                    ? AppColors.zoneColor(t.color)
                    : (governed ? AppColors.red : AppColors.orange);
                return Polygon(
                  points: _verticesFor(t),
                  color: base.withValues(alpha: governed ? 0.28 : 0.18),
                  borderColor: base,
                  borderStrokeWidth: t.isCurrent ? 3 : (governed ? 2 : 1),
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
                onPressed: _refreshing ? null : _recenterFresh,
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
    final since = _agoLabel(zone.governorUpdatedAt);
    final String status;
    if (iAmGovernor) {
      status = '👑 Você governa esta zona — defenda sua posição!'
          '${since != null ? ' (capturada $since)' : ''}';
    } else if (zone.isGoverned) {
      status = 'Governada por ${zone.governorName}'
          '${since != null ? ' · capturada $since' : ''}. Dispute o domínio!';
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

/// Avatar do governador no centro do hexágono: foto (se houver, em cache) ou
/// inicial do nome, com contorno HQ e uma coroa indicando domínio.
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
                    image: CachedNetworkImageProvider(
                        territory.governorAvatarUrl!),
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
