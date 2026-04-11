

### Terminal 1 — API server

ftah project b cmd:
cd api
npm start


Leave this running. Default base URL is usually `http://127.0.0.1:3000` (see `lib/config/backend_config.dart`).

### Terminal 2 — Player A (Chrome)

ftah project b tene cmd
flutter run -d chrome --dart-define=DEV_USER_ID=1


### Terminal 3 — Player B (Edge)

ftah project b telit cmd
flutter run -d edge --dart-define=DEV_USER_ID=2

