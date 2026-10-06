# Beem View 360

A small Flutter mobile app for the BeemView take-home assignment.
The app is being built one step at a time, starting with the supplied login design.

## Current step

The login UI is implemented, including email/password validation, password
visibility, autofill hints and a layout that scrolls on small screens or when
the keyboard opens. The email shown in the design is a hint, not a saved value.
The password starts empty.

Authentication is not connected yet. Submitting a valid form shows that sign-in
is not available; it does not create a session or navigate to Projects.
Projects, tasks, task details and status updates are the next steps.

## Run

Built with Flutter 3.47.2 and Dart 3.13.2.

```sh
flutter pub get
flutter run
```

Choose a connected Android device or emulator. For a quick browser preview:

```sh
flutter run -d chrome
```

## Structure

```text
lib/
  main.dart                  Starts the app.
  app.dart                   MaterialApp and the initial screen.
  core/app_theme.dart        Shared colors, font, inputs and buttons.
  core/validators.dart       Email and password rules.
  screens/login_screen.dart  Login layout and form interaction.
  widgets/brand_logo.dart    Shared brand symbol and wordmark.
```

The screen uses `setState` for password visibility. That state only affects one
widget, so it stays in the screen. The next step will add a `ChangeNotifier`
controller for authentication, typed models and separate services for API calls
and secure token storage. Those files will be added when they have real behavior.

The planned request flow is **screen -> controller -> service -> API**. Screens
display state; controllers manage loading and errors; services call endpoints;
models turn response JSON into Dart objects.

## Configuration and dependencies

No runtime packages beyond Flutter are needed for this UI step. The brand symbol
and Plus Jakarta Sans font are bundled locally. The font's license is included in
`assets/fonts/OFL.txt`.

API origin and tenant subdomain configuration will be added with authentication.
The tenant is configuration, not a third login field. Credentials and tokens
will not be committed. Local reference images and temporary previews are ignored
by Git.

## Checks

```sh
flutter analyze
flutter test
```

The widget tests cover invalid form submission and password visibility with a
compact viewport and keyboard insets. iOS source is included; an iOS build needs
macOS and Xcode. The remaining API flow has not been implemented or tested.
