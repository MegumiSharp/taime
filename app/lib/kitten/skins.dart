/// The kitten catalogue: pure data, drawn by `painter.dart`.
library;

enum Rarity { comune, raro, epico, leggendario }

extension RarityInfo on Rarity {
  String get label => switch (this) {
    Rarity.comune => 'Comune',
    Rarity.raro => 'Raro',
    Rarity.epico => 'Epico',
    Rarity.leggendario => 'Leggendario',
  };

  /// Hue (OKLCH) used to tint rarity badges and cards.
  double get hue => switch (this) {
    Rarity.comune => 150,
    Rarity.raro => 235,
    Rarity.epico => 305,
    Rarity.leggendario => 75,
  };
}

enum Pose { seduto, pagnotta, dorme }

extension PoseInfo on Pose {
  String get label => switch (this) {
    Pose.seduto => 'Seduto',
    Pose.pagnotta => 'Pagnotta',
    Pose.dorme => 'Dorme',
  };
}

enum CoatPattern { tintaUnita, tigrato, calico, point, macchie }

enum EyeStyle { puntini, dorati, azzurri }

enum Accessory {
  nessuno,
  fiocco,
  sciarpa,
  campanella,
  cuffie,
  berretto,
  basco,
  coronaFiori,
  occhiali,
  germoglio,
  corona,
  mantello,
  lunaFermaglio,
  coronaFoglie,
}

enum Effect { nessuno, stelle, scintille, petali, lucciole, note, pittura, codaArcobaleno, sciarpaVento }

class Coat {
  const Coat({
    required this.pattern,
    required this.base,
    this.second,
    this.third,
    this.whiteMuzzle = false,
    this.whiteBelly = false,
    this.whitePaws = false,
    this.blaze = false,
    this.darkOutline = false,
  });

  final CoatPattern pattern;
  final int base;

  /// Stripes, spots, points or the first calico patch colour.
  final int? second;

  /// Second calico patch colour.
  final int? third;
  final bool whiteMuzzle, whiteBelly, whitePaws, blaze;

  /// For very dark coats the usual brown outline would vanish.
  final bool darkOutline;
}

class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.rarity,
    required this.price,
    required this.coat,
    this.pose = Pose.seduto,
    this.eyes = EyeStyle.puntini,
    this.accessory = Accessory.nessuno,
    this.accessoryColor = 0xFFE89BBE,
    this.accessory2 = Accessory.nessuno,
    this.accessory2Color = 0xFFF2C94C,
    this.effect = Effect.nessuno,
    this.free = false,
  });

  final String id;
  final String name;
  final Rarity rarity;
  final int price;
  final Coat coat;
  final Pose pose;
  final EyeStyle eyes;
  final Accessory accessory;
  final int accessoryColor;
  final Accessory accessory2;
  final int accessory2Color;
  final Effect effect;
  final bool free;
}

// Coat colours: flat, warm, never saturated.
const _orange = 0xFFF3AE6B, _orangeStripe = 0xFFE0894A;
const _cream = 0xFFF8EAD6, _white = 0xFFFFFAF3;
const _lightGrey = 0xFFD9D2CD, _grey = 0xFFBDB4AE, _greyStripe = 0xFF978C86;
const _charcoal = 0xFF6E6562, _smoke = 0xFF9EA6B1;
const _brown = 0xFFBC8A66, _brownStripe = 0xFF946747, _caramel = 0xFFDDA26D;
const _chocolate = 0xFF8C6150, _black = 0xFF514748;
const _navy = 0xFF55618A, _lavGrey = 0xFFC9BDD8, _sage = 0xFFE2E7CF;
const _peachSoft = 0xFFF6C29C, _pinkGrey = 0xFFB8A9AE;

