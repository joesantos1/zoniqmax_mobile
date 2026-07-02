// Gera os assets de identidade do app (ícone + splash) em assets/icon/.
// Uso: dart run tool/gen_icon.dart
//
// Se um asset desenhado por designer chegar depois, basta substituir os PNGs
// nos mesmos caminhos e rodar novamente flutter_launcher_icons / native_splash.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// Paleta da marca.
final orange = img.ColorRgba8(0xF2, 0x85, 0x1B, 0xFF);
final orangeEdge = img.ColorRgba8(0xC9, 0x6A, 0x0E, 0xFF);
final ink = img.ColorRgba8(0x1B, 0x1A, 0x18, 0xFF);
final white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);

// Fator de supersampling para bordas suaves (renderiza grande, reduz depois).
const ss = 4;

List<img.Point> hexagon(double cx, double cy, double r) {
  // Hexágono pointy-top (vértice para cima), igual às zonas do mapa.
  return List.generate(6, (i) {
    final a = (-90 + 60 * i) * math.pi / 180;
    return img.Point(cx + r * math.cos(a), cy + r * math.sin(a));
  });
}

List<img.Point> zMark(double cx, double cy, double size) {
  // "Z" bold em polígono único, coordenadas em caixa unitária (y para baixo).
  const pts = [
    [0.06, 0.06], [0.94, 0.06], [0.94, 0.30], [0.42, 0.70], [0.94, 0.70],
    [0.94, 0.94], [0.06, 0.94], [0.06, 0.70], [0.58, 0.30], [0.06, 0.30],
  ];
  final half = size / 2;
  return pts
      .map((p) => img.Point(cx - half + p[0] * size, cy - half + p[1] * size))
      .toList();
}

void drawBadge(img.Image im, double cx, double cy, double hexR,
    {required img.Color zColor, bool edge = true}) {
  // Sombra "chunky" (edge) deslocada para baixo, estilo sticker.
  if (edge) {
    img.fillPolygon(im,
        vertices: hexagon(cx, cy + hexR * 0.07, hexR), color: orangeEdge);
  }
  img.fillPolygon(im, vertices: hexagon(cx, cy, hexR), color: white);
  img.fillPolygon(im, vertices: zMark(cx, cy, hexR * 0.98), color: zColor);
}

img.Image downsample(img.Image big, int size) => img.copyResize(big,
    width: size, height: size, interpolation: img.Interpolation.average);

void savePng(img.Image im, String path) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
  stdout.writeln('gerado: $path (${im.width}x${im.height})');
}

void main() {
  const dir = 'assets/icon';

  // icon.png — 1024², fundo laranja, hexágono branco com Z ink.
  {
    const size = 1024;
    final big = img.Image(width: size * ss, height: size * ss);
    img.fill(big, color: orange);
    const c = size * ss / 2;
    drawBadge(big, c, c - size * ss * 0.015, size * ss * 0.36, zColor: ink);
    savePng(downsample(big, size), '$dir/icon.png');
  }

  // icon_foreground.png — 1024² transparente, arte na safe zone central (66%).
  {
    const size = 1024;
    final big =
        img.Image(width: size * ss, height: size * ss, numChannels: 4);
    const c = size * ss / 2;
    drawBadge(big, c, c, size * ss * 0.24, zColor: ink);
    savePng(downsample(big, size), '$dir/icon_foreground.png');
  }

  // splash_logo.png — 768² transparente, hexágono branco com Z laranja
  // (lê como "recorte" sobre o fundo laranja do splash).
  {
    const size = 768;
    final big =
        img.Image(width: size * ss, height: size * ss, numChannels: 4);
    const c = size * ss / 2;
    drawBadge(big, c, c, size * ss * 0.32, zColor: orange, edge: false);
    savePng(downsample(big, size), '$dir/splash_logo.png');
  }
}
