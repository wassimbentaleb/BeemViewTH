# Beem View 360

A Flutter mobile app for the BeemView take-home assignment, built from the
supplied screen designs.

## Current step

Login now uses the API. The form validates email/password, supports password
visibility and autofill, and scrolls when the keyboard opens. During login,
inputs and the submit button are disabled. API errors preserve the entered text.

The token is saved securely; the password is not stored by the app. On restart,
the app checks the saved token with the current-user profile endpoint before
opening the authenticated area. A protected HTTP 401 clears the session. HTTP
403 or a network failure during restoration keeps the saved token and offers
Retry or an explicit return to login. Signing out clears the local session.

The authenticated Projects screen loads projects in pages of ten and shows the
user's name. Load more appends the next page, replaces duplicate IDs, blocks
duplicate requests and disappears after the final page. Its avatar opens the
account menu with Sign out. Empty results show Reload; request failures show
Retry. A failed next page keeps the loaded cards and retries the same offset.
Project selection and task screens follow later.

## Run

Built with Flutter 3.47.2 and Dart 3.13.2.

```sh
flutter pub get
```

Copy `config/app.example.json` to `config/app.local.json` and fill in the assigned
tenant subdomain. `API_ORIGIN` defaults to `https://beemview.com`. The tenant is
configuration; email and password are entered in the form. The local file is
ignored by Git and contains no password.

```sh
flutter run --dart-define-from-file=config/app.local.json
```

Choose a connected Android device or emulator. For a browser preview:

```sh
flutter run -d chrome --dart-define-from-file=config/app.local.json
```

Browser API access also requires the server to allow the preview's origin through
CORS. Web secure storage requires HTTPS or localhost.

## Structure

```text
lib/
  main.dart                  Initializes Flutter and starts the app.
  app.dart                   Creates services and chooses the session screen.
  core/app_theme.dart        Shared colors, font, inputs and buttons.
  core/validators.dart       Email and password rules.
  core/app_config.dart       API origin and tenant configuration.
  core/api_exception.dart    Useful API errors with HTTP status codes.
  models/                    Typed user, login session and project data.
  services/                  HTTP, authentication, project pages and token storage.
  controllers/               Session and projects state, loading and errors.
  screens/                   Login, session check and Projects list.
  widgets/brand_logo.dart    Shared brand symbol and wordmark.
```

The request flow is **screen -> controller -> service -> API**. Screens
display state; controllers manage loading and errors; services call endpoints;
models turn response JSON into Dart objects.

`AuthController` uses Flutter's `ChangeNotifier`; `ListenableBuilder` rebuilds
the interface when its state changes. Password visibility uses local `setState`
because it only affects the form. Changing the authenticated user also resets
navigation, so sign-out or expiry removes authenticated pages from the back stack.
New logical blocks have short French comments explaining their purpose.

## Configuration and dependencies

`http` 1.6.0 handles JSON requests, bearer headers and a 20-second timeout.
[`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
11.2.0 stores the token with Android encryption and iOS Keychain.
The brand symbol and Plus Jakarta Sans font
are bundled locally. The font's license is included in `assets/fonts/OFL.txt`.

Android internet access is enabled and automatic backup is disabled for the
encrypted session. iOS Keychain entitlements are configured for all build modes;
an iOS build requires macOS and Xcode.

Credentials, tokens, local reference images and temporary previews are excluded
from source control. No automatic login or request retry uses saved credentials.

## Checks

```sh
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/app.local.json
```

The tests cover validation, compact layout, password visibility, request
payloads, profile parsing, duplicate submissions, token storage, restoration,
401 versus 403, retained input on API failure, successful login and sign-out.
Project tests also check data mapping, response envelopes, bearer headers,
pagination parameters, duplicate IDs, retained cards on retry, empty states,
401/403 session behavior, loading and long names with enlarged text.
HTTP and storage are simulated in these tests. The real login/profile and
project-list APIs have also been checked with the supplied test account.

The debug APK was built and installed on an Android API 36 emulator. Real form
login, session restoration after a full app restart, and sign-out were verified.

Task endpoints are not implemented yet. There is no refresh-token or
server logout endpoint in the assignment contract.
