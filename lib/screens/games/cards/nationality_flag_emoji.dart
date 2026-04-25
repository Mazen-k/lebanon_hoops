import 'nationality_iso_data.dart';

/// Shown when a nationality string cannot be mapped to an ISO alpha-2 code.
const String kNationalityFallbackEmoji = '\u{1F30D}';

/// Unicode regional-indicator flag from ISO 3166-1 alpha-2 (e.g. `LB` → 🇱🇧).
String? flagEmojiFromIsoAlpha2(String iso2) {
  if (iso2.length != 2) return null;
  final a = iso2.toUpperCase();
  final c0 = a.codeUnitAt(0);
  final c1 = a.codeUnitAt(1);
  if (c0 < 0x41 || c0 > 0x5A || c1 < 0x41 || c1 > 0x5A) return null;
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCode(c0 + base) + String.fromCharCode(c1 + base);
}

String _normalizeNationalityToken(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = s.split(RegExp(r'[|/]')).first.trim();
  s = s.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  return s;
}

String _nameKey(String s) {
  final u = s.toUpperCase();
  final buf = StringBuffer();
  for (var i = 0; i < u.length; i++) {
    final c = u.codeUnitAt(i);
    final isAlnum = (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A);
    buf.writeCharCode(isAlnum ? c : 0x20);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _resolveNationalityToIso2(String raw) {
  final token = _normalizeNationalityToken(raw);
  if (token.isEmpty) return null;
  final u = token.toUpperCase();

  if (u.length == 2) {
    final c0 = u.codeUnitAt(0);
    final c1 = u.codeUnitAt(1);
    if (c0 >= 0x41 && c0 <= 0x5A && c1 >= 0x41 && c1 <= 0x5A) {
      return u;
    }
  }

  if (u.length == 3) {
    final c0 = u.codeUnitAt(0);
    final c1 = u.codeUnitAt(1);
    final c2 = u.codeUnitAt(2);
    final allLetters =
        c0 >= 0x41 &&
        c0 <= 0x5A &&
        c1 >= 0x41 &&
        c1 <= 0x5A &&
        c2 >= 0x41 &&
        c2 <= 0x5A;
    if (allLetters) {
      final from3 = kNationalityAlpha3ToAlpha2[u];
      if (from3 != null) return from3;
    }
  }

  final key = _nameKey(token);
  if (key.isNotEmpty) {
    final hit = kNationalityNameKeyToAlpha2[key];
    if (hit != null) return hit;
  }

  final parts = key.split(' ');
  if (parts.length > 1) {
    final first = parts.first;
    if (first.length == 3) {
      final from3 = kNationalityAlpha3ToAlpha2[first];
      if (from3 != null) return from3;
    }
    final fromName = kNationalityNameKeyToAlpha2[first];
    if (fromName != null) return fromName;
  }

  return null;
}

/// Resolves a `players.nationality`-style string to a flag emoji.
String? nationalityValueToFlagEmoji(String raw) {
  final iso = _resolveNationalityToIso2(raw);
  if (iso == null) return null;
  return flagEmojiFromIsoAlpha2(iso);
}

/// Flag for UI, never null (uses [kNationalityFallbackEmoji]).
String nationalityValueToFlagEmojiOrFallback(String raw) =>
    nationalityValueToFlagEmoji(raw) ?? kNationalityFallbackEmoji;
