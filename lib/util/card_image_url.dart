import '../config/backend_config.dart';

/// Turns stored `card_image` values into a URL [Image.network] can load.
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
