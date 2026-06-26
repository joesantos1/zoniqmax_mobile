import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

const double _kmPerDegLat = 110.574;
const double _kmPerDegLng = 111.32;

/// Vértices de um hexágono "pointy-top" (um vértice apontando para o norte),
/// dado o centro e o raio (centro→vértice) em km. Espelha a grade do servidor.
List<LatLng> hexagonVertices(LatLng center, double radiusKm) {
  final lngScale = _kmPerDegLng * math.cos(center.latitude * math.pi / 180);
  final points = <LatLng>[];
  for (int i = 0; i < 6; i++) {
    final angle = (60.0 * i + 30.0) * math.pi / 180.0; // offset 30° = pointy-top
    final dEastKm = radiusKm * math.cos(angle);
    final dNorthKm = radiusKm * math.sin(angle);
    final lat = center.latitude + dNorthKm / _kmPerDegLat;
    final lng = center.longitude + dEastKm / lngScale;
    points.add(LatLng(lat, lng));
  }
  return points;
}
