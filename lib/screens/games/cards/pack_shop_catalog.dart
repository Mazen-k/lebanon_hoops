import 'package:flutter/foundation.dart';

/// Folder where pack list artwork lives. Filenames must match [imageFileName].
const String kPackShopImageDir = 'assets/images/pack_shop';

/// One row on the Open packs screen.
///
/// Edit **`pack_shop_catalog.dart`** for title, [descriptionLines], [priceCoins], and [imageFileName].
/// Server must recognize [apiPackId] (see `api/server.mjs` pack open handler).
@immutable
class PackShopItem {
  const PackShopItem({
    required this.id,
    required this.apiPackId,
    required this.imageFileName,
    required this.title,
    required this.descriptionLines,
    required this.priceCoins,
  });

  final String id;
  /// Sent in POST `/packs/open` as `packId`.
  final String apiPackId;
  final String imageFileName;
  final String title;
  final List<String> descriptionLines;
  final int priceCoins;

  String get imageAssetPath => '$kPackShopImageDir/$imageFileName';
}

/// Packs listed on [OpenPacksPage].
const List<PackShopItem> kPackShopCatalog = [
  PackShopItem(
    id: 'lebanese_base',
    apiPackId: 'lebanese_base',
    imageFileName: 'LebaneseBasePack.png',
    title: 'Lebanese Base Pack',
    descriptionLines: [
      'Guranteed 4 Lebanese base cards.',
    ],
    priceCoins: 5,
  ),
  PackShopItem(
    id: 'import_chance',
    apiPackId: 'import_chance',
    imageFileName: 'ImportChancePick.png',
    title: 'Import Chance Pick',
    descriptionLines: [
      'Guranteed 3 Base cards with chance of 1 import',
    ],
    priceCoins: 7,
  ),
];

String formatCoinsWithCommas(int value) {
  if (value == 0) return 'Free';
  final s = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
