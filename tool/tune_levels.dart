// ignore_for_file: avoid_print
// Prints how the bots do on every night. Run: dart run tool/tune_levels.dart
// Add `all` to list every night instead of only the imperfect ones.
import 'package:keeper_of_the_cove/engine/bot.dart';
import 'package:keeper_of_the_cove/engine/seasons.dart';

void main(List<String> args) {
  final showAll = args.contains('all');
  print('id  s name                         q  dawn | skilled         | casual');
  var failures = 0;
  for (final spec in allNights) {
    final h = playNight(spec, KeeperBot());
    final c = playNight(spec, KeeperBot.casual());
    final st = playNight(spec, KeeperBot.steady());
    if (!h.kept && !c.kept && !st.kept) failures++;
    String fmt(BotRun r) =>
        '${(r.kept ? 'KEPT' : (r.outcome?.name ?? '-')).padRight(9)} e${r.embers} ${r.seconds.toStringAsFixed(0).padLeft(3)}s';
    if (showAll || h.embers < 3 || c.embers < 3) {
      print('${spec.id.toString().padLeft(2)}  ${spec.season} '
          '${spec.name.padRight(28)} ${spec.quota.toString().padLeft(2)} '
          '${spec.dawnSeconds.toStringAsFixed(0).padLeft(4)} | ${fmt(h)} | ${fmt(c)}');
    }
  }
  print('nights no bot style could keep: $failures');
  const seeds = [11, 22, 33, 44, 55, 66];
  for (final season in seasons) {
    for (final (label, make) in [('skilled', KeeperBot.new), ('casual', KeeperBot.casual)]) {
      var embers = 0, kept = 0, runs = 0;
      for (final id in season.nightIds) {
        for (final seed in seeds) {
          final r = playNight(allNights[id - 1], make(), seed: seed);
          embers += r.embers;
          if (r.kept) kept++;
          runs++;
        }
      }
      print('${season.name.padRight(16)} ${label.padRight(7)} kept ${(100 * kept / runs).toStringAsFixed(0).padLeft(3)}%  avg embers ${(embers / runs).toStringAsFixed(2)}');
    }
  }
}
