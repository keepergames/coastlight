import 'dart:ui';

/// Chandlery shelves. Everything is cosmetic and paid with lamp oil earned by
/// playing. Prices are fixed; nothing is random; nothing costs money.
enum Shelf { beam, paint, boats, keepsakes }

class Good {
  const Good({
    required this.id,
    required this.shelf,
    required this.name,
    required this.line,
    required this.price,
    this.beamColor,
    this.asset,
  });

  final String id;
  final Shelf shelf;
  final String name;

  /// One line of keeper's description.
  final String line;
  final int price;

  /// For beam goods: the light's colour.
  final Color? beamColor;

  /// Paint / boat livery / keepsake asset key.
  final String? asset;

  bool get isDefault => price == 0;
}

String shelfTitle(Shelf s) => switch (s) {
      Shelf.beam => 'Lamp glass',
      Shelf.paint => 'Tower paint',
      Shelf.boats => 'Harbour liveries',
      Shelf.keepsakes => 'Keepsakes',
    };

const List<Good> catalog = [
  // Lamp glass: tints the beam. Kept warm or moonlit so light still reads as safety.
  Good(id: 'beam_amber', shelf: Shelf.beam, name: 'Amber glass', line: 'The lens the tower was built with.', price: 0, beamColor: Color(0xFFF4B860)),
  Good(id: 'beam_candle', shelf: Shelf.beam, name: 'Candle glass', line: 'A paler, softer flame.', price: 140, beamColor: Color(0xFFFFE0A3)),
  Good(id: 'beam_rose', shelf: Shelf.beam, name: 'Rose dawn glass', line: 'Warm as the first minute of morning.', price: 220, beamColor: Color(0xFFF2A88C)),
  Good(id: 'beam_moon', shelf: Shelf.beam, name: 'Moonlight glass', line: 'Cool and silver, for winter nights.', price: 300, beamColor: Color(0xFFD9E4F2)),
  // Tower paint (seen on the hub).
  Good(id: 'paint_rust', shelf: Shelf.paint, name: 'Rust bands', line: 'The old harbour board colours.', price: 0, asset: 'rust'),
  Good(id: 'paint_tide', shelf: Shelf.paint, name: 'Tide bands', line: 'Deep blue, the colour of the cove.', price: 160, asset: 'tide'),
  Good(id: 'paint_white', shelf: Shelf.paint, name: 'Whitewash', line: 'Plain lime and patience.', price: 200, asset: 'whitewash'),
  Good(id: 'paint_stone', shelf: Shelf.paint, name: 'Bare stone', line: 'Scrape it back to the granite.', price: 260, asset: 'stone'),
  // Harbour liveries: how the boats you guide are painted.
  Good(id: 'boats_skiff', shelf: Shelf.boats, name: 'Grey working boats', line: 'Plain hulls, pale sails.', price: 0, asset: 'skiff'),
  Good(id: 'boats_tan', shelf: Shelf.boats, name: 'Tan sails', line: 'Bark-dyed canvas, like the old fleet.', price: 240, asset: 'tan'),
  Good(id: 'boats_painted', shelf: Shelf.boats, name: 'Painted hulls', line: 'Blue hulls with a lamp-gold trim.', price: 320, asset: 'painted'),
  // Keepsakes: appear around the lighthouse on the hub.
  Good(id: 'keep_vane', shelf: Shelf.keepsakes, name: 'Herring vane', line: 'An iron fish to read the wind.', price: 90, asset: 'vane'),
  Good(id: 'keep_garden', shelf: Shelf.keepsakes, name: 'Herb garden', line: 'Thyme and sea kale by the door.', price: 130, asset: 'garden'),
  Good(id: 'keep_bunting', shelf: Shelf.keepsakes, name: 'Bunting', line: 'Flags for a kept season.', price: 170, asset: 'bunting'),
  Good(id: 'keep_telescope', shelf: Shelf.keepsakes, name: 'Brass telescope', line: 'For watching the far shore.', price: 220, asset: 'telescope'),
  Good(id: 'keep_cat', shelf: Shelf.keepsakes, name: 'A sleeping cat', line: 'She came with the winter and stayed.', price: 280, asset: 'cat'),
];

Good goodById(String id) => catalog.firstWhere((g) => g.id == id);

Iterable<Good> shelfGoods(Shelf s) => catalog.where((g) => g.shelf == s);

/// Shelves where one item is "in use" at a time (keepsakes are all shown).
bool isExclusive(Shelf s) => s != Shelf.keepsakes;

String defaultFor(Shelf s) => switch (s) {
      Shelf.beam => 'beam_amber',
      Shelf.paint => 'paint_rust',
      Shelf.boats => 'boats_skiff',
      Shelf.keepsakes => '',
    };