const List<Skin> kSkins = [
  // --- Comuni --------------------------------------------------------------
  Skin(
    id: 'biscotto',
    name: 'Biscotto',
    rarity: Rarity.comune,
    price: 0,
    free: true,
    coat: Coat(
      pattern: CoatPattern.tigrato,
      base: _orange,
      second: _orangeStripe,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
    ),
  ),
  Skin(
    id: 'nuvola',
    name: 'Nuvola',
    rarity: Rarity.comune,
    price: 0,
    free: true,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: _lightGrey,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
    ),
  ),
  Skin(
    id: 'latte',
    name: 'Latte',
    rarity: Rarity.comune,
    price: 0,
    free: true,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _cream),
  ),
  Skin(
    id: 'pepe',
    name: 'Pepe',
    rarity: Rarity.comune,
    price: 60,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: _charcoal,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
      blaze: true,
    ),
  ),
  Skin(
    id: 'caramello',
    name: 'Caramello',
    rarity: Rarity.comune,
    price: 80,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _caramel),
  ),
  Skin(
    id: 'tigro',
    name: 'Tigro',
    rarity: Rarity.comune,
    price: 90,
    coat: Coat(pattern: CoatPattern.tigrato, base: _grey, second: _greyStripe),
  ),
  Skin(
    id: 'cannella',
    name: 'Cannella',
    rarity: Rarity.comune,
    price: 100,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _brown, whitePaws: true),
  ),
  Skin(
    id: 'mochi',
    name: 'Mochi',
    rarity: Rarity.comune,
    price: 120,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.macchie, base: _white, second: _grey),
  ),
  Skin(
    id: 'zucca',
    name: 'Zucca',
    rarity: Rarity.comune,
    price: 140,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _orange, whiteMuzzle: true),
  ),
  Skin(
    id: 'fumo',
    name: 'Fumo',
    rarity: Rarity.comune,
    price: 150,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _smoke),
  ),

  // --- Rari ----------------------------------------------------------------
  Skin(
    id: 'pezzetta',
    name: 'Pezzetta',
    rarity: Rarity.raro,
    price: 300,
    coat: Coat(
      pattern: CoatPattern.calico,
      base: _white,
      second: _orange,
      third: _charcoal,
    ),
  ),
  Skin(
    id: 'menta',
    name: 'Menta',
    rarity: Rarity.raro,
    price: 320,
    pose: Pose.pagnotta,
    accessory: Accessory.fiocco,
    accessoryColor: 0xFF8FD3B6,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: _lightGrey,
      whiteMuzzle: true,
    ),
  ),
  Skin(
    id: 'cappuccino',
    name: 'Cappuccino',
    rarity: Rarity.raro,
    price: 350,
    eyes: EyeStyle.azzurri,
    coat: Coat(pattern: CoatPattern.point, base: _cream, second: _chocolate),
  ),
  Skin(
    id: 'zenzero',
    name: 'Zenzero',
    rarity: Rarity.raro,
    price: 380,
    accessory: Accessory.sciarpa,
    accessoryColor: 0xFF8FCFB0,
    coat: Coat(pattern: CoatPattern.tigrato, base: _orange, second: _orangeStripe),
  ),
  Skin(
    id: 'brioche',
    name: 'Brioche',
    rarity: Rarity.raro,
    price: 400,
    pose: Pose.pagnotta,
    accessory: Accessory.campanella,
    accessoryColor: 0xFFE88A8A,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _peachSoft, whiteMuzzle: true),
  ),
  Skin(
    id: 'fiocco',
    name: 'Fiocco',
    rarity: Rarity.raro,
    price: 420,
    accessory: Accessory.fiocco,
    accessoryColor: 0xFFF2A7C3,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _white),
  ),
  Skin(
    id: 'pistacchio',
    name: 'Pistacchio',
    rarity: Rarity.raro,
    price: 450,
    accessory: Accessory.cuffie,
    accessoryColor: 0xFFA9D18E,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: _grey,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
    ),
  ),
  Skin(
    id: 'nocciola',
    name: 'Nocciola',
    rarity: Rarity.raro,
    price: 480,
    accessory: Accessory.berretto,
    accessoryColor: 0xFFE7C36A,
    coat: Coat(pattern: CoatPattern.tigrato, base: _brown, second: _brownStripe),
  ),
  Skin(
    id: 'gelsomino',
    name: 'Gelsomino',
    rarity: Rarity.raro,
    price: 550,
    pose: Pose.pagnotta,
    accessory: Accessory.coronaFiori,
    accessoryColor: 0xFFF6B7C8,
    coat: Coat(
      pattern: CoatPattern.calico,
      base: _white,
      second: _caramel,
      third: _grey,
    ),
  ),
  Skin(
    id: 'ombra',
    name: 'Ombra',
    rarity: Rarity.raro,
    price: 600,
    eyes: EyeStyle.dorati,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _black, darkOutline: true),
  ),

  // --- Epici ---------------------------------------------------------------
  Skin(
    id: 'professore',
    name: 'Professore',
    rarity: Rarity.epico,
    price: 900,
    accessory: Accessory.occhiali,
    accessoryColor: 0xFF6E5A50,
    coat: Coat(
      pattern: CoatPattern.tigrato,
      base: _grey,
      second: _greyStripe,
      whiteMuzzle: true,
    ),
  ),
  Skin(
    id: 'marinaio',
    name: 'Marinaio',
    rarity: Rarity.epico,
    price: 1000,
    accessory: Accessory.basco,
    accessoryColor: 0xFF7F93C9,
    accessory2: Accessory.sciarpa,
    accessory2Color: 0xFF9DB4E8,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _white),
  ),
  Skin(
    id: 'germoglio',
    name: 'Germoglio',
    rarity: Rarity.epico,
    price: 1100,
    pose: Pose.pagnotta,
    accessory: Accessory.germoglio,
    accessoryColor: 0xFF93C98A,
    coat: Coat(
      pattern: CoatPattern.calico,
      base: _cream,
      second: _orange,
      third: _brown,
    ),
  ),
  Skin(
    id: 'pittore',
    name: 'Pittore',
    rarity: Rarity.epico,
    price: 1200,
    accessory: Accessory.basco,
    accessoryColor: 0xFFE58C8C,
    effect: Effect.pittura,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _cream, whiteMuzzle: true),
  ),
  Skin(
    id: 'vinile',
    name: 'Vinile',
    rarity: Rarity.epico,
    price: 1300,
    accessory: Accessory.cuffie,
    accessoryColor: 0xFFB89BE3,
    effect: Effect.note,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: _charcoal,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
      blaze: true,
    ),
  ),
  Skin(
    id: 'sakura',
    name: 'Sakura',
    rarity: Rarity.epico,
    price: 1400,
    pose: Pose.pagnotta,
    effect: Effect.petali,
    accessory: Accessory.coronaFiori,
    accessoryColor: 0xFFF7B8CC,
    coat: Coat(
      pattern: CoatPattern.calico,
      base: _white,
      second: 0xFFF3B7A0,
      third: _pinkGrey,
    ),
  ),
  Skin(
    id: 'nebbia',
    name: 'Nebbia',
    rarity: Rarity.epico,
    price: 1500,
    eyes: EyeStyle.azzurri,
    accessory: Accessory.sciarpa,
    accessoryColor: 0xFFC7B3E6,
    coat: Coat(pattern: CoatPattern.point, base: _white, second: _smoke),
  ),

  // --- Leggendari ----------------------------------------------------------
  Skin(
    id: 'notte',
    name: 'Notte Stellata',
    rarity: Rarity.leggendario,
    price: 2500,
    effect: Effect.stelle,
    eyes: EyeStyle.dorati,
    accessory: Accessory.lunaFermaglio,
    accessoryColor: 0xFFF2D27C,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _navy, darkOutline: true),
  ),
  Skin(
    id: 'remicio',
    name: 'Re Micio',
    rarity: Rarity.leggendario,
    price: 3000,
    accessory: Accessory.corona,
    accessoryColor: 0xFFF2C94C,
    accessory2: Accessory.mantello,
    accessory2Color: 0xFFB0708E,
    effect: Effect.scintille,
    coat: Coat(
      pattern: CoatPattern.tigrato,
      base: _orange,
      second: _orangeStripe,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
    ),
  ),
  Skin(
    id: 'aurora',
    name: 'Aurora',
    rarity: Rarity.leggendario,
    price: 3200,
    effect: Effect.codaArcobaleno,
    accessory2: Accessory.nessuno,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _white),
  ),
  Skin(
    id: 'bosco',
    name: 'Spirito del Bosco',
    rarity: Rarity.leggendario,
    price: 3500,
    pose: Pose.pagnotta,
    accessory: Accessory.coronaFoglie,
    accessoryColor: 0xFF9CCB8E,
    effect: Effect.lucciole,
    coat: Coat(pattern: CoatPattern.macchie, base: _sage, second: 0xFFC7D3A8),
  ),
  Skin(
    id: 'luna',
    name: 'Principessa Luna',
    rarity: Rarity.leggendario,
    price: 4000,
    accessory: Accessory.lunaFermaglio,
    accessoryColor: 0xFFF2D27C,
    accessory2: Accessory.sciarpa,
    accessory2Color: 0xFFD7B8F0,
    effect: Effect.sciarpaVento,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _lavGrey, whiteMuzzle: true),
  ),
];

