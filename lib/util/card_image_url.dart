import 'package:flutter/material.dart';

import '../config/backend_config.dart';

/// Bundled play card art: `assets/images/cards/<card_id>.png` (e.g. card 1 → `assets/images/cards/1.png`).
///
/// **Must match** `play_cards.card_id` exactly. Use **PNG**; other extensions are not tried here.
/// Declare the folder in `pubspec.yaml` (`assets/images/cards/`) and do a **full restart** after adding files.
String bundledPlayCardAssetPath(int cardId) => 'assets/images/cards/$cardId.png';

Widget _networkCardImage({
  required String? rawUrl,
  required BoxFit fit,
  required double? width,
  required double? height,
  required Widget errorPlaceholder,
}) {
  final u = displayableCardImageUrl(rawUrl);
  if (u == null || u.isEmpty) return errorPlaceholder;
  return Image.network(
    u,
    fit: fit,
    width: width,
    height: height,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => errorPlaceholder,
  );
}

/// Local PNG first; if missing and [fallbackImageUrl] is set (e.g. `play_cards.card_image`), loads that URL.
class BundledPlayCardImage extends StatelessWidget {
  const BundledPlayCardImage({
    super.key,
    required this.cardId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    required this.errorPlaceholder,
    this.fallbackImageUrl,
  });

  final int cardId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget errorPlaceholder;
  /// When the bundled asset is missing, try this (Drive URL, https, or API path).
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    if (cardId <= 0) return errorPlaceholder;
    return Image.asset(
      bundledPlayCardAssetPath(cardId),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _networkCardImage(
        rawUrl: fallbackImageUrl,
        fit: fit,
        width: width,
        height: height,
        errorPlaceholder: errorPlaceholder,
      ),
    );
  }
}

/// Turns stored `card_image` values into a URL [Image.network] can load.
///
/// Kept for legacy data or non-bundled URLs. **Play card UI** should use [BundledPlayCardImage] instead.
///
/// **Google Drive:** `uc?export=view` often returns HTML (virus-scan page, etc.), not image bytes.
/// We route Drive file IDs through your Node API (`GET /card-image/:id`), which fetches real image data.
/// The file must still be shared as **Anyone with the link** (viewer).
String? displayableCardImageUrl(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  final base = BackendConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');

  if (s.startsWith('http://') || s.startsWith('https://')) {
    final driveId = extractGoogleDriveFileId(s);
    if (driveId != null) {
      return '$base/card-image/$driveId';
    }
    return s;
  }

  return s.startsWith('/') ? '$base$s' : '$base/$s';
}

/// Returns the file id from a Drive URL, or null if not a recognized Drive link.
String? extractGoogleDriveFileId(String url) {
  final lower = url.toLowerCase();
  if (!lower.contains('drive.google.com')) return null;

  final filePath = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
  if (filePath != null) return filePath.group(1);

  final idParam = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
  if (idParam != null) return idParam.group(1);

  return null;
}
