import 'dart:async';
import 'dart:convert';

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
import 'challenge_setup_screen.dart';
import 'hex_background_layer.dart';

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
  // snapshot por USUÁRIO — evita vazar o mapa de uma conta para outra
  String get _snapshotKey =>
      'map_snapshot_v1_${widget.api.currentUserId ?? 'anon'}';
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
  bool _sheetCollapsed = false; // sheet da zona atual (expandido/colapsado)
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
          builder: (_) => ChallengeSetupScreen(
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
      return EmptyState(
        icon: LucideIcons.mapPinOff,
        title: 'Não deu para carregar o mapa',
        message: _error,
        action: GameButton(
          label: 'TENTAR DE NOVO',
          icon: LucideIcons.refreshCw,
          onPressed: _load,
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
              // Voyager: basemap quente e lúdico (estilo Waze).
              // Fallback neutro: 'light_all' no lugar de 'rastertiles/voyager'.
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.zoniqmax.app',
              maxZoom: 19,
            ),
            // imagem de fundo do governador, recortada no hexágono (transparente)
            HexBackgroundLayer(territories: _territories),
            PolygonLayer(
              polygons: [
                for (final t in _territories) ...[
                  // "casing" branco por baixo da zona atual — brilho estilo
                  // Waze destacando onde o jogador está (custa 1 polígono).
                  if (t.isCurrent)
                    Polygon(
                      points: _verticesFor(t),
                      borderColor:
                          AppColors.white.withValues(alpha: 0.9),
                      borderStrokeWidth: 7,
                    ),
                  () {
                    final governed = t.isGoverned;
                    final hasBg = t.backgroundUrl != null &&
                        t.backgroundUrl!.isNotEmpty;
                    final base = t.color != null
                        ? AppColors.zoneColor(t.color)
                        : (governed ? AppColors.red : AppColors.orange);
                    return Polygon(
                      points: _verticesFor(t),
                      // com imagem de fundo, quase sem preenchimento
                      color: base.withValues(
                          alpha: hasBg ? 0.06 : (governed ? 0.28 : 0.18)),
                      borderColor: base,
                      borderStrokeWidth:
                          t.isCurrent ? 3.5 : (governed ? 2.5 : 2),
                    );
                  }(),
                ],
              ],
            ),
            MarkerLayer(
              markers: [
                for (final t in _territories)
                  Marker(
                    point: LatLng(t.centerLat, t.centerLng),
                    width: 56,
                    height: t.isGoverned ? 60 : 56,
                    child: GestureDetector(
                      onTap: () => _openTerritory(t),
                      child: t.isGoverned
                          ? _GovernorBadge(territory: t)
                          : Center(child: _ZoneMarker(territory: t)),
                    ),
                  ),
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 48,
                    height: 48,
                    child: IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // halo estático (sem pulso — evita raster contínuo)
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.blue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.white, width: 3),
                              boxShadow: const [Shadows.soft],
                            ),
                          ),
                        ],
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
            child: GamePanel(
              color: Color.alphaBlend(
                  context.zon.warning.withValues(alpha: 0.15),
                  context.zon.surface),
              borderColor: context.zon.warning.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(LucideIcons.mapPinOff,
                      size: 18, color: context.zon.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GPS indisponível — mostrando uma área padrão. Permita a localização para ver seus territórios.',
                      style: AppText.label
                          .copyWith(color: context.zon.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // botões de atualizar e recentralizar (área segura no topo)
        Positioned(
          right: 12,
          top: topPad + (_usedFallback ? 88 : 12),
          child: Column(
            children: [
              _HudButton(
                icon: LucideIcons.refreshCw,
                loading: _refreshing,
                onTap: _refreshing ? null : _refresh,
              ),
              const SizedBox(height: 8),
              _HudButton(
                icon: LucideIcons.locateFixed,
                onTap: _refreshing ? null : _recenterFresh,
              ),
            ],
          ),
        ),
        if (_currentZone != null) _buildZoneSheet(_currentZone!),
      ],
    );
  }

  /// Sheet flutuante no rodapé com a zona atual: grab-handle, colapsável por
  /// arraste/toque, ações em GameButton. Mantém `Positioned` (sem
  /// DraggableScrollableSheet) para não conflitar com os gestos do mapa.
  Widget _buildZoneSheet(MapTerritory zone) {
    final zon = context.zon;
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
      bottom: 12,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 150 && !_sheetCollapsed) {
            setState(() => _sheetCollapsed = true);
          } else if (v < -150 && _sheetCollapsed) {
            setState(() => _sheetCollapsed = false);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: zon.surface,
            borderRadius: BorderRadius.circular(Corners.xl),
            boxShadow: const [Shadows.lifted],
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: AnimatedSize(
            duration: AppDurations.normal,
            curve: AppCurves.out,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // grab-handle (toque alterna expandido/colapsado)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _sheetCollapsed = !_sheetCollapsed),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2, bottom: 8),
                      decoration: BoxDecoration(
                        color: zon.outline,
                        borderRadius: BorderRadius.circular(Corners.pill),
                      ),
                    ),
                  ),
                ),
                if (_sheetCollapsed)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _sheetCollapsed = false),
                    child: Row(
                      children: [
                        Icon(LucideIcons.mapPin,
                            color: zon.danger, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            zone.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong,
                          ),
                        ),
                        Icon(LucideIcons.chevronUp,
                            size: 18, color: zon.onSurfaceMuted),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, color: zon.danger, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Você está em ${zone.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title.copyWith(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (zone.isGoverned) ...[
                        AvatarRing(
                          imageUrl: zone.governorAvatarUrl,
                          initial: zone.governorInitial,
                          size: 24,
                          ringWidth: 2,
                          gap: 1,
                          ringColor: zon.danger,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(status,
                            style: AppText.label
                                .copyWith(color: zon.onSurfaceMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GameButton(
                          label: iAmGovernor ? 'DEFENDER' : 'INICIAR DESAFIOS',
                          icon: iAmGovernor
                              ? LucideIcons.shield
                              : LucideIcons.play,
                          expanded: true,
                          onPressed: () => _startChallenge(zone),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GameButton(
                        label: 'VER',
                        variant: GameButtonVariant.secondary,
                        onPressed: () => _openTerritory(zone),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador de zona livre: círculo branco com anel colorido e ícone da zona —
/// robusto e legível sobre o mapa (estilo Waze).
class _ZoneMarker extends StatelessWidget {
  const _ZoneMarker({required this.territory});

  final MapTerritory territory;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final color = territory.color != null
        ? AppColors.zoneColor(territory.color)
        : zon.brand;
    final current = territory.isCurrent;
    final size = current ? 44.0 : 38.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: zon.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: const [Shadows.soft],
      ),
      child: Icon(
        territory.iconName != null
            ? zoneIcon(territory.iconName)
            : (current ? LucideIcons.mapPin : LucideIcons.hexagon),
        color: color,
        size: current ? 21 : 18,
      ),
    );
  }
}

/// Avatar do governador no centro do hexágono: AvatarRing com anel na cor da
/// zona e uma coroa em mini-pill laranja sobreposta (estilo sticker).
class _GovernorBadge extends StatelessWidget {
  const _GovernorBadge({required this.territory});

  final MapTerritory territory;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final ring = territory.color != null
        ? AppColors.zoneColor(territory.color)
        : zon.danger;
    return SizedBox(
      width: 56,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: AvatarRing(
              imageUrl: territory.governorAvatarUrl,
              initial: territory.governorInitial,
              size: 46,
              ringColor: ring,
              ringWidth: 3,
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: zon.brand,
                borderRadius: BorderRadius.circular(Corners.pill),
                border: Border.all(color: zon.surface, width: 1.5),
                boxShadow: const [Shadows.soft],
              ),
              child: Icon(LucideIcons.crown, size: 10, color: zon.onBrand),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão circular "chunky" do HUD do mapa (atualizar / recentralizar).
class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, this.onTap, this.loading = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GamePressable(
      onTap: onTap,
      radius: Corners.pill,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: zon.brand),
                )
              : Icon(icon, size: 19, color: zon.onSurface),
        ),
      ),
    );
  }
}
