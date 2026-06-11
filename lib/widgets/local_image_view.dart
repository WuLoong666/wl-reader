import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/image_format.dart';

class LocalImageView extends StatelessWidget {
  const LocalImageView({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.fallbackBuilder,
    this.unsupportedBuilder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final WidgetBuilder? fallbackBuilder;
  final WidgetBuilder? unsupportedBuilder;

  @override
  Widget build(BuildContext context) {
    if (path.trim().isEmpty) {
      return _fallback(context);
    }

    final file = File(path);
    if (!file.existsSync()) {
      return _fallback(context);
    }

    final format = ImageFormat.fromPath(path);
    if (format.isRasterRenderable) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }

    if (format.isSvg) {
      return SvgPicture.file(
        file,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        placeholderBuilder: _placeholderBuilder,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }

    return _unsupported(context);
  }

  Widget _fallback(BuildContext context) {
    return fallbackBuilder?.call(context) ??
        SizedBox(width: width, height: height);
  }

  Widget _unsupported(BuildContext context) {
    return unsupportedBuilder?.call(context) ?? _fallback(context);
  }

  Widget _placeholderBuilder(BuildContext context) {
    return fallbackBuilder?.call(context) ??
        SizedBox(width: width, height: height);
  }
}
