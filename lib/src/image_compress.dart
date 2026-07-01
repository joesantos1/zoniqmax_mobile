import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int _maxBytes = 1024 * 1024; // 1 MB
const int _maxDimension = 1280; // maior lado, em px

/// Garante que a imagem fique abaixo de 1 MB: se já estiver, retorna como veio;
/// senão redimensiona e recomprime (JPEG) em um isolate (não trava a UI).
Future<Uint8List> compressImageUnder1MB(Uint8List input) {
  if (input.lengthInBytes <= _maxBytes) return Future.value(input);
  return compute(_compress, input);
}

Uint8List _compress(Uint8List input) {
  img.Image? im;
  try {
    im = img.decodeImage(input);
  } catch (_) {
    return input;
  }
  if (im == null) return input;

  // 1) redimensiona se o maior lado exceder o limite
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > _maxDimension) {
    im = im.width >= im.height
        ? img.copyResize(im, width: _maxDimension)
        : img.copyResize(im, height: _maxDimension);
  }

  // 2) tenta qualidades JPEG decrescentes
  for (final q in const [82, 72, 62, 52, 42]) {
    final out = img.encodeJpg(im, quality: q);
    if (out.lengthInBytes <= _maxBytes) return out;
  }

  // 3) ainda grande: reduz a dimensão e recomprime uma última vez
  final smaller = img.copyResize(im, width: (im.width * 0.7).round());
  return img.encodeJpg(smaller, quality: 50);
}
