# Chat Media Cleaner

[![CI](https://github.com/ChandraChaan/chat-media-cleaner/actions/workflows/ci.yml/badge.svg)](https://github.com/ChandraChaan/chat-media-cleaner/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/ChandraChaan/chat-media-cleaner?color=3949AB)](https://github.com/ChandraChaan/chat-media-cleaner/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ChandraChaan/chat-media-cleaner/total?color=3949AB)](https://github.com/ChandraChaan/chat-media-cleaner/releases)
![Android 8+](https://img.shields.io/badge/Android-8.0%2B-3DDC84)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**See which WhatsApp photos, videos and voice notes are filling your phone, look through them, and clear them safely.**

Chat Media Cleaner scans the WhatsApp (and WhatsApp Business) media folder, shows what takes the most space, and groups the files you probably don't need: huge videos, the same meme saved five times, old forwards, copies of things you sent. You pick what goes. Deleted files wait in a trash for 7 days so you can change your mind.

It is also a file manager for those folders: browse them, and open photos, videos, voice notes, PDFs and text files right in the app, with a full video player. No internet permission, no account, no ads.

<p align="center">
  <img src="docs/screenshots/01_home.png" alt="Home screen: chat media split by type, with Largest files, Exact duplicates, Old forwards and memes, and Sent media copies groups" width="200">
  <img src="docs/screenshots/02_review.png" alt="Review grid of old forwards with thumbnails, sizes and five files selected" width="200">
  <img src="docs/screenshots/03_confirm.png" alt="Confirmation before moving 100 files (1.4 GB) to the trash" width="200">
  <img src="docs/screenshots/04_trash.png" alt="Trash with days left before each file is deleted for good, and Restore" width="200">
  <img src="docs/screenshots/06_files.png" alt="Files tab inside WhatsApp Images: a Sent folder with its size, then photos with thumbnails, sizes and dates" width="200">
  <img src="docs/screenshots/07_player.png" alt="Video player with previous, pause and next buttons, a scrub bar, and a brightness level shown while swiping" width="200">
</p>

## Download

**[Download the latest APK →](https://github.com/ChandraChaan/chat-media-cleaner/releases/latest)**

| File | For |
|---|---|
| `ChatMediaCleaner-<version>-arm64-v8a.apk` | Almost every phone from the last 6–7 years (pick this if unsure) |
| `ChatMediaCleaner-<version>-armeabi-v7a.apk` | Older 32-bit phones |
| `ChatMediaCleaner-<version>-universal.apk` | Any phone (bigger download) |

Open the file on your phone and allow installing from your browser or file manager when Android asks. Each release lists SHA-256 checksums, and every APK is signed with the same release key, so future versions install as updates.

## How to use it

1. Open the app and tap **Choose WhatsApp folder**. Android's file picker opens at the right place; tap **Use this folder**, then **Allow**.
2. Tap **Scan now**. The scan lists the folder, then compares files of the same size to find exact duplicates. You get the total, a breakdown by type (videos, images, voice notes, documents, stickers, GIFs, statuses) and the clean-up groups.
3. Open a group, tap the files you want gone (touch and hold to preview), and tap **Move to trash**.
4. Delete them right away to free the space, or leave them in the trash. Anything still there after 7 days (you can pick 1 to 30) is deleted for good the next time you open the app.
5. Open the **Files** tab to browse the folder yourself and open anything in it.

## Browse and open files

The **Files** tab shows every folder you chose. Inside one you can:

- walk through sub-folders (the path at the top takes you back up), **search** by name, **sort** by name, date or size, and switch between a list and a grid of pictures;
- see how many files each folder holds and how big it is, once you have scanned;
- tap a file to open it, or touch and hold to select several and **share** them or **move them to the trash**;
- use a file's menu to **rename** it, see its **details** (size, date, type, pixel size, length), share it or open it in another app.

What opens inside the app:

| Kind | How |
|---|---|
| **Photos, stickers, GIFs** | Full screen. Pinch or double-tap to zoom, swipe for the next file. |
| **Videos** | The player below. |
| **Voice notes and audio** | Play, scrub, skip 10 seconds, speed. |
| **PDFs** | Page by page. Pinch or double-tap to zoom. Password-protected PDFs are handed to another app. |
| **Text** (notes, contacts, CSV, JSON, logs…) | The first 256 KB, selectable. |
| Anything else | **Open with…** another app. |

### Video player

| Do this | To |
|---|---|
| Tap | Show or hide the controls |
| Double-tap the left or right half | Skip 10 seconds back or forward |
| Swipe up or down on the left half | Change the brightness |
| Swipe up or down on the right half | Change the volume |
| Swipe sideways | Scrub (the full width is 90 seconds) |
| Touch and hold | Play at 2× until you let go |

Buttons: previous and next file, **lock** (so a pocket or a child can't touch anything), mute, speed from 0.25× to 3×, picture size (fit, crop to fill, stretch), full screen, and a menu with repeat, a **sleep timer** and **save this frame as a photo**. A video you stopped part-way carries on from there next time. The screen stays on while a video plays.

## What it finds

| Group | What's in it |
|---|---|
| **Largest files** | The 100 biggest files of 1 MB or more, biggest first. |
| **Exact duplicates** | Files with exactly the same content (same size, then the same SHA-256 hash), like a video forwarded to you in three groups. The oldest copy of each is kept and never listed, so even "Select all" leaves one. |
| **Old forwards and memes** | Photos, GIFs and short videos (up to 16 MB) you *received* more than 6 months ago (3, 6, 12 or 24 in Settings). Voice notes, documents and things you sent are never in this group. |
| **Sent media copies** | Files in WhatsApp's `Sent` folders: copies of media you sent, whose originals usually stay in your gallery. |
| **By type** | Every file of one type, for example all statuses or all documents. |

## Why it asks for a folder

Since Android 11, an app can't read another app's media folder on its own. Instead of asking for *All files access*, Chat Media Cleaner uses Android's own folder picker (the Storage Access Framework): you choose `Android/media/com.whatsapp/WhatsApp/Media` once, and the app gets access to **that folder only**. You can take the access back any time in the app's Settings or in Android's settings.

On Android 10 and older the folder is `WhatsApp/Media` at the top of your storage; the app accepts that layout too, and the WhatsApp Business folder (`com.whatsapp.w4b`).

**Choose another folder** adds any other folder the same way, for example Telegram, Download or Camera. Everything works there too, except that "Old forwards and memes" only ever lists files from chat app folders: an old photo in your camera folder is more likely one you took.

The app has **no permissions at all** in its manifest: no storage permission, no `MANAGE_EXTERNAL_STORAGE`, no internet.

## Privacy

- **No internet permission.** The app can't send anything anywhere, and has no analytics, ads or crash reporting.
- A scan reads file names, sizes and dates. Files are only opened to draw thumbnails and to show or play them on screen when you open them.
- Sharing a file opens Android's share sheet; the app you pick there gets that file and nothing else.
- Settings, the trash list and where you stopped each video are stored in the app's private storage on your phone.

## Safety

- **Nothing is deleted unless you select it** and confirm. Groups are suggestions; nothing is pre-selected.
- **Trash first.** "Move to trash" moves files into a hidden `.media-cleaner-trash` folder inside the media folder you chose, with a `.nomedia` file so galleries ignore it. Moving is instant and needs no extra space. **Restore** puts each file back in its original folder under its original name and date (or a numbered name if that name was taken meanwhile).
- **Space is freed when the trash is emptied:** right after moving (if you choose *Delete now*), from the trash screen, or automatically once the restore window (7 days by default) has passed. The automatic clean-up runs when you open the app.
- Deleting a file here removes it from your phone. WhatsApp will show those messages without their media, exactly as if you'd deleted the files in a file manager. The same goes for a file you rename: WhatsApp may no longer find it.

## Not affiliated

Chat Media Cleaner is an independent open-source app. It is not made by, affiliated with or endorsed by WhatsApp or Meta. "WhatsApp" is used only to say which folder the app works with.

## Feedback

Found a file in the wrong group, or a phone where the folder picker doesn't open in the right place? [Open an issue](https://github.com/ChandraChaan/chat-media-cleaner/issues) with your phone model and Android version, or share ideas in [Discussions](https://github.com/ChandraChaan/chat-media-cleaner/discussions).

## For developers

Flutter app with a small Kotlin layer for folder access. Pull requests are welcome; [AGENTS.md](AGENTS.md) has the project rules.

### How it works

| Layer | What it does |
| --- | --- |
| [`StorageChannel.kt`](android/app/src/main/kotlin/dev/chandra/chat_media_cleaner/storage/StorageChannel.kt) | Storage Access Framework on background threads: folder picker with a persisted grant, listing folders (`DocumentsContract` queries), streaming SHA-256 of a file, thumbnails (provider thumbnail, video frame or sampled decode), moving files into and out of the trash (`moveDocument`, so no copying), renaming, sharing and opening a file in another app. Also PDF pages (`PdfRenderer`), picture size and length of media, saving a video frame, and the window brightness and media volume for the player. |
| [`MediaStorage`](lib/features/media/domain/media_storage.dart) | The Dart interface over that platform code; tests use an in-memory fake file tree. |
| [`SourceLocator`](lib/features/media/domain/media_source.dart) | Knows the modern and legacy WhatsApp / WhatsApp Business paths, opens the picker in the right place and finds the `Media` folder inside whatever was picked. |
| [`MediaScanner`](lib/features/media/domain/media_scanner.dart) | Walks the folder tree with progress and cancel, skipping the trash and `.nomedia` files. |
| [`DuplicateFinder`](lib/features/media/domain/duplicate_finder.dart) | Groups files by size, hashes only those that share a size (SHA-256 in Kotlin, two at a time), groups by hash within each folder, keeps the oldest of each set. Sets are re-checked whenever files are trashed or restored, so one copy always stays. |
| [`MediaClassifier`](lib/features/media/domain/media_type.dart) / [`MediaAnalyzer`](lib/features/media/domain/media_report.dart) | Type from the WhatsApp folder name (with a MIME fallback), totals by type, and the smart groups and age rule. |
| [`TrashRepository`](lib/features/trash/domain/trash_repository.dart) | Trash bookkeeping: move, restore (with name clashes and missing folders), delete for good, expiry. The index is a JSON file in app storage. |
| [`FolderListing` / `BrowseOrder`](lib/features/browse/domain/browse_entry.dart) | The Files tab: one folder's contents read live, ordered and searched, with folder totals taken from the last scan. |
| [`ViewKinds`](lib/features/viewer/domain/view_kind.dart) | Decides from extension and MIME type whether a file is shown as a picture, video, sound, PDF or text. |
| [`ViewerScreen`](lib/features/viewer/presentation/viewer_screen.dart) | One swipeable page per file. Video and audio play through [`video_player`](https://pub.dev/packages/video_player) (ExoPlayer) straight from the `content://` address; [`VideoControls`](lib/features/viewer/presentation/player_controls.dart) adds the gestures. |
| [`PlaybackPositions`](lib/features/viewer/domain/playback_positions.dart) | Where each video was stopped, for the 200 most recent. |
| Flutter UI | Riverpod 3 controllers per screen; folder explainer, home, review grid, file browser, viewer, trash and settings; light and dark themes. |

### Build and test

Requirements: Flutter 3.44+, JDK 17, Android SDK.

```bash
flutter pub get
flutter analyze
flutter test                                        # Dart unit and widget tests
(cd android && ./gradlew :app:testDebugUnitTest)    # Kotlin tests
flutter build apk --release --split-per-abi
```

README screenshots and the launcher icon are rendered by tests with fake data:

```bash
flutter test --run-skipped --tags tools --update-goldens test/tools
dart run flutter_launcher_icons
```

#### Release signing

`android/app/build.gradle.kts` reads `android/key.properties` (git-ignored):

```
storeFile=keystore/chat-media-cleaner-release.jks
storePassword=…
keyAlias=chatmediacleaner
keyPassword=…
```

Without that file, release builds fall back to the debug key so the project still builds anywhere. Never commit the keystore or the properties file; both are in `.gitignore`.

## License

[MIT](LICENSE)
