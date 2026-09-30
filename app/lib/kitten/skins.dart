/// The kitten catalogue: pure data, drawn by `painter.dart`.
library;

import 'dart:convert';
import 'dart:math' as math;

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

enum CoatPattern { tintaUnita, tigrato, calico, point, macchie, soriano, panda, maculato }

extension CoatPatternInfo on CoatPattern {
  String get label => switch (this) {
    CoatPattern.tintaUnita => 'Tinta unita',
    CoatPattern.tigrato => 'Tigrato',
    CoatPattern.calico => 'Tricolore',
    CoatPattern.point => 'Siamese',
    CoatPattern.macchie => 'A macchie',
    CoatPattern.soriano => 'Soriano',
    CoatPattern.panda => 'Panda',
    CoatPattern.maculato => 'Maculato',
  };
}

enum EyeStyle { puntini, dorati, azzurri, verdi }

extension EyeStyleInfo on EyeStyle {
  String get label => switch (this) {
    EyeStyle.puntini => 'Puntini',
    EyeStyle.dorati => 'Dorati',
    EyeStyle.azzurri => 'Azzurri',
    EyeStyle.verdi => 'Verdi',
  };
}

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
  cappelloMago,
  cappelloStrega,
  aureola,
  ali,
  aliDrago,
  cornine,
  cappelloChef,
  bandana,
  cappelloFesta,
  girasole,
  casco,
  papillon,
  antennine,
  cappuccioRana,
  cappelloCowboy,
  cappelloFragola,
  ciliegie,
  tiara,
  cornoUnicorno,
}

extension AccessoryInfo on Accessory {
  /// Worn at the neck or on the back (the second slot when you make a kitten).
  bool get neckOrBack => const {
    Accessory.sciarpa,
    Accessory.campanella,
    Accessory.papillon,
    Accessory.mantello,
    Accessory.ali,
    Accessory.aliDrago,
  }.contains(this);

  String get label => switch (this) {
    Accessory.nessuno => 'Niente',
    Accessory.fiocco => 'Fiocco',
    Accessory.sciarpa => 'Sciarpa',
    Accessory.campanella => 'Collarino',
    Accessory.cuffie => 'Cuffie',
    Accessory.berretto => 'Berretto',
    Accessory.basco => 'Basco',
    Accessory.coronaFiori => 'Coroncina di fiori',
    Accessory.occhiali => 'Occhiali',
    Accessory.germoglio => 'Germoglio',
    Accessory.corona => 'Corona',
    Accessory.mantello => 'Mantello',
    Accessory.lunaFermaglio => 'Fermaglio luna',
    Accessory.coronaFoglie => 'Corona di foglie',
    Accessory.cappelloMago => 'Cappello da mago',
    Accessory.cappelloStrega => 'Cappello da strega',
    Accessory.aureola => 'Aureola',
    Accessory.ali => 'Ali',
    Accessory.aliDrago => 'Ali di drago',
    Accessory.cornine => 'Cornini',
    Accessory.cappelloChef => 'Cappello da chef',
    Accessory.bandana => 'Bandana',
    Accessory.cappelloFesta => 'Cappellino da festa',
    Accessory.girasole => 'Girasole',
    Accessory.casco => 'Casco spaziale',
    Accessory.papillon => 'Papillon',
    Accessory.antennine => 'Antennine',
    Accessory.cappuccioRana => 'Cappuccio rana',
    Accessory.cappelloCowboy => 'Cappello da cowboy',
    Accessory.cappelloFragola => 'Cappello fragola',
    Accessory.ciliegie => 'Ciliegie',
    Accessory.tiara => 'Tiara',
    Accessory.cornoUnicorno => 'Corno di unicorno',
  };
}

enum Effect {
  nessuno,
  stelle,
  scintille,
  petali,
  lucciole,
  note,
  pittura,
  codaArcobaleno,
  sciarpaVento,
  fluttua,
  fantasma,
  magia,
  bolle,
  neve,
  cuori,
  stelleCadenti,
  coriandoli,
  fuochiFatui,
  pioggia,
  fulmini,
  foglie,
  braci,
  piumino,
  smeraldi,
  farfalle,
}

