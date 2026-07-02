import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../geo.dart';
import '../models.dart';

/// Camada que desenha a IMAGEM DE FUNDO de cada território recortada no formato
/// do hexágono (com transparência), acompanhando o zoom/pan do mapa. Deve ficar
/// entre o TileLayer e o PolygonLayer (a borda do hexágono fica por cima).
class HexBackgroundLayer extends StatefulWidget {
  const HexBackgroundLayer({
    super.key,
    required this.territories,
    this.opacity = 0.4,
  });

  final List<MapTerritory> territories;
  final double opacity;

  @override
  State<HexBackgroundLayer> createState() => _HexBackgroundLayerState();
}

class _HexBackgroundLayerState extends State<HexBackgroundLayer> {
  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};

  void _ensure(String url) {
    if (_images.containsKey(url) || _loading.contains(url)) return;
    _loading.add(url);
    final stream =
        CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _loading.remove(url);
        if (mounted) setState(() => _images[url] = info.image);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        _loading.remove(url);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final items = <_HexBg>[];
    for (final t in widget.territories) {
      final url = t.backgroundUrl;
      if (url == null || url.isEmpty) continue;
      _ensure(url);
      final img = _images[url];
      if (img == null) continue; // ainda carregando
      items.add(_HexBg(
        vertices: hexagonVertices(LatLng(t.centerLat, t.centerLng), t.radiusKm),
        image: img,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox.expand(
      child: CustomPaint(
        painter: _HexBgPainter(
          camera: camera,
          items: items,
          opacity: widget.opacity,
        ),
      ),
    );
  }
}

class _HexBg {
  _HexBg({required this.vertices, required this.image});
  final List<LatLng> vertices;
  final ui.Image image;
}

class _HexBgPainter extends CustomPainter {
  _HexBgPainter({
    required this.camera,
    required this.items,
    required this.opacity,
  });

  final MapCamera camera;
  final List<_HexBg> items;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    for (final it in items) {
      final pts =
          it.vertices.map((v) => camera.latLngToScreenOffset(v)).toList();
      final path = ui.Path()..addPolygon(pts, true);
      final bounds = path.getBounds();
      if (bounds.isEmpty) continue;

      // opacidade aplicada à camada inteira
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
      canvas.clipPath(path);
      canvas.drawImageRect(
        it.image,
        Rect.fromLTWH(
            0, 0, it.image.width.toDouble(), it.image.height.toDouble()),
        _coverRect(it.image, bounds),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
  }

  /// Retângulo de destino que COBRE o hexágono mantendo o aspecto da imagem.
  Rect _coverRect(ui.Image img, Rect dst) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = math.max(dst.width / iw, dst.height / ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH(
      dst.center.dx - w / 2,
      dst.center.dy - h / 2,
      w,
      h,
    );
  }

  @override
  bool shouldRepaint(covariant _HexBgPainter old) =>
      old.camera != camera ||
      old.items.length != items.length ||
      old.opacity != opacity;
}
