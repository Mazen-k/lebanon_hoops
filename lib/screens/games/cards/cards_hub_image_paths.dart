/// Main card games hub artwork. Add PNGs under `assets/images/cards_hub/`.
/// See `assets/images/cards_hub/HUB_IMAGES.txt`.
abstract final class CardsHubImagePaths {
  static const String _dir = 'assets/images/cards_hub';

  /// Large top tile — opens pack shop.
  static const String packsHero = '$_dir/packs_hero.png';

  /// Wide button — 1v1 mode.
  static const String oneVOne = '$_dir/hub_1v1.png';

  static const String collection = '$_dir/hub_collection.png';
  static const String duplicates = '$_dir/hub_duplicates.png';
  static const String trading = '$_dir/hub_trading.png';
  static const String sbc = '$_dir/hub_sbc.png';
}