extension EffectInfo on Effect {
  String get label => switch (this) {
    Effect.nessuno => 'Niente',
    Effect.stelle => 'Pelo stellato',
    Effect.scintille => 'Scintille',
    Effect.petali => 'Petali',
    Effect.lucciole => 'Lucciole',
    Effect.note => 'Note musicali',
    Effect.pittura => 'Macchie di colore',
    Effect.codaArcobaleno => 'Coda arcobaleno',
    Effect.sciarpaVento => 'Sciarpa al vento',
    Effect.fluttua => 'Fluttua',
    Effect.fantasma => 'Fantasma',
    Effect.magia => 'Magia',
    Effect.bolle => 'Bolle',
    Effect.neve => 'Neve',
    Effect.cuori => 'Cuori',
    Effect.stelleCadenti => 'Stelle cadenti',
    Effect.coriandoli => 'Coriandoli',
    Effect.fuochiFatui => 'Fuochi fatui',
    Effect.pioggia => 'Pioggerella',
    Effect.fulmini => 'Fulmini',
    Effect.foglie => 'Foglie',
    Effect.braci => 'Braci',
    Effect.piumino => 'Piumino giallo',
    Effect.smeraldi => 'Scintille smeraldo',
    Effect.farfalle => 'Farfalle',
  };
}

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
    this.blackNose = false,
    this.fourth,
    this.darkOutline = false,
  });

  final CoatPattern pattern;
  final int base;

  /// Stripes, spots, points or the first calico patch colour.
  final int? second;

  /// Second calico patch colour.
  final int? third;
  final bool whiteMuzzle, whiteBelly, whitePaws, blaze;

  /// A black nose instead of the pink one (Minou's).
  final bool blackNose;

  /// A warm tone mixed into the coat in soft patches: the variegated look
  /// of a European cat (Wendy's).
  final int? fourth;

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
    this.effect2 = Effect.nessuno,
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
  final Effect effect2;
  final bool free;

  bool has(Effect e) => effect == e || effect2 == e;

  bool get isCustom => id.startsWith(kCustomPrefix);

  /// The look only (coat, pose, eyes, accessories, effects), for kittens you
  /// make yourself.
  Map<String, Object?> lookJson() => {
    'pattern': coat.pattern.name,
    'base': coat.base,
    'second': coat.second,
    'third': coat.third,
    'fourth': coat.fourth,
    'muzzle': coat.whiteMuzzle,
    'belly': coat.whiteBelly,
    'paws': coat.whitePaws,
    'blaze': coat.blaze,
    'blackNose': coat.blackNose,
    'pose': pose.name,
    'eyes': eyes.name,
    'acc': accessory.name,
    'accColor': accessoryColor,
    'acc2': accessory2.name,
    'acc2Color': accessory2Color,
    'fx': effect.name,
    'fx2': effect2.name,
  };

  static Skin fromLook(String id, String name, Map<String, Object?> j) {
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.where((e) => e.name == v).firstOrNull ?? fallback;
    final base = (j['base'] as int?) ?? 0xFFF3AE6B;
    return Skin(
      id: id,
      name: name,
      rarity: Rarity.comune,
      price: 0,
      coat: Coat(
        pattern: pick(CoatPattern.values, j['pattern'], CoatPattern.tintaUnita),
        base: base,
        second: j['second'] as int?,
        third: j['third'] as int?,
        fourth: j['fourth'] as int?,
        whiteMuzzle: j['muzzle'] == true,
        whiteBelly: j['belly'] == true,
        whitePaws: j['paws'] == true,
        blaze: j['blaze'] == true,
        blackNose: j['blackNose'] == true || j['noseSpot'] == true,
        darkOutline: _luminance(base) < 0.12,
      ),
      pose: pick(Pose.values, j['pose'], Pose.seduto),
      eyes: pick(EyeStyle.values, j['eyes'], EyeStyle.puntini),
      accessory: pick(Accessory.values, j['acc'], Accessory.nessuno),
      accessoryColor: (j['accColor'] as int?) ?? 0xFFE89BBE,
      accessory2: pick(Accessory.values, j['acc2'], Accessory.nessuno),
      accessory2Color: (j['acc2Color'] as int?) ?? 0xFFF2C94C,
      effect: pick(Effect.values, j['fx'], Effect.nessuno),
      effect2: pick(Effect.values, j['fx2'], Effect.nessuno),
    );
  }
}

