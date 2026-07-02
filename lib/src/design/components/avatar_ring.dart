import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Avatar circular com anel colorido e gap branco — perfil, ranking,
/// governadores no mapa.
class AvatarRing extends StatelessWidget {
  const AvatarRing({
    super.key,
    this.imageUrl,
    this.initial,
    this.size = 44,
    this.ringColor,
    this.ringWidth = 3,
    this.gap = 2,
  });

  final String? imageUrl;

  /// Fallback quando não há foto (primeira letra do nome).
  final String? initial;
  final double size;
  final Color? ringColor;
  final double ringWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final ring = ringColor ?? zon.brand;
    final innerSize = size - 2 * (ringWidth + gap);

    Widget inner;
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      inner = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: innerSize,
          height: innerSize,
          fit: BoxFit.cover,
          fadeInDuration: AppDurations.fast,
          errorWidget: (_, __, ___) => _InitialAvatar(
              initial: initial, size: innerSize, color: ring),
        ),
      );
    } else {
      inner = _InitialAvatar(initial: initial, size: innerSize, color: ring);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: zon.surface,
        border: Border.all(color: ring, width: ringWidth),
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({this.initial, required this.size, required this.color});

  final String? initial;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Text(
        (initial ?? '?').toUpperCase(),
        style: AppText.title.copyWith(fontSize: size * 0.45, color: color),
      ),
    );
  }
}
