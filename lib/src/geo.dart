import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

const double _kmPerDegLat = 110.574;
const double _kmPerDegLng = 111.32;

/// Distância aproximada em km entre dois pontos (Haversine).
double distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
  return 2 * r * math.asin(math.sqrt(h));
}

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