/// Relative luminance of an ARGB colour (sRGB), without Flutter.
double _luminance(int argb) {
  double ch(int v) {
    final c = v / 255;
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch((argb >> 16) & 0xFF) + 0.7152 * ch((argb >> 8) & 0xFF) + 0.0722 * ch(argb & 0xFF);
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
    effect2: Effect.stelleCadenti,
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
    effect2: Effect.scintille,
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
    effect2: Effect.scintille,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _lavGrey, whiteMuzzle: true),
  ),

  // --- 2.1: altri 20 ---------------------------------------------------------
  Skin(
    id: 'girasole',
    name: 'Girasole',
    rarity: Rarity.comune,
    price: 110,
    accessory: Accessory.girasole,
    accessoryColor: 0xFFF6CF5E,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _cream, whiteMuzzle: true),
  ),
  Skin(
    id: 'marshmallow',
    name: 'Marshmallow',
    rarity: Rarity.comune,
    price: 90,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFF6D6DC, whiteMuzzle: true),
  ),
  Skin(
    id: 'tofu',
    name: 'Tofu',
    rarity: Rarity.comune,
    price: 70,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _white),
  ),
  Skin(
    id: 'mirtillo',
    name: 'Mirtillo',
    rarity: Rarity.comune,
    price: 130,
    coat: Coat(pattern: CoatPattern.macchie, base: 0xFFDCE0EA, second: 0xFFA3ADC4),
  ),
  Skin(
    id: 'oreo',
    name: 'Oreo',
    rarity: Rarity.comune,
    price: 150,
    pose: Pose.pagnotta,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: _black,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
      darkOutline: true,
    ),
  ),
  Skin(
    id: 'bolla',
    name: 'Bolla',
    rarity: Rarity.raro,
    price: 380,
    effect: Effect.bolle,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFCFDCE8, whiteMuzzle: true, whiteBelly: true),
  ),
  Skin(
    id: 'chef',
    name: 'Chef Pepe',
    rarity: Rarity.raro,
    price: 420,
    accessory: Accessory.cappelloChef,
    accessoryColor: 0xFFFFFAF3,
    coat: Coat(pattern: CoatPattern.tigrato, base: _grey, second: _greyStripe, whiteMuzzle: true),
  ),
  Skin(
    id: 'pirata',
    name: 'Pirata',
    rarity: Rarity.raro,
    price: 460,
    accessory: Accessory.bandana,
    accessoryColor: 0xFFE58C8C,
    coat: Coat(pattern: CoatPattern.tigrato, base: _orange, second: _orangeStripe, whiteMuzzle: true),
  ),
  Skin(
    id: 'festa',
    name: 'Festa',
    rarity: Rarity.raro,
    price: 520,
    accessory: Accessory.cappelloFesta,
    accessoryColor: 0xFF9DC7EA,
    effect: Effect.coriandoli,
    coat: Coat(pattern: CoatPattern.calico, base: _white, second: _caramel, third: _charcoal),
  ),
  Skin(
    id: 'neve',
    name: 'Fiocco di Neve',
    rarity: Rarity.raro,
    price: 580,
    accessory: Accessory.berretto,
    accessoryColor: 0xFFA9C8EC,
    effect: Effect.neve,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFEEF2F8, whiteMuzzle: true),
  ),
  Skin(
    id: 'piuma',
    name: 'Piuma',
    rarity: Rarity.epico,
    price: 1000,
    effect: Effect.fluttua,
    accessory: Accessory.fiocco,
    accessoryColor: 0xFFC6A8F2,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _white),
  ),
  Skin(
    id: 'merlino',
    name: 'Merlino',
    rarity: Rarity.epico,
    price: 1100,
    accessory: Accessory.cappelloMago,
    accessoryColor: 0xFF8D9DDA,
    effect: Effect.magia,
    coat: Coat(pattern: CoatPattern.tigrato, base: 0xFFC3BDCC, second: 0xFF9C93AA, whiteMuzzle: true),
  ),
  Skin(
    id: 'diavoletto',
    name: 'Diavoletto',
    rarity: Rarity.epico,
    price: 1150,
    accessory: Accessory.cornine,
    accessoryColor: 0xFFE88A8A,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFDDBEC4, whiteMuzzle: true),
  ),
  Skin(
    id: 'salem',
    name: 'Salem',
    rarity: Rarity.epico,
    price: 1250,
    eyes: EyeStyle.dorati,
    accessory: Accessory.cappelloStrega,
    accessoryColor: 0xFF4A3F5C,
    effect: Effect.fuochiFatui,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _black, darkOutline: true),
  ),
  Skin(
    id: 'cupido',
    name: 'Cupido',
    rarity: Rarity.epico,
    price: 1300,
    accessory2: Accessory.ali,
    accessory2Color: 0xFFFFFAF3,
    effect: Effect.cuori,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _peachSoft, whiteMuzzle: true),
  ),
  Skin(
    id: 'astronauta',
    name: 'Astronauta',
    rarity: Rarity.epico,
    price: 1450,
    accessory: Accessory.casco,
    effect: Effect.fluttua,
    effect2: Effect.stelleCadenti,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _lightGrey, whiteMuzzle: true, whiteBelly: true),
  ),
  Skin(
    id: 'cometa',
    name: 'Cometa',
    rarity: Rarity.leggendario,
    price: 2800,
    eyes: EyeStyle.azzurri,
    effect: Effect.stelleCadenti,
    effect2: Effect.scintille,
    coat: Coat(pattern: CoatPattern.point, base: 0xFFEDEBF6, second: 0xFF7C80B4),
  ),
  Skin(
    id: 'angioletto',
    name: 'Angioletto',
    rarity: Rarity.leggendario,
    price: 3300,
    accessory: Accessory.aureola,
    accessoryColor: 0xFFF2D27C,
    accessory2: Accessory.ali,
    accessory2Color: 0xFFFFFAF3,
    effect: Effect.fluttua,
    effect2: Effect.scintille,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _white),
  ),
  Skin(
    id: 'fantasmino',
    name: 'Fantasmino',
    rarity: Rarity.leggendario,
    price: 3600,
    effect: Effect.fantasma,
    effect2: Effect.fuochiFatui,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFF4F6FA),
  ),
  Skin(
    id: 'drago',
    name: 'Draghetto',
    rarity: Rarity.leggendario,
    price: 4200,
    accessory: Accessory.cornine,
    accessoryColor: 0xFFF2D27C,
    accessory2: Accessory.aliDrago,
    accessory2Color: 0xFF9FD0A8,
    effect: Effect.scintille,
    coat: Coat(pattern: CoatPattern.macchie, base: 0xFFC4E3C4, second: 0xFF9FCBA2, whiteMuzzle: true),
  ),

  // --- 2.2: altri 17 ---------------------------------------------------------
  Skin(
    id: 'pesca',
    name: 'Pesca',
    rarity: Rarity.comune,
    price: 100,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFF7C7A6, whiteMuzzle: true, whitePaws: true),
  ),
  Skin(
    id: 'perla',
    name: 'Perla',
    rarity: Rarity.comune,
    price: 140,
    pose: Pose.pagnotta,
    eyes: EyeStyle.dorati,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFA9B3C2),
  ),
  Skin(
    id: 'bruno',
    name: 'Bruno',
    rarity: Rarity.comune,
    price: 120,
    pose: Pose.pagnotta,
    accessory2: Accessory.papillon,
    accessory2Color: 0xFFE57B7B,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: _chocolate, whiteMuzzle: true),
  ),
  Skin(
    id: 'ciliegia',
    name: 'Ciliegia',
    rarity: Rarity.comune,
    price: 160,
    accessory: Accessory.ciliegie,
    accessoryColor: 0xFFE8646E,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFFBEFE3, whiteMuzzle: true),
  ),
  // Wendy and Minou are drawn from two real cats: keep them close to the
  // photos (green eyes, spotted tabby; tuxedo with a smudge on the nose).
  Skin(
    id: 'wendy',
    name: 'Wendy',
    rarity: Rarity.leggendario,
    price: 4800,
    eyes: EyeStyle.verdi,
    effect: Effect.farfalle,
    effect2: Effect.smeraldi,
    coat: Coat(
      pattern: CoatPattern.maculato,
      base: 0xFFA39A90,
      second: 0xFF4F453F,
      third: 0xFFEADFCF,
      fourth: 0xFFC89A6E,
      whiteMuzzle: true,
    ),
  ),
  Skin(
    id: 'minou',
    name: 'Minou',
    rarity: Rarity.leggendario,
    price: 4800,
    eyes: EyeStyle.dorati,
    effect: Effect.piumino,
    effect2: Effect.scintille,
    coat: Coat(
      pattern: CoatPattern.tintaUnita,
      base: 0xFF3E3637,
      whiteMuzzle: true,
      whiteBelly: true,
      whitePaws: true,
      blaze: true,
      blackNose: true,
      darkOutline: true,
    ),
  ),
  Skin(
    id: 'panda',
    name: 'Panda',
    rarity: Rarity.raro,
    price: 520,
    pose: Pose.pagnotta,
    coat: Coat(pattern: CoatPattern.panda, base: _white, second: 0xFF5B5254),
  ),
  Skin(
    id: 'apetta',
    name: 'Apetta',
    rarity: Rarity.raro,
    price: 540,
    accessory: Accessory.antennine,
    accessoryColor: 0xFF5A3E36,
    accessory2: Accessory.ali,
    accessory2Color: 0xFFEAF4FB,
    coat: Coat(pattern: CoatPattern.tigrato, base: 0xFFF6D57A, second: 0xFF9C7158, whiteMuzzle: true),
  ),
  Skin(
    id: 'ranocchio',
    name: 'Ranocchio',
    rarity: Rarity.raro,
    price: 560,
    pose: Pose.pagnotta,
    accessory: Accessory.cappuccioRana,
    accessoryColor: 0xFF9BCF8E,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFF3E6CF, whiteMuzzle: true),
  ),
  Skin(
    id: 'cowboy',
    name: 'Cowboy',
    rarity: Rarity.raro,
    price: 500,
    accessory: Accessory.cappelloCowboy,
    accessoryColor: 0xFFC39466,
    coat: Coat(pattern: CoatPattern.tigrato, base: _caramel, second: 0xFFB77E4E, whiteMuzzle: true, whitePaws: true),
  ),
  Skin(
    id: 'fragolina',
    name: 'Fragolina',
    rarity: Rarity.raro,
    price: 420,
    accessory: Accessory.cappelloFragola,
    accessoryColor: 0xFFEF7F86,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFFFF1EC, whiteMuzzle: true),
  ),
  Skin(
    id: 'pioggerella',
    name: 'Pioggerella',
    rarity: Rarity.epico,
    price: 1150,
    effect: Effect.pioggia,
    accessory2: Accessory.sciarpa,
    accessory2Color: 0xFFF6D46E,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFB9C4D6, whiteMuzzle: true, whiteBelly: true),
  ),
  Skin(
    id: 'tempesta',
    name: 'Tempesta',
    rarity: Rarity.epico,
    price: 1350,
    eyes: EyeStyle.azzurri,
    effect: Effect.fulmini,
    coat: Coat(pattern: CoatPattern.macchie, base: 0xFF9AA2B2, second: 0xFF737B8E),
  ),
  Skin(
    id: 'autunno',
    name: 'Autunno',
    rarity: Rarity.epico,
    price: 1100,
    effect: Effect.foglie,
    accessory2: Accessory.sciarpa,
    accessory2Color: 0xFFE59A5B,
    coat: Coat(pattern: CoatPattern.tigrato, base: _caramel, second: _brownStripe, whiteMuzzle: true),
  ),
  Skin(
    id: 'duchessa',
    name: 'Duchessa',
    rarity: Rarity.epico,
    price: 1400,
    eyes: EyeStyle.azzurri,
    accessory: Accessory.tiara,
    accessoryColor: 0xFFE3DDEE,
    accessory2: Accessory.campanella,
    accessory2Color: 0xFFC6A8F2,
    coat: Coat(pattern: CoatPattern.point, base: _cream, second: 0xFFB6A09A),
  ),
  Skin(
    id: 'unicorno',
    name: 'Unicorno',
    rarity: Rarity.leggendario,
    price: 4400,
    eyes: EyeStyle.azzurri,
    accessory: Accessory.cornoUnicorno,
    accessoryColor: 0xFFF2D27C,
    effect: Effect.codaArcobaleno,
    effect2: Effect.scintille,
    coat: Coat(pattern: CoatPattern.tintaUnita, base: 0xFFFBF7FF),
  ),
  Skin(
    id: 'fenice',
    name: 'Fenice',
    rarity: Rarity.leggendario,
    price: 4600,
    eyes: EyeStyle.dorati,
    accessory2: Accessory.ali,
    accessory2Color: 0xFFF6C66B,
    effect: Effect.braci,
    effect2: Effect.scintille,
    coat: Coat(pattern: CoatPattern.tigrato, base: 0xFFF4A261, second: 0xFFE07A5F, whiteMuzzle: true),
  ),
];

