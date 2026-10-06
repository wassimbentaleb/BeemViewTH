# Beem View 360

A Flutter mobile app for the BeemView take-home assignment.

## Current step

Login now calls the API and saves the token with secure storage before
opening the temporary Projects landing page. The password is not stored.
Restoration after restarting the app and sign-out are the next changes.

The form validates email/password, supports password visibility and autofill,
and scrolls on small screens or when the keyboard opens. Project lists, tasks,
details and status updates have not been implemented yet.

## Run and configuration

Built with Flutter 3.47.2 and Dart 3.13.2.
Copy `config/app.example.json` to `config/app.local.json` and set the assigned
tenant subdomain. The local file is ignored by Git and contains no password.
The default API origin is `https://beemview.com`.

```sh
flutter pub get
flutter run --dart-define-from-file=config/app.local.json
```

Enter email and password in the form; the tenant is app configuration.
An Android device/emulator is the mobile target. A browser preview can use
`flutter run -d chrome --dart-define-from-file=config/app.local.json`.
API calls from a browser require the server to allow the preview origin via CORS.
An iOS build requires macOS and Xcode.

## Structure

`core/` contains shared theme, validation and configuration. API requests live
in `services/`, response types in `models/`, state in `controllers/` and UI in
`screens/`. Files are added when their behavior is implemented.
The request flow is screen -> controller -> service -> API. Password visibility
uses local `setState`; authentication uses `ChangeNotifier` and `ListenableBuilder`.
New logical blocks have short French comments explaining their purpose.

## Dependencies and checks

`http` 1.6.0 handles JSON requests, bearer headers and a 20-second timeout.
`flutter_secure_storage` 11.2.0 stores the token using platform secure storage.
Android backup is disabled and iOS Keychain entitlements are configured.
The brand image and Plus Jakarta Sans font are bundled locally; the font license
is included in `assets/fonts/OFL.txt`. Credentials, tokens and previews are ignored.

```sh
flutter analyze
flutter test
```
