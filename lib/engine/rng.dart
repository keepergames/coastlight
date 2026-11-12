/// Small deterministic PRNG (mulberry32) so a seed gives the same night on
/// every device and in every test. `dart:math` Random is not guaranteed to be
/// stable across platforms.
class Rng {
  Rng(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  /// Next value in [0, 1).
  double next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    t &= 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  /// Value in [a, b).
  double range(double a, double b) => a + (b - a) * next();

  /// Integer in [0, n).
  int nextInt(int n) => (next() * n).floor().clamp(0, n - 1);

  bool chance(double p) => next() < p;

  static int _imul(int a, int b) => imul32(a, b);
}

/// 32-bit multiply that gives the same answer on native (64-bit ints) and on
/// the web (53-bit doubles), by splitting into 16-bit halves.
int imul32(int a, int b) {
  final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
  return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

/// Stable 32-bit hash for strings (FNV-1a), used to seed nights by id/date.
int hashSeed(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = imul32(h, 0x01000193);
  }
  return h;
}
