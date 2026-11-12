# Releasing Keeper of the Cove (signed Android builds via CI)

Release APK/AAB are built **only** by GitHub Actions — never locally. The signing
keystore lives exclusively in GitHub Secrets; it is decoded at build time, used to
sign in release mode, and deleted before the job ends. No secret is ever printed.

## One-time setup

### 1. The signing keystore (already exists)

The upload keystore for this app **already exists** at `android/app/keeper-release.jks`
with its base64 copy `android/app/keeper-release.keystore.base64.txt` (both
git-ignored). **Do not generate a new one**: an app on Google Play can only be
updated with the key it was first uploaded with.

- Back both files up somewhere safe **outside** this project (e.g. an encrypted drive
  or password manager).
- `scripts/generate_keystore.ps1` is only for a brand-new app; it prompts for every
  value and gathers nothing from the machine.
- Check the certificate's owner fields contain no personal name:
  `keytool -list -v -keystore android/app/keeper-release.jks`

### 2. Add the four GitHub repository secrets

In the repo: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret name | Value |
|-------------|-------|
| `COASTLIGHT_KEYSTORE_BASE64` | entire contents of `keeper-release.keystore.base64.txt` |
| `COASTLIGHT_KEYSTORE_PASSWORD` | keystore password you entered |
| `COASTLIGHT_KEY_PASSWORD` | key password you entered |
| `COASTLIGHT_KEY_ALIAS` | the key alias you chose |

## Triggering a build

The workflow [`.github/workflows/android-release.yml`](../.github/workflows/android-release.yml)
runs on every push, or on demand from the **Actions** tab → *Android Release Build*
→ **Run workflow**.

It produces two downloadable artifacts:

- `keeper-of-the-cove-release-apk` → `app-release.apk` (sideload / testing)
- `keeper-of-the-cove-release-aab` → `app-release.aab` (Google Play upload)

Both are signed in **release** mode with your keystore. If the signing secrets are
missing, the workflow fails fast with a clear message rather than producing an
unsigned or debug-signed build.

## How signing is wired

`android/app/build.gradle.kts` reads `android/key.properties` (git-ignored). CI
writes that file from the secrets at build time and points `storeFile` at the
decoded `keeper-release.jks`. When `key.properties` is absent (e.g. a local debug
run) the build falls back to debug signing so `flutter run` still works.

The release build also enables R8 (`isMinifyEnabled` / `isShrinkResources`).
`android/app/proguard-rules.pro` adds `-dontwarn` rules for the unused Google Play
Core (deferred components) classes so R8 does not fail — safe because this app does
not use dynamic feature delivery.

## Privacy note

`generate_keystore.ps1` collects no system information and no personal data. Every
field is typed by you; nothing is gathered from the machine or the network.
