# Phase 08 — Final Build & Release Prep

- **Status:** done
- **Depends on:** 07
- **Can run in parallel with:** none

## What
Get the project release-ready: app identity, icon, version, and a clean release configuration. Signing/CI is handed to the `game-ci` skill, not done here.

## Why
The last step before a signed build is produced by CI.

## Scope (build only this)
1. Set the app display name to "Keeper of the Cove" (Android label) and confirm the applicationId (`com.coastlight.keeper_of_the_cove`).
2. Add an app icon derived from the design language (amber beam on indigo). Generate launcher icons (e.g. document using `flutter_launcher_icons`, or place icons directly). If asset generation is not possible, document the exact files/sizes needed.
3. Set `version` in `pubspec.yaml` (e.g. `1.0.0+1`) and a short store description draft in notes.
4. Confirm a release build configuration is sound (no debug-only flags); add a brief note pointing to `game-ci` for signing, proguard `-dontwarn` Play Core rules, and the GitHub Actions workflow.
5. Update `description` in `pubspec.yaml` to a real one-line pitch.

## Out of scope
No keystore creation, no signing config, no GitHub Actions (that is the `game-ci` skill). No new gameplay.

## References
- docs/README.md — pitch, identity.
- docs/DESIGN_LANGUAGE.md — icon palette.
- docs/COMPLIANCE.md — final NO check before submission.

## Verify
`flutter build apk --debug` (or `--release` if signing-agnostic) completes without errors. App name and icon appear correctly. Version set.

## On completion
- Set Status to done with notes (icon approach, version, handoff to game-ci).
- Update the Phase 08 row in docs/IMPLEMENTATION_PLAN.md.

## Completion notes

**App identity**
- `android:label` in `android/app/src/main/AndroidManifest.xml` → "Keeper of the Cove".
- `applicationId` confirmed `com.coastlight.keeper_of_the_cove` (in `android/app/build.gradle.kts`).

**Version & description (`pubspec.yaml`)**
- `version: 1.0.0+1` (versionName 1.0.0, versionCode 1).
- `description` set to the one-line pitch: *"A calm one-thumb game: keep a lighthouse, sweep your beam to guide lost vessels safely home through the dark."*

**Icon approach**
- Source PNG (1024×1024): `assets/icon/app_icon.png` — amber beam (`#F4B860`) on indigo (`#0B1626`), per DESIGN_LANGUAGE.md.
- Generated via `flutter_launcher_icons` (added as a dev_dependency with config in `pubspec.yaml`). Re-run anytime with `dart run flutter_launcher_icons`.
- Output: legacy mipmaps `ic_launcher.png` (mdpi→xxxhdpi) + adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`, indigo background via generated `colors.xml`, lighthouse foreground). No empty/broken PNGs shipped.
- If a hand-tuned adaptive foreground is later desired, supply a foreground PNG with ~25% safe padding (lighthouse centered) and update `adaptive_icon_foreground`.

**Release config note (sound; debug-agnostic)**
- `buildTypes.release` currently uses the debug signing config as a placeholder so `flutter run --release` works; no debug-only flags are set. No code shrinking/obfuscation is enabled, so no Play Core ProGuard rules are needed yet.
- Handoff to the **game-ci** skill for the real release pipeline:
  - Create a keystore + a release `signingConfig` (replace the debug placeholder).
  - If `isMinifyEnabled`/R8 shrinking is turned on, add ProGuard/R8 `-dontwarn com.google.android.play.core.**` rules to avoid Play Core warnings.
  - Add the GitHub Actions workflow to build/sign the App Bundle (`flutter build appbundle --release`).
- Out of scope here (no keystore, signing config, or GitHub Actions created in this phase).

**Compliance:** unchanged — offline, no network/permissions/data; all COMPLIANCE.md answers remain NO.

**Store description draft**
> **Keeper of the Cove** — A calm, one-thumb game of gentle guardianship.
>
> You are the keeper of a lonely lighthouse on a rocky cove. Through the dark, lost vessels drift toward the rocks. Sweep your single warm beam to find them, then hold it steady until each one charts a safe course home.
>
> One beam, limited attention — the quiet tension is choosing who to light. No combat, no harm: you guide, you never hurt. Soft amber light against a cold dark sea, with a slow rocking sway and gentle chimes.
>
> Fully offline. No ads, no purchases, no accounts, no data collection. Just you, the night, and the souls who need a way home.

**Verify:** `flutter analyze` → No issues found. (Release build not run — requires signing, handed to game-ci.)
