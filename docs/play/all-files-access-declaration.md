# "All files access" declaration (MANAGE_EXTERNAL_STORAGE)

Play Console › Policy and programs › App content › **All files access** (it appears once a bundle that requests `MANAGE_EXTERNAL_STORAGE` is uploaded). Version 1.2.0 (version code 3) is the first build that requests it.

## Core functionality: pick

**File management** ("file manager or file browser apps whose primary purpose is to access, edit or manage files and folders on the device").

## Why the app needs it (paste)

```
Chat Media Cleaner is a file manager. Its Files tab lets the user browse their whole internal storage and memory card, and copy, move, rename, compress (ZIP), extract and delete files and folders anywhere on the device. It also measures storage by type of file and finds large and duplicate files across the device so the user can free space. These features need to read and write every folder on shared storage, which scoped storage and MediaStore can't provide: MediaStore covers only media files and the user's own documents, and it can't create, move or delete folders that other apps made. The Storage Access Framework gives access to one folder at a time, and since Android 11 it can't open the root of storage, Download or Android/media. That makes browsing, copying and moving files and folders between arbitrary locations impossible. The app has no internet permission: file names and contents never leave the device. The permission is optional. Users who decline keep a limited mode that works only in folders they pick with the system folder picker.
```

## Why less invasive options don't work (if asked separately)

```
The Storage Access Framework only grants single folders the user picks, can't grant the storage root, Download or Android/media on Android 11 and later, and doesn't support moving files between folders the user didn't grant. MediaStore only exposes media and documents and can't manage folders or files of other types (archives, APKs and app media). A file manager needs both across the whole device.
```

## Video (required)

Play asks for a link to a short video (YouTube unlisted or a Google Drive share) showing:

1. the in-app explanation (Files tab › "Browse all your files" card, or the first-start screen);
2. tapping **Allow access to all files** and Android's "All files access" switch for the app;
3. the core file-manager use: opening Internal storage, creating a folder, copying a file into it, compressing and extracting, the Storage screen.

A recording made on an emulator is in the session's scratchpad (see the PR description). Upload it yourself and paste the link.

## Other App content to re-check for 1.2.0

- **Data safety:** unchanged. The app still collects and shares nothing (no internet permission).
- **Content rating, target audience, ads, app access:** unchanged.
- **Store listing:** use `docs/play/store-listing.md`, which describes the app as a file manager. Review checks that the listing matches the declared core functionality.
