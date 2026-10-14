# Release checklist (Phase 11)

What is ready, and what still needs a person, a device or a decision. Items marked **(you)** can't be
done from the development machine or need the operator's accounts, legal input or artwork.

## 1. Repository and CI

- [x] CI on every push and pull request (`.github/workflows/ci.yml`) covers:
  - backend lint, types, migrations and tests on PostgreSQL
  - OpenAPI drift
  - mobile format, analyze and tests
  - the Android build
  - the image build and compose validation
- [ ] **(you)** GitHub → Settings → Branches: protect `main`; require the CI jobs `backend`, `mobile`, `android`
  and `container`; require pull requests.
- [ ] **(you)** Pin third-party actions to commit SHAs (optional hardening; currently major tags). Enable Dependabot for
  pip, pub, GitHub Actions and Docker.
- [ ] Run the manual **Device tests** workflow (Android emulator: integration tests, including real secure storage and
  on-disk DB migration).

## 2. Backend deployment

Follow [deployment.md](deployment.md). The production settings refuse to start without:
- `PREPLOOP_AUTH_SECRET` (32+ characters)
- Postgres rate limits
- SMTP with TLS
- explicit CORS

- [ ] **(you)** Choose the hosting, a managed Postgres with backups and PITR, a shared volume for PDFs, an SMTP provider and a
  domain with TLS.
- [ ] **(you)** Put the secrets in the platform's secret store.
- [ ] Release steps: run migrations as a one-off task, then roll out the API and worker, then smoke-test.
- [ ] **(you)** Register the real first account **before** anyone else. The first account claims any pre-account data
  imported during development.
- [ ] Optional: `PREPLOOP_METRICS_TOKEN` and a Prometheus scrape; alerts on 5xx rate and readiness.

## 3. Android release

1. **(you)** Pick the permanent application id (e.g. `in.yourdomain.preploop`). Set `applicationId` and
   `namespace` in `apps/mobile/android/app/build.gradle.kts`, and move `MainActivity.kt` to the matching package.
   **It can't be changed after the first Play upload.**
2. **(you)** Create the upload keystore **outside the repository** and back it up:
   ```powershell
   keytool -genkey -v -keystore $env:USERPROFILE\.preploop\preploop-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias preploop
   ```
   Copy `android/key.properties.example` to `android/key.properties` (gitignored) and fill it in. Enroll in **Play App
   Signing**, so Google holds the app signing key and a lost upload key can be reset.
3. Versioning: `version: <semver>+<build>` in `pubspec.yaml`. Raise the semver for user-visible releases and the build
   number on **every** upload (CI can pass `--build-number`).
4. Build:
   ```powershell
   cd apps\mobile
   flutter build appbundle --release --dart-define=FLAVOR=production --dart-define=API_BASE_URL=https://api.yourdomain --dart-define=APP_NAME=PrepLoop
   ```
   Non-development builds refuse a non-HTTPS `API_BASE_URL`.
5. **(you)** Replace the provisional icon: put the artwork through `scripts/generate_app_icons.py --master art.png`.
6. **Verify on a real device** (none is available on the development machine):
   - [ ] Sign up, confirm the email (code arrives), reset the password, sign out, and sign in on a second device; data syncs.
   - [ ] Secure storage survives an app restart; reinstalling signs you out.
   - [ ] PDF picker opens the system picker; the upload completes; the worker processes the paper.
   - [ ] Daily reminder: the permission prompt appears only when turned on, the notification arrives at the set time, it survives a
         reboot (boot receiver), denying the permission shows the explanation, and nothing is duplicated after restarts.
   - [ ] Hindi renders everywhere (bundled Noto Sans Devanagari) with the device in Hindi.
   - [ ] Offline: practice answers queue; concepts and flashcards keep working; everything syncs when back online.
   - [ ] **Try R8**: set `isMinifyEnabled = true` and `isShrinkResources = true`, add keep rules if
     flutter_local_notifications needs them (scheduled notifications use Gson), then repeat the reminder checks.
7. **(you)** Play Console:
   - store listing (EN and HI)
   - content rating
   - target audience (adults preparing for SSC exams)
   - data safety, using [legal/play-data-safety.md](legal/play-data-safety.md)
   - privacy policy URL
   - internal testing track first

## 4. iOS (needs macOS + Xcode)

- **(you)** A Mac with Xcode, an Apple Developer account, a bundle id and a signing team in Xcode.
- `flutter build ipa --release --dart-define=...` (same defines as Android).
- Local notifications need no extra entitlements. The permission is requested in context. Secure storage uses the Keychain.
- App Store Connect privacy labels: use the same data inventory as the Play data safety form.
- Check the generated `AppIcon` set (opaque 1024 px included) and run on a device.

## 5. Legal and privacy

- [ ] **(you)** Have counsel review `apps/mobile/assets/legal/privacy-policy.md` and `terms.md`. Fill in every
  `[placeholder]`:
  - operator and contact
  - processors and region
  - backup retention days
  - governing law
  - minimum age and parental consent
- [ ] **(you)** Publish both documents at public URLs (needed for the store listings). The in-app copies must stay identical.
- [ ] **(you)** Review the AI provider's data-retention terms before enabling `PREPLOOP_AI_API_KEY` in production. Mention
  the provider in the privacy policy (already drafted).

## 6. Accessibility and performance

- [x] Automated: tap targets, labels and contrast (light and dark) on every tab and on sign-in; 2× text without overflow
  (`test/a11y/accessibility_test.dart`). Found and fixed: Material `SearchBar` exposed a 24 px tap target.
- [ ] **(you, device)** Manual pass:
  - TalkBack / VoiceOver through sign-in, onboarding, practice, revision and Profile
  - largest system font
  - dark mode
  - Hindi
- [ ] **(you, device)** Performance:
  - `flutter run --profile --trace-startup` on a mid-range Android phone: first frame under 2 s
  - DevTools for jank in long lists (question bank, progress)
  - the release bundle size

## 7. Known limits at release

See "Current phase" in [CLAUDE.md](../CLAUDE.md). The main ones:
- **Sync:** last-writer-wins per record.
- **Accounts:** no device list or remote sign-out.
- **Storage and scaling:** PDFs on a shared volume (no S3 adapter yet); metrics are per process.
- **Exam formats:** only one verified format (SSC CHSL 2026 Tier-I); SSC CGL needs the current official notice.
- **Not yet reviewed:** Hindi text needs native-speaker review; AI output quality is unmeasured until a key is configured.
