import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decoded images painted by tool/make_art.py, loaded once at start.
class Art {
  Art._();

  static final Map<String, ui.Image> _images = {};
  static bool _loaded = false;

  static bool get loaded => _loaded;

  static final List<String> files = [
    'sea_0.jpg', 'sea_1.jpg', 'sea_2.jpg', 'sea_3.jpg', 'hub.jpg',
    'rocks.png', 'harbor.png', 'lamp_gallery.png', 'buoy_dark.png', 'buoy_lit.png',
    'tower_rust.png', 'tower_tide.png', 'tower_whitewash.png', 'tower_stone.png',
    'keepsake_vane.png', 'keepsake_garden.png', 'keepsake_cat.png',
    'keepsake_bunting.png', 'keepsake_telescope.png',
    for (final t in ['skiff', 'tan', 'painted'])
      for (final s in ['skiff', 'sloop', 'drifter', 'lead']) 'boat_${t}_$s.png',
  ];

  static Future<void> load() async {
    if (_loaded) return;
    await Future.wait(files.map((f) async {
      try {
        final data = await rootBundle.load('assets/art/$f');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _images[f.split('.').first] = frame.image;
      } catch (_) {
        // A missing image falls back to the code-drawn shapes.
      }
    }));
    _loaded = true;
  }

  /// The image named [key] (file name without extension), if loaded.
  static ui.Image? img(String key) => _images[key];

  static ui.Image? sea(int season) => _images['sea_$season'];
  static ui.Image? boat(String livery, int style) =>
      _images['boat_${livery}_${const ['skiff', 'sloop', 'drifter', 'lead'][style.clamp(0, 3)]}'];
}

/// Draws [img] to cover [dst] (like BoxFit.cover), cropping evenly.
void paintCover(ui.Canvas canvas, ui.Image img, ui.Rect dst, {ui.Paint? paint, double alignY = 0}) {
  final iw = img.width.toDouble(), ih = img.height.toDouble();
  final scale = (dst.width / iw) > (dst.height / ih) ? dst.width / iw : dst.height / ih;
  final sw = dst.width / scale, sh = dst.height / scale;
  final sx = (iw - sw) / 2;
  final sy = (ih - sh) * (alignY + 1) / 2;
  canvas.drawImageRect(img, ui.Rect.fromLTWH(sx, sy, sw, sh), dst,
      paint ?? (ui.Paint()..filterQuality = ui.FilterQuality.medium));
}
