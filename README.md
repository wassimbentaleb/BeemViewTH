# Beem View 360

A standalone Flutter mobile app for browsing projects and tasks with the
BeemView API.

## Features

- Login with email/password validation on leaving a field or submitting,
  loading and readable API errors.
- Secure token storage, session restoration and local sign-out.
- Projects with pagination and a Load more action.
- Project tasks with name search and all eight status filters applied locally.
- Task details with description, project, assignees, start/due dates and latest returned comment.
- Status update with an optional note posted as a separate comment.
- Light and dark themes with a sun/moon button on every screen. The app follows
  the device theme until a preference is chosen, then remembers it across restarts
  and sign-out.

Loading, empty results and failed reads have dedicated states. A protected 401
returns to Login; 403 preserves the session. A delayed 401 for an old token does
not clear a newer session.

Save sends status first, then a nonempty trimmed note. Controls and Back are
locked during saving. Save stays above the keyboard while entering a note.
If only the comment fails, the note is kept and Retry
sends only that comment. An uncertain write response offers a fresh detail read
instead of resubmitting. After an update, Details and Tasks are refreshed while
keeping the task-list search and filter.

## Setup and run

Built and checked with **Flutter 3.47.2 / Dart 3.13.2**.

```sh
flutter pub get
```

Copy `config/app.example.json` to `config/app.local.json`. Keep `API_ORIGIN` as
`https://beemview.com` unless another origin is supplied, and fill
`TENANT_SUBDOMAIN` with the assigned tenant. The origin must be an absolute HTTP
or HTTPS URL, without `/api`; the tenant must be nonempty. Credentials are entered
in the login form and are never included in this configuration file.

```sh
flutter run --dart-define-from-file=config/app.local.json
```

Choose a connected Android device or emulator. Local configuration files, tokens
and credentials are excluded from Git. The app stores the token and theme
preference under separate keys using `flutter_secure_storage` 11.2.0;
`http` 1.6.0 handles JSON requests and a 20-second
timeout. The logo and Plus Jakarta Sans font are bundled; the font license is
in `assets/fonts/OFL.txt`.

## Architecture

```text
lib/
  main.dart       App entry point.
  app.dart        Shared services, session and initial screen.
  core/           Configuration, theme, validation, dates and API errors.
  models/         Typed response data.
  services/       HTTP requests and secure session storage.
  controllers/    Loading, errors, filters and save state.
  screens/        The five screens and session restoration.
  widgets/        Shared logo, cards and badges.
```

The data flow is **screen -> controller -> service -> API**. Services map JSON
into typed models. Screens own their controllers, while the app owns the shared
HTTP client and authentication controller.

State management uses Flutter's `ChangeNotifier` and `ListenableBuilder`. The
state is small and each screen can be understood independently, so no additional
state-management package is needed. Local password visibility uses `setState`.
New code blocks have short French comments explaining their purpose.

`ThemeController` shares the appearance choice above the Navigator. Theme changes
preserve the active route, search filters, login input and draft notes. The saved
theme is read before the first frame; an unavailable preference falls back to the
device theme. A failed preference write keeps the selected theme for the current
session and shows a message.

`Task` normalizes list/detail date names and priority casing. `TaskDetails`
composes this model with optional associations. `UpdateStatusController` keeps
confirmed status saves separate from comment success, which makes comment-only
retry possible without sending status again.

## API routes

Protected requests use `Authorization: Bearer <token>`; JSON bodies use
`Content-Type: application/json`. IDs come from API responses.

| Method | Route | Purpose |
| --- | --- | --- |
| POST | `/api/auth/login` | Email, password and configured subdomain. |
| GET | `/api/users/me/profile` | Validate the restored session. |
| GET | `/api/projects?limit=10&offset=0` | Paginated visible projects. |
| GET | `/api/tasks/project/:projectId` | Complete task collection for a project. |
| GET | `/api/tasks/:id` | Current task details. |
| PUT | `/api/tasks/:id` | Send only the selected `status`. |
| POST | `/api/tasks/comment` | Send `task_id`, trimmed `content`, `mentioned_user_ids: []`. |

## Assumptions and limitations

- Test access and tenant configuration are supplied separately. Use the assigned
  project and tasks for write requests.
- Project-task search and status filters run over the loaded collection. That
  endpoint has no pagination; server-side task filtering is not used.
- Missing optional fields remain empty. Unknown status labels stay readable;
  saving requires one of the eight documented API values.
- Details returns up to ten recent comments. The newest usable timestamp chooses
  the displayed comment; if none are usable, the first returned comment is used.
- Status and comment are separate writes. A timeout, connection loss, 5xx or
  unusable acknowledgement may follow an applied write. The user checks Details
  before deciding whether to send another note; the app performs no automatic retries.
- Only the token and theme preference persist. Projects, tasks and draft notes have no offline storage.
  Sign-out clears the local session; the contract has no server logout or refresh-token route.
- Android was tested on an API 36 emulator. iOS configuration is included, but an
  iOS build was not tested because it requires macOS/Xcode. Web is a preview target
  and was not validated; API access depends on server CORS and secure storage
  requires HTTPS or localhost.
- The APK is a debug build. Production signing is not configured.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/app.local.json
```

All **103 tests** pass; formatting and analysis report no issues. Tests cover
response mapping, pagination, filters, session storage/expiry, delayed old-token
401s, duplicate reads/saves, late responses, partial saves, uncertain comments,
refresh and preserved filters, and narrow layouts with enlarged text and a keyboard.
Theme tests cover device brightness, saved preferences, sign-out, preserved form
and navigation state, and unavailable preference storage.
HTTP/storage are simulated in automated tests.

The real API was checked on Android for login, session restoration, projects,
tasks, details and status saving. The assigned task was changed from To do to
In progress, its detail/list data refreshed, then its original status restored.
Comments, partial failures and pagination beyond the test account's projects
were checked with simulated responses.

Final Android checks also covered offline session restoration followed by Retry,
sign-out persisting after a restart, real login and restoration after another
restart, combined task search/status filtering, return navigation and note entry
with Save visible above the keyboard. Wi-Fi and mobile-data settings were restored
after the offline check.

The installable debug APK is generated at
`build/app/outputs/flutter-apk/app-debug.apk` and is excluded from Git.
