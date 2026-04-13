/// Pack artwork for [OpenPacksPage]. Add PNG files under `assets/images/pack_tiles/`.
/// See `assets/images/pack_tiles/PACK_IMAGES.txt` for filenames.
abstract final class PackImagePaths {
  static const String _dir = 'assets/images/pack_tiles';

  static const String standardPack = '$_dir/standard_pack.png';
  static const String premiumPack = '$_dir/premium_pack.png';
  static const String specialPack = '$_dir/special_pack.png';
  static const String eventPack = '$_dir/event_pack.png';
}