final Map<String, Skin> kSkinById = {for (final s in kSkins) s.id: s};

Skin skinById(String? id) => kSkinById[id] ?? kSkins.first;

// --- Growth ---------------------------------------------------------------

/// Minutes at which each growth stage starts.
const List<int> kStageMinutes = [0, 10, 25, 45, 60];
const List<String> kStageNames = [
  'Neonato',
  'Cucciolo',
  'Giovane',
  'Quasi adulto',
  'Adulto',
];

/// 0..4 for a number of worked minutes (within the current hour).
int stageOf(double minutes) {
  var s = 0;
  for (var i = 0; i < kStageMinutes.length; i++) {
    if (minutes >= kStageMinutes[i]) s = i;
  }
  return s;
}

/// Continuous size factor 0..1 (adult at 60 minutes).
double growthOf(double minutes) => (minutes / 60).clamp(0.0, 1.0);

// --- The pen: one adult per full hour, plus a kitten for the rest ----------

class PenCat {
  const PenCat(this.skinId, this.growth, this.seed);
  final String skinId;

  /// 1.0 = adult.
  final double growth;

  /// Stable per cat, for placement and pose.
  final int seed;
}

/// Minimum leftover minutes that still earn a kitten.
const int kMinKittenMinutes = 5;

/// Cats earned by one session of [workMinutes].
List<PenCat> catsForSession(int workMinutes, String skinId, int seed) {
  final adults = workMinutes ~/ 60;
  final rest = workMinutes % 60;
  return [
    for (var i = 0; i < adults; i++) PenCat(skinId, 1, seed * 31 + i),
    if (rest >= kMinKittenMinutes) PenCat(skinId, growthOf(rest.toDouble()), seed * 31 + adults),
  ];
}

// --- Crocchette -----------------------------------------------------------

/// One crocchetta per minute of work, minus what was spent. Can be negative
/// after editing sessions; callers show `max(0, ...)` and block purchases.
int crocchetteBalance(int workSeconds, int spent) => workSeconds ~/ 60 - spent;