final Map<String, Skin> kSkinById = {for (final s in kSkins) s.id: s};

/// Ids of kittens you made start with this, followed by their row id.
const String kCustomPrefix = 'custom_';
const int kMaxCustomSkins = 5;

/// Kittens made in "Crea il tuo gattino", kept in step with the database by
/// `main.dart` (deleted ones too, so old sessions still draw them).
final Map<String, Skin> kCustomSkins = {};
final List<String> _liveCustomIds = [];

/// The kittens you made that were not deleted, oldest first.
List<Skin> get myCustomSkins => [for (final id in _liveCustomIds) kCustomSkins[id]!];

Skin skinById(String? id) => kSkinById[id] ?? kCustomSkins[id] ?? kSkins.first;

/// Rebuilds [kCustomSkins] from database rows.
void loadCustomSkins(Iterable<({int id, String name, String spec, bool deleted})> rows) {
  kCustomSkins.clear();
  _liveCustomIds.clear();
  for (final r in rows) {
    final id = '$kCustomPrefix${r.id}';
    Map<String, Object?> look;
    try {
      look = (jsonDecode(r.spec) as Map).cast<String, Object?>();
    } on FormatException {
      look = const {};
    }
    kCustomSkins[id] = Skin.fromLook(id, r.name, look);
    if (!r.deleted) _liveCustomIds.add(id);
  }
}

