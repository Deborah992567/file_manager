# Changelog

All notable milestones in the Nova Files build are listed here, newest first.

## [0.1.0] — Milestone: 80 pushed commits

- Full feature set shipped: browse (grid/list), search, favorites & tags,
  biometric Locked Folder, trash-with-undo, zip, drag & drop, Quick Look,
  storage donut + cleanup, biometric app lock, splash + onboarding.
- Verified build: `xcodebuild` succeeds with **zero warnings**.
- Headless verification suite (`./scripts/verify_services.sh`): 11/11 checks
  pass — zip round-trips (text/binary/nested), zip-slip defense, deterministic
  byte formatting.
- Simulator smoke test (`./scripts/smoke_launch.sh`): app installs, launches,
  and stays alive on a booted simulator.
- Housekeeping: `.gitignore`, `LICENSE`, build/smoke/verify scripts,
  component previews, VoiceOver labels, header-button extraction.

## [0.0.2] — Services + view models complete

- `FileService` (moves/copies/renames, trash + undo, favorites/tags/recents,
  Locked Folder), `StorageService` (donut accounting, device usage),
  `SecurityService` (LocalAuthentication), `SearchService` (actor-safe walk),
  `ZipService` (dependency-free zlib archive read/write).
- Six `@MainActor` view models behind all screens.

## [0.0.1] — Foundation

- Xcode project (synchronized groups), app entry, theme/motion/haptics design
  system, item/folder/settings models.