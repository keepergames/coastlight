import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'audio/fx.dart';
import 'data/progress.dart';
import 'game/art.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Spectral (font)'], ofl);
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Preview builds expose the accessibility tree so the recorder can find buttons.
  if (keeperPreview) SemanticsBinding.instance.ensureSemantics();
  final results = await Future.wait([Progress.load(), Art.load()]);
  final progress = results.first as Progress;
  Fx.init(progress);
  runApp(KeeperApp(progress: progress));
}
