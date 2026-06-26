import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'territory_detail_screen.dart';

/// Home: mapa 2D (OSM) com a localização real do jogador e os territórios
/// hexagonais (3km) gerados ao redor. Toque num hexágono para entrar nele.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.api});

  final ApiClient api;

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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await _determinePosition();
      final territories = await widget.api.territoriesNear(
        location.latitude,
        location.longitude,
        rings: 2,
      );
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _territories = territories;
        _loading = false;
      });
      _mapController.move(location, 13);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao carregar o mapa: $e';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
  }

  void _openTerritory(MapTerritory t) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => TerritoryDetailScreen(
            api: widget.api,
            territory: t.toTerritory(),
          ),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAPA'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(api: widget.api)),
            ),
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.ink,
        onPressed: _userLocation == null
            ? null
            : () => _mapController.move(_userLocation!, 13),
        child: const Icon(Icons.my_location),
      ),
      body: _buildBody(),
    );
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
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zoniqmax.app',
            ),
            PolygonLayer(
              polygons: _territories.map((t) {
                final governed = t.governorUserId != null;
                return Polygon(
                  points: hexagonVertices(
                    LatLng(t.centerLat, t.centerLng),
                    t.radiusKm,
                  ),
                  color: (governed ? AppColors.red : AppColors.orange)
                      .withValues(alpha: 0.18),
                  borderColor: AppColors.ink,
                  borderStrokeWidth: 2,
                );
              }).toList(),
            ),
            MarkerLayer(
              markers: [
                for (final t in _territories)
                  Marker(
                    point: LatLng(t.centerLat, t.centerLng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _openTerritory(t),
                      child: Icon(
                        t.governorUserId != null
                            ? Icons.flag
                            : Icons.hexagon_outlined,
                        color: t.governorUserId != null
                            ? AppColors.red
                            : AppColors.brown,
                        size: 28,
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
        if (_usedFallback)
          const Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: ComicPanel(
              color: AppColors.orange,
              padding: EdgeInsets.all(10),
              child: Text(
                'GPS indisponível — mostrando uma área padrão. Permita a localização para ver seus territórios.',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
          ),
      ],
    );
  }
}
