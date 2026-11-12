import 'dart:math' as math;

/// Tiny immutable 2D vector so the engine has no Flutter or Flame dependency.
class Vec {
  const Vec(this.x, this.y);

  static const Vec zero = Vec(0, 0);

  final double x;
  final double y;

  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);
  Vec operator -(Vec o) => Vec(x - o.x, y - o.y);
  Vec operator *(double s) => Vec(x * s, y * s);

  double get length => math.sqrt(x * x + y * y);
  double get length2 => x * x + y * y;
  double get angle => math.atan2(y, x);

  Vec normalized() {
    final l = length;
    return l == 0 ? Vec.zero : Vec(x / l, y / l);
  }

  double distanceTo(Vec o) => (this - o).length;

  static Vec fromAngle(double a, [double len = 1]) =>
      Vec(math.cos(a) * len, math.sin(a) * len);

  @override
  String toString() => 'Vec(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Wraps an angle difference into -pi..pi.
double wrapAngle(double a) {
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}
