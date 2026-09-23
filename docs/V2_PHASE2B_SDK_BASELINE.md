# V2 Phase 2B — SDK / Dependency Baseline

**Branch:** `feature/v2.0.0-phase-2a`  
**Date:** 2026-09-16  
**Goal:** Resolve Dart/Flutter compatibility so Phase 2A can be analyzed, tested, and built. No product features.

---

## 1. Observed baseline (before Phase 2B fix)

| Item | Value |
|------|--------|
| PATH / global `flutter` | **3.24.5** (Dart **3.5.4**) |
| Repository FVM pin (`.fvmrc`) | **3.29.2** |
| FVM local SDK (`.fvm/flutter_sdk`) | `/Users/hxtreme/fvm/versions/3.29.2` → Dart **3.7.2** |
| `pubspec.yaml` `environment.sdk` (pre-fix) | `'>=3.0.0 <4.0.0'` |
| `pubspec.lock` `sdks.dart` | `>=3.7.0 <4.0.0` |
| `pubspec.lock` `sdks.flutter` | `>=3.29.0` |
| `google_mobile_ads` (pubspec) | `^6.0.0` |
| `google_mobile_ads` (lock) | **6.0.0** (requires Dart **>=3.6.0**) |

### Blocker (exact)

```
The current Dart SDK version is 3.5.4.
Because google_mobile_ads 6.0.0 requires SDK version >=3.6.0 <4.0.0
and no versions of google_mobile_ads match >6.0.0 <7.0.0,
google_mobile_ads ^6.0.0 is forbidden.
```

**Root cause:** developers were invoking global Flutter **3.24.5 / Dart 3.5.4** instead of the repo-pinned FVM Flutter **3.29.2 / Dart 3.7.2**.  
The lockfile and `google_mobile_ads 6.0.0` already assume Dart ≥ 3.7 / Flutter ≥ 3.29.

`google_mobile_ads` was the **direct** pub solver failure when using Dart 3.5.4. Other packages were not the solver failure at that SDK, but the lockfile already constrains the project to Flutter ≥ 3.29.

---

## 2. Toolchain inventory

### Android

| Setting | Value |
|---------|--------|
| Gradle wrapper | 8.10.2 |
| Android Gradle Plugin | 8.7.0 |
| Kotlin | 2.1.0 |
| `compileSdk` / `targetSdk` | 36 |
| `minSdk` | 23 |
| Java (app) | 11 (`sourceCompatibility` / `targetCompatibility`) |
| Host JDK (Flutter doctor) | OpenJDK 17 |
| `applicationId` / namespace | `com.app.newson` |

### iOS

| Setting | Value |
|---------|--------|
| Podfile platform | iOS **15.0** |
| Xcode (local) | **26.6** (Build 17F113) |
| CocoaPods | 1.16.2 |
| Frameworks linkage | `use_frameworks! :linkage => :static` |

### Firebase / ads / auth (locked, not upgraded in 2B)

| Package | Locked version |
|---------|----------------|
| firebase_core | 3.15.2 |
| firebase_messaging | 15.2.10 |
| firebase_remote_config | 5.5.0 |
| firebase_storage | 12.4.10 |
| firebase_database | 11.3.10 |
| cloud_firestore | 5.6.12 |
| google_mobile_ads | 6.0.0 |
| google_sign_in | 6.3.0 |
| sign_in_with_apple | 6.1.4 |
| url_launcher | (existing; used for V2 full article) |
| webview_flutter | transitive only — **not** introduced for V2 full article |

---

## 3. Options evaluated

### Option A — Use existing FVM Flutter pin (selected)

- Keep `.fvmrc` → Flutter **3.29.2** / Dart **3.7.2**
- Align `pubspec.yaml` `environment.sdk` to `>=3.7.0 <4.0.0` (matches lockfile)
- No package version bumps
- Preserve AdMob / Firebase / auth as locked

**Why safest:** repository already intended this SDK; lockfile already resolved against it; zero dependency churn.

### Option B — Downgrade `google_mobile_ads`

Rejected for Phase 2B: would change AdMob integration surface and risk Android/iOS native SDK regressions for a problem already solved by using the pinned Flutter.

### Option C — Pin an older exact `google_mobile_ads` under Dart 3.5.4

Rejected: fights the existing lockfile (`flutter: >=3.29.0`) and would still leave the project on an SDK older than what the rest of the lock expects.

---

## 4. Selected solution

| Field | Value |
|-------|--------|
| Strategy | **Option A** |
| Flutter | **3.29.2** (FVM) |
| Dart | **3.7.2** |
| Dependency changes | **None** (ranges unchanged except SDK constraint) |
| FVM | Already present; preserved; VS Code path corrected to `.fvm/flutter_sdk` |

### Developer setup

```bash
# Install FVM if needed, then:
fvm install 3.29.2
fvm use 3.29.2
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

Prefer `fvm flutter …` over global `flutter` for this repo.

---

## 5. Risks

| Risk | Mitigation |
|------|------------|
| Contributors still use global Flutter 3.24.x | Document FVM; IDE uses `.fvm/flutter_sdk` |
| Disk-full iOS CocoaPods clones | Environment issue; free space before `pod install` |
| Pre-existing flaky plugin tests (audio / speech) | Not caused by SDK pin; exclude from Phase 2B gate or fix later |
| Future major bumps of `google_mobile_ads` / Firebase | Out of scope for 2B; do deliberately later |

---

## 6. Recommended minimum compatible SDK

**Flutter 3.29.2 / Dart 3.7.2** (already pinned).

Do not use Flutter ≤ 3.24.x (Dart 3.5.x) with the current lock + `google_mobile_ads 6.0.0`.