/// What "Crea il tuo gattino" offers: every style of the kittens you own.
class KittenParts {
  KittenParts(Iterable<Skin> owned) {
    void add<T>(List<T> list, T v) {
      if (!list.contains(v)) list.add(v);
    }

    for (final s in owned) {
      final c = s.coat;
      add(coats, c.base);
      if (c.pattern != CoatPattern.tintaUnita) add(patterns, (c.pattern, c.second, c.third, c.fourth));
      muzzle |= c.whiteMuzzle;
      blackNose |= c.blackNose;
      blaze |= c.blaze;
      belly |= c.whiteBelly;
      paws |= c.whitePaws;
      add(eyes, s.eyes);
      for (final (a, col) in [(s.accessory, s.accessoryColor), (s.accessory2, s.accessory2Color)]) {
        if (a == Accessory.nessuno) continue;
        add(a.neckOrBack ? neck : head, (a, col));
      }
      for (final e in [s.effect, s.effect2]) {
        if (e != Effect.nessuno) add(effects, e);
      }
    }
  }

  final List<int> coats = [];
  final List<(CoatPattern, int?, int?, int?)> patterns = [(CoatPattern.tintaUnita, null, null, null)];
  bool muzzle = false, blaze = false, belly = false, paws = false, blackNose = false;
  final List<EyeStyle> eyes = [EyeStyle.puntini];
  final List<(Accessory, int)> head = [(Accessory.nessuno, 0)];
  final List<(Accessory, int)> neck = [(Accessory.nessuno, 0)];
  final List<Effect> effects = [Effect.nessuno];

  /// Styles unlocked, out of everything the catalogue has, for the hint.
  int get count =>
      coats.length + patterns.length + eyes.length + head.length + neck.length + effects.length +
      [muzzle, blaze, belly, paws, blackNose].where((b) => b).length;

  static final int total = KittenParts(kSkins).count;
}

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
