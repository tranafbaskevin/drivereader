<div align="center">

# KevDex
### Read Anywhere

A personal manga and image reader built with Flutter.

[![Release](https://img.shields.io/github/v/release/tranafbaskevin/KevDex?label=latest&color=6C63FF)](https://github.com/tranafbaskevin/KevDex/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-personal--use-lightgrey)](#disclaimer)

</div>

---

## Features

| Source | Status | Description |
|--------|--------|-------------|
| **MangaDex** | Stable | Browse, search, view manga details, choose chapters, and read pages |
| **Google Drive** | Stable | Read self-owned image folders from Google Drive links |
| **Hentai2Read** | Experimental | Browse and read supported galleries |
| **Hitomi / NHentai** | Limited | Kept behind the private source gate; may fail because of CDN, mirror, or site protection changes |

**App highlights:**

- Source Hub with separate source inputs
- MangaDex Home with title search and chapter selection
- Continue Reading card
- Library page for saved stories
- Thumbnail blur toggle for sensitive/private sources
- Custom background picker
- Dark manga-reader UI
- Reader page navigation, gallery mode, and page progress

---

## Screenshots

<div align="center">
  <img src="docs/screenshots/kevdex-source-hub.png" alt="KevDex Source Hub" width="49%">
  <img src="docs/screenshots/kevdex-mangadex-home.png" alt="MangaDex Home search" width="49%">
  <br>
  <img src="docs/screenshots/kevdex-manga-details.png" alt="Manga details and chapter list" width="49%">
  <img src="docs/screenshots/kevdex-reader.png" alt="KevDex reader page" width="49%">
</div>

---

## Download

> **[Download latest APK -> Releases](https://github.com/tranafbaskevin/KevDex/releases/latest)**

Install the `.apk` directly on your Android device.

You may need to enable **Install from unknown sources** in Android Settings.

---

## Build From Source

**Requirements:** Flutter 3.x, Android SDK, Java 17+

```bash
git clone https://github.com/tranafbaskevin/KevDex.git
cd KevDex

flutter pub get
flutter run
flutter build apk --release
```

The output APK will be at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Changelog

### v2.5.2 - Branding & Version Cleanup

- Sync package name, app description, and version metadata with KevDex v2.5.2.
- Update README links and build instructions for the KevDex repository.
- Keep Android update compatibility by preserving the existing application id.
- Confirm Android label/icon and iOS display name use KevDex branding.

### v2.5.1 - MangaDex Search & KevDex Branding

- Add MangaDex Home title search.
- Support partial search queries such as `jujut`.
- Update Android app label and launcher icon to KevDex.

### v2.5.0 - Hentai2Read Source

- Add Hentai2Read as an experimental source.
- Add Hentai2Read Home and reader flow.
- Stabilize release checks before APK publishing.

### v2.4.0 - Hitomi Routing Fix

- Fix Hitomi image loading after CDN routing changes.
- Update fallback routing metadata.

### v2.3.1

- Add thumbnail blur toggle for sensitive content.

### v2.3.0

- Add Hitomi Home with infinite scroll and gallery loading.

### v2.2.9

- Clarify NHentai mirror limits in the UI.

### v2.2.8

- Fix Hitomi image routing after a CDN host change.

### v2.2.5

- Stage private source inputs.

### v2.2.3

- Add private source gate.

### v2.2.2

- Add clear cache action.

### v2.2.1

- Add full library page.

### v2.2.0

- Add source hub foundation.

---

## Disclaimer

> **This application is a personal project intended for personal use only.**
>
> - KevDex does **not** host, store, or distribute copyrighted content.
> - KevDex is a reader/client that connects to existing public or self-owned sources.
> - Users are responsible for ensuring their use complies with local laws and the Terms of Service of any third-party website they access through this app.
> - The developer does **not** condone piracy or illegal use of this software.
> - This app is **not affiliated** with MangaDex, Google Drive, Hentai2Read, Hitomi, or NHentai.

---

<div align="center">
Made by <a href="https://github.com/tranafbaskevin">Kevin</a> with Flutter.
</div>