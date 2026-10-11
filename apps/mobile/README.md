# PrepLoop mobile (Flutter)

See the [root README](../../README.md) for setup and run commands, and [CLAUDE.md](../../CLAUDE.md) for conventions.

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter analyze
flutter test
```

Localisation sources are in `lib/core/localization/arb/`. Run `flutter gen-l10n` after editing them.
