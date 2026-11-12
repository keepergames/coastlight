import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/progress.dart';

/// Every sound in the game (files made by tool/make_sfx.py).
enum Sfx {
  tap('tap'),
  page('page'),
  chart('chart'),
  charted('charted'),
  home('home'),
  lost('lost'),
  ember('ember'),
  kindle('kindle'),
  buoyOut('buoy_out'),
  dawn('dawn'),
  lantern('lantern'),
  dark('dark'),
  unlock('unlock'),
  purchase('purchase');

  const Sfx(this.file);
  final String file;
}

enum Music { hub, sea }

/// Sound, music and haptics, all switchable in Settings.
class Fx {
  Fx._();

  /// Tests and the preview recorder turn real audio off.
  static bool audioDisabled = false;

  static Progress? _progress;
  static final Map<Sfx, List<AudioPlayer>> _pools = {};
  static final Map<Sfx, int> _next = {};
  static AudioPlayer? _music;
  static Music? _track;
  static bool _paused = false;
  static AppLifecycleListener? _life;

  static void init(Progress progress) {
    _progress = progress;
    progress.addListener(_applySettings);
    _life ??= AppLifecycleListener(
      onHide: () {
        _paused = true;
        _music?.pause();
      },
      onShow: () {
        _paused = false;
        _applySettings();
      },
    );
  }

  static bool get _soundOn => !audioDisabled && (_progress?.sound ?? true);
  static bool get _musicOn => !audioDisabled && (_progress?.music ?? true);
  static bool get _hapticsOn => _progress?.vibration ?? true;

  static Future<void> play(Sfx s, {double volume = 1}) async {
    if (!_soundOn) return;
    try {
      final pool = _pools.putIfAbsent(s, () => []);
      final i = _next[s] ?? 0;
      if (pool.length < 3) {
        final p = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        pool.add(p);
      }
      final player = pool[i % pool.length];
      _next[s] = i + 1;
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/${s.file}.ogg'));
    } catch (_) {
      // Audio is a nicety: a device that cannot play it still plays the game.
    }
  }

  static Future<void> music(Music track) async {
    _track = track;
    await _applySettings();
  }

  static Future<void> _applySettings() async {
    if (_paused) return;
    try {
      if (!_musicOn || _track == null) {
        await _music?.pause();
        return;
      }
      final file = _track == Music.hub ? 'keeper_tune' : 'sea_loop';
      final player = _music ??= AudioPlayer();
      if (player.source is AssetSource && (player.source as AssetSource).path.contains(file)) {
        if (player.state != PlayerState.playing) await player.resume();
        return;
      }
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_track == Music.hub ? 0.5 : 0.65);
      await player.play(AssetSource('audio/$file.ogg'));
    } catch (_) {}
  }

  static void lightTap() {
    if (_hapticsOn) HapticFeedback.selectionClick();
  }

  static void soft() {
    if (_hapticsOn) HapticFeedback.lightImpact();
  }

  static void firm() {
    if (_hapticsOn) HapticFeedback.mediumImpact();
  }
}
