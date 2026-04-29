/// Backend / database configuration for Swish.
///
/// **Security:** The Flutter app must not open raw PostgreSQL connections.
/// Use the Node API in this repo at `api/` (`npm install` + `npm start`; see `api/package.json`).
///
/// Example server connection string:
/// `postgresql://postgres:admin@localhost:5432/BasketballApp`
abstract final class BackendConfig {
  /// Your running PostgreSQL database name.
  static const String postgresDatabaseName = 'BasketballApp';

  /// Typical Postgres port (change if yours differs).
  static const int postgresDefaultPort = 5432;

  /// Base URL of your REST API (no trailing slash required).
  ///
  /// | Where you run the app | Use this host for the API on your PC |
  /// | Chrome / Windows desktop | `http://127.0.0.1:PORT` |
  /// | Android emulator | `http://10.0.2.2:PORT` |
  /// | Physical phone (same Wi‑Fi as PC) | `http://YOUR_PC_LAN_IP:PORT` (e.g. `192.168.1.20`) |
  ///
  /// Phone will **not** work with `localhost` or `127.0.0.1` — that points at the phone itself.
  /// Find your PC IP: `ipconfig` (IPv4 Address). Allow the port in Windows Firewall if needed.
  ///
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'https://lebanon-hoops.onrender.com'; // Live Render API URL
  }

  /// Path to the teams list, appended after [apiBaseUrl] (no leading slash).
  ///
  /// Use `api/teams` if your server exposes that route instead of `/teams`.
  ///
  /// `flutter run --dart-define=API_TEAMS_PATH=api/teams`
  static String get teamsPath {
    const fromEnv = String.fromEnvironment('API_TEAMS_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'teams';
  }

  /// Until login returns a real `users.user_id`, pack opens use this id.
  ///
  /// `flutter run --dart-define=DEV_USER_ID=2`
  static int get devUserId {
    const raw = String.fromEnvironment('DEV_USER_ID', defaultValue: '1');
    return int.tryParse(raw) ?? 1;
  }

  /// GET path for user collection: `{path}?user_id=…` (distinct cards, sorted by overall).
  ///
  /// `flutter run --dart-define=API_COLLECTION_PATH=api/collection`
  static String get collectionPath {
    const fromEnv = String.fromEnvironment('API_COLLECTION_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'collection';
  }

  /// Duplicates use [collectionPath] with query `duplicates_only=1` (same host/route as collection).

  /// `GET {path}?user_id=…` — all play_cards + owned_count + on_wishlist.
  static String get catalogPath {
    const fromEnv = String.fromEnvironment('API_CATALOG_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'cards/catalog';
  }

  /// `GET` / `PUT` / `PATCH` wishlist for `user_id` (PATCH updates `msg` only).
  static String get wishlistPath {
    const fromEnv = String.fromEnvironment('API_WISHLIST_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'wishlist';
  }

  /// POST path for opening a pack (after [apiBaseUrl], no leading slash).
  ///
  /// If your API only mounts under `/api`, use `api/packs/open`.
  /// `flutter run --dart-define=API_PACKS_OPEN_PATH=api/packs/open`
  static String get packsOpenPath {
    const fromEnv = String.fromEnvironment('API_PACKS_OPEN_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'packs/open';
  }

  /// POST login: `{ "usernameOrEmail", "password" }`
  static String get authLoginPath {
    const fromEnv = String.fromEnvironment('API_AUTH_LOGIN_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'auth/login';
  }

  /// POST register: signup body
  static String get authRegisterPath {
    const fromEnv = String.fromEnvironment('API_AUTH_REGISTER_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'auth/register';
  }

  /// Court reservation (same [apiBaseUrl]): `GET public/courts`, `GET public/courts/:id/playgrounds`,
  /// `GET public/playgrounds/:id/availability?date=YYYY-MM-DD`, `POST public/reservations`
  /// with JSON `{ "user_id", "availability_id" }`. Apply `lebanon_hoops/DB/court_reservation_schema.sql` once if tables are missing.

  /// `GET ?user_id=…&squad_number=1..3` — 1v1 lineup; `PATCH` JSON body updates name and/or slots.
  static String get cardsSquadPath {
    const fromEnv = String.fromEnvironment('API_CARDS_SQUAD_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'cards/squad';
  }

  /// GET `?user_id=…` — returns `username` and `card_coins` for the cards hub header.
  static String get userWalletPath {
    const fromEnv = String.fromEnvironment('API_USER_WALLET_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'user/wallet';
  }

  /// `GET` active SBC challenges + requirements + reward card info.
  static String get sbcChallengesPath {
    const fromEnv = String.fromEnvironment('API_SBC_CHALLENGES_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'sbc/challenges';
  }

  /// `POST` SBC submit body: `{ user_id, sbc_id, slots:{pg,sg,sf,pf,c} }`.
  static String get sbcSubmitPath {
    const fromEnv = String.fromEnvironment('API_SBC_SUBMIT_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'sbc/submit';
  }

  /// GET `?category=…` — fan-shop items list; returns array of shop_items rows.
  static String get shopItemsPath {
    const fromEnv = String.fromEnvironment('API_SHOP_ITEMS_PATH', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv.trim().replaceAll(RegExp(r'^/+'), '');
    return 'shop/items';
  }
}
