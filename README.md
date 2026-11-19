# Flutter login with typed API error handling

A small Flutter sample showing how I structure a login flow so that every way a
request can fail ends up as a clear message on screen, and never as a crash or a
spinner that runs forever.

It runs with no server. A stand-in backend is built into the app, and a dropdown
on each screen lets you choose how it answers the next request.

Demo account: `demo@example.com` / `password123`

## What it shows

- **One closed set of failures.** `ApiException` is a sealed class with seven
  cases (offline, timeout, unauthorized, validation, rate limited, server error,
  unreadable response). The UI turns them into text in a single `switch` with no
  default branch, so a new failure type will not compile until it has a message.
- **All failure handling in one layer.** `ApiClient` maps status codes, socket
  errors, timeouts and bad JSON. Nothing above it looks at a status code.
- **Safe retries.** A GET is retried up to twice on a dropped connection, a
  timeout, or a 502, 503 or 504. A POST is never retried, so a slow login cannot
  be submitted twice.
- **Server errors on the right field.** A 422 with `errors: {email: ...}` shows
  under the email field, next to the client-side validation.
- **Session handling.** The token is kept in the Keychain or Keystore through
  `flutter_secure_storage`, restored at launch, and cleared when the server
  rejects it. An expired session sends the user back to login with the reason.
- **No manual navigation.** The root widget picks the screen from the session
  state, so the UI cannot show a signed-in screen to a signed-out user.

## Run it

Requires Flutter 3.47 or later. The UI uses the standalone `material_ui` package
that replaced `package:flutter/material.dart`.

```bash
flutter create --platforms=android,ios --project-name flutter_auth_error_handling .
flutter pub get
flutter run
```

The first command generates the `android/` and `ios/` folders. If it also adds
`test/widget_test.dart`, delete that file.

Then try each option in "Simulate server response":

| Option | What you should see |
|---|---|
| Success | Profile screen |
| Wrong password | "Email or password is incorrect." |
| Validation error | Message under the email field |
| Offline | Offline message with a "Try again" button |
| Timeout | Timeout message after three seconds, with "Try again" |
| Server error | Server message with "Try again" |
| Rate limited | "Try again in 30 seconds." |
| Session expired | Sign in first, pick this, tap "Reload profile" |

## Tests

```bash
flutter analyze
flutter test
```

| File | Covers |
|---|---|
| `test/api_client_test.dart` | Status code and exception mapping, auth header, retry rules |
| `test/auth_controller_test.dart` | Sign in, restore at launch, expired session, sign out |
| `test/login_screen_test.dart` | Form validation, error banner, retry, field errors, session expiry |

The same checks run on every push through GitHub Actions
(`.github/workflows/ci.yml`).

## Layout

```
lib/
  main.dart                 wiring
  app.dart                  root widget, picks the screen from session state
  src/api/                  ApiClient and the ApiException types
  src/auth/                 token storage, repository, controller
  src/demo/                 the built-in stand-in backend
  src/ui/                   screens, error banner, error text
```

## Using a real backend

In `lib/main.dart`, pass `http.Client()` and your API's base URL to `ApiClient`.
The demo backend is an `http.Client` too, so no other code changes.

State management is `provider` with a `ChangeNotifier`, chosen to keep the sample
small. The API and auth layers do not depend on it.
