# KevDex v2.7.0 - Stability Checkpoint

## Goal

KevDex v2.7.0 is a stability checkpoint after the v2.6.x cleanup/refactor phase.

This version focuses on:

- Regression testing.
- Bug triage.
- APK verification.
- Reader stability.
- Library and Continue Reading correctness.
- Cache and clear-cache behavior.

No major new features should be added during this phase.

---

## Current Automated Result

Date: 2026-07-02

Automated checks run by Remi:

```txt
PASS    flutter analyze lib test
PASS    flutter test
PASS    flutter build apk --debug
PASS    flutter build apk --release
WARN    flutter analyze timed out in this environment
BLOCKED flutter run / device install: no ADB device online
```

Notes:

- `flutter test` passed 31/31 tests.
- `flutter analyze lib test` reported no issues.
- `flutter analyze` for the full project timed out after multiple attempts, so it should be retried manually before release.
- ADB reported no attached device.
- Android emulator listed no available AVDs from this terminal.
- BlueStacks was not visible through ADB from this terminal.
- `devtools_options.yaml` is a local untracked IDE file and should not be committed.

Generated APKs:

```txt
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

Suggested release APK name:

```txt
KevDex-v2.7.0-stability-checkpoint.apk
```

---

## Test Devices

- [ ] Pixel 8 API 35 Android emulator
- [ ] BlueStacks emulator
- [ ] Release APK install test

Current device status:

- Pixel 8 emulator: pending manual test.
- BlueStacks: pending manual test.
- Release APK install: pending manual test.

---

## Priority Rules

- P0: crash, build fail, app cannot open, Home unusable, Reader unusable.
- P1: wrong data, wrong page, wrong source, Library/Continue Reading/cache bugs.
- P2: UI polish, minor visual issues, non-blocking source issues.

---

## Known Issues To Track

### Confirmed / High Priority

1. BlueStacks compatibility issue

- Android Studio emulator may show Home correctly while BlueStacks may render Home/source screens differently.
- Needs device-specific verification.

2. Post-refactor regression risk after v2.6.9

- v2.6.x moved models, services, helpers, and widgets out of `main.dart`.
- Main routes must be re-tested after the cleanup phase.

3. Cache behavior needs verification

- Thumbnail cache, full image cache, preload, and clear-cache behavior need manual verification.
- Clear Cache must not delete Library or Continue Reading unless explicitly intended.

4. Continue Reading accuracy

- Must verify `sourceLink`, `chapterId`, and `pageIndex`.
- Risk: reopening the wrong story/chapter/page or resetting to page 1.

5. Reader navigation stability

- Must verify swipe, arrow overlay, back button, and page number.
- Risk: wrong back route, route loop, or wrong page index.

### Medium Priority

6. Google Drive folder edge cases

- Private folders, empty folders, wrong links, heavy images, and mixed filename ordering need manual tests.

7. MangaDex API edge cases

- Missing cover, missing description, missing chapters, missing pages, slow API, or API errors should not crash the app.

8. UI theme/background readability

- Custom backgrounds can make text/buttons harder to read.
- Thumbnail blur may affect weaker devices.

9. Release APK verification

- Debug success does not guarantee release success.
- Release APK should be installed and opened separately.

### Low Priority

10. UI polish

- Spacing, icons, text, button color, and animation polish can wait until core flows are stable.

11. Private/secondary source stability

- Secondary/private sources should not block the v2.7.0 release unless they crash the whole app.
- They can be hidden/disabled later if needed.

---

## A. Build / Run Basics

- [x] `flutter analyze lib test` has no serious red errors.
- [x] `flutter test` passes.
- [ ] `flutter analyze` full project completes without timeout.
- [ ] `flutter run` runs on Pixel 8 emulator.
- [ ] App opens without crashing.
- [ ] No red screen on app start.
- [ ] Hot restart does not create strange state.
- [x] Debug APK builds.
- [x] Release APK builds.
- [ ] Release APK installs on emulator/device.

---

## B. Home / Source Hub

- [ ] Home opens correctly.
- [ ] Source Hub shows all intended sources.
- [ ] Google Drive source opens.
- [ ] MangaDex source opens.
- [ ] Hentai2Read source route does not crash.
- [ ] Library opens.
- [ ] Continue Reading opens.
- [ ] Settings opens.
- [ ] Back button returns to Home correctly.
- [ ] No blank white/black screen.
- [ ] No obvious UI overflow.
- [ ] BlueStacks displays Home correctly.
- [ ] Pixel 8 emulator displays Home correctly.

---

## C. Google Drive Reader

- [ ] Paste valid Google Drive folder link.
- [ ] Folder loads real images.
- [ ] No old demo images appear.
- [ ] Images are sorted as page 1, 2, 3...
- [ ] Tap first image opens the correct reader page.
- [ ] Tap middle image opens the correct reader page.
- [ ] Tap last image opens the correct reader page.
- [ ] Reader does not show red screen.
- [ ] Swipe left/right changes page correctly.
- [ ] Left/right arrow buttons work.
- [ ] Page number is correct.
- [ ] Back from reader returns to gallery.
- [ ] Back from gallery returns to source/home.
- [ ] Wrong link shows readable error.
- [ ] Empty folder shows empty state.
- [ ] Private/no-permission folder shows readable error.
- [ ] Slow network does not create infinite loading.

Recommended cases:

- [ ] Folder with 5 images.
- [ ] Folder with 50+ images.
- [ ] Folder with mixed filename order.
- [ ] Folder with heavy images.
- [ ] Wrong folder ID.
- [ ] Link that is not a folder.
- [ ] Network loss during load.

---

## D. MangaDex

- [ ] MangaDex Home opens.
- [ ] MangaDex Search works.
- [ ] Common keyword returns results.
- [ ] Nonsense keyword shows empty state.
- [ ] Tapping manga opens details.
- [ ] Description displays.
- [ ] Cover/thumbnail loads.
- [ ] Chapter list loads.
- [ ] Choosing chapter opens reader.
- [ ] Chapter pages load in correct order.
- [ ] Swipe left/right changes page correctly.
- [ ] Page number is correct.
- [ ] Back from reader returns to details/chapter list.
- [ ] Missing description does not crash app.
- [ ] Chapter with no readable pages does not crash app.
- [ ] Slow/API error does not crash app.

Extra cases:

- [ ] Manga with many chapters.
- [ ] Manga with few chapters.
- [ ] Manga without cover.
- [ ] Manga with long description.
- [ ] Manga title with Japanese/English/special characters.

---

## E. Secondary / Private Sources

- [ ] Source route does not crash app.
- [ ] Source route does not create blank Home.
- [ ] Source can be hidden/disabled if unstable.
- [ ] Secondary source issue does not block Google Drive/MangaDex.

---

## F. Library

- [ ] Opened Drive story is saved to Library.
- [ ] Opened MangaDex story is saved to Library.
- [ ] Library shows correct title/cover/source.
- [ ] Tapping Library item reopens the correct story.
- [ ] No infinite duplicates for the same story.
- [ ] Removing item from Library works.
- [ ] Library persists after app restart.
- [ ] Clear Cache does not delete Library by accident.
- [ ] Empty Library displays nicely.

---

## G. Continue Reading

- [ ] Exit on page 1 and reopen page 1.
- [ ] Exit on middle page and reopen that page.
- [ ] Exit on last page and reopen that page.
- [ ] Continue Reading distinguishes Drive and MangaDex.
- [ ] Does not open the wrong chapter.
- [ ] Does not open the wrong manga.
- [ ] Does not open the wrong Drive folder.
- [ ] Missing/deleted story gives readable error.

---

## H. Cache / Clear Cache

- [ ] Image loads the first time.
- [ ] Same image loads faster after cache.
- [ ] Thumbnail cache works.
- [ ] Full image cache works.
- [ ] Previous/next page preload works.
- [ ] Clear Cache removes cache.
- [ ] After Clear Cache, images reload from source.
- [ ] Clear Cache does not crash.
- [ ] Clear Cache does not delete Library/Continue Reading by accident.
- [ ] Cache does not grow without limit.
- [ ] Corrupt cache does not crash app.

Practical flow:

1. Open Drive folder.
2. Open page 1.
3. Swipe to page 2.
4. Exit.
5. Reopen page 1.
6. Check whether it loads faster.
7. Clear cache.
8. Reopen page 1.
9. Check whether it loads again.

---

## I. UI Settings

- [ ] Dark UI is stable.
- [ ] Pick background from image library works.
- [ ] Background persists after app restart.
- [ ] Thumbnail blur toggles correctly.
- [ ] Thumbnail blur does not lag badly.
- [ ] Clear/reset background works if available.
- [ ] Text stays readable on bright/dark backgrounds.
- [ ] Buttons stay visible.
- [ ] Reader is not covered by background/theme.

---

## J. Navigation

- [ ] Home -> Drive -> Gallery -> Reader -> Back -> Gallery.
- [ ] Gallery -> Back -> Drive/Home.
- [ ] Home -> MangaDex -> Details -> Chapter -> Reader -> Back.
- [ ] Home -> Library -> Reader -> Back.
- [ ] Home -> Continue Reading -> Reader -> Back.
- [ ] Repeated back presses do not crash.
- [ ] No route loop.
- [ ] No wrong back destination.
- [ ] App state is not lost unexpectedly.

---

## K. Network / API Errors

- [ ] No network on app open.
- [ ] Network loss while loading Drive.
- [ ] Network loss while loading MangaDex.
- [ ] Slow API shows loading state.
- [ ] API error shows error state.
- [ ] Retry works if available.
- [ ] Loading does not spin forever.

---

## L. Release APK

- [ ] `pubspec.yaml` version is correct for release.
- [x] Release APK builds successfully.
- [ ] Release APK installs on emulator.
- [ ] Release APK installs on BlueStacks.
- [ ] Release APK opens without crash.
- [ ] Drive basic flow works on release APK.
- [ ] MangaDex basic flow works on release APK.
- [ ] Library/Continue Reading works on release APK.
- [ ] APK file is renamed clearly for GitHub Release.

Release label:

```txt
KevDex v2.7.0 - Stability Checkpoint
```

---

## Recommended Bug Fix Order

1. Build/analyze/app crash.
2. Home display, especially BlueStacks.
3. Navigation/back/route loop.
4. Reader page/swipe/arrow/page number.
5. Continue Reading wrong page/story/chapter.
6. Library save/delete/duplicate/persist.
7. Cache/Clear Cache/Preload.
8. MangaDex edge cases.
9. UI polish.

---

## Release Decision

Do not tag v2.7.0 until:

- [ ] Pixel 8 emulator smoke test passes.
- [ ] BlueStacks smoke test passes or its issue is documented clearly.
- [ ] Release APK install test passes.
- [ ] P0 bugs are fixed or explicitly documented.

If only P2 polish issues remain, v2.7.0 can be released as a stability checkpoint.