# Changelog

All notable milestones in the Nova Files build are listed here, newest first.

## [0.4.0] — Milestone: 130 pushed commits

- Launch polish: the splash now staggers its wordmark in, settles the mark
  with a soft overshoot wobble and loops a baseline shimmer under the tagline.
- Onboarding liveliness: page icons breathe and drip an orbiting dash ring,
  swipes tick a light haptic, a page counter tracks progress and the primary
  action sparks with a one-shot shine.
- Micro-interactions elsewhere: photo thumbnails shimmer while decoding then
  fade in, toast icons pop on arrival, sort-direction arrows bounce, quick-access
  chips stagger in, the storage donut races its sectors a place, and tab icons
  celebrate selection with a bounce.
- Every build still compiles with zero Swift warnings.

## [0.3.0] — Milestone: 120 pushed commits

- Correctness: context-menu "Select All" now actually enters selection mode
  and closes the menu; deflate streams verify their inflated size; the
  smoke-launch probe matches the real bundle id.
- Engineering: single-pass search-result bucketing, shared storage tree walk,
  generic persisted-settings decoding, one detail-line helper, cached
  on-device extension strings, dead API pruned (favorites selection,
  biometric toggle passthrough, tag-toast passthrough).
- Accessibility continued: storage bar/donut, locked-folder row delete,
  accent/theme/sort/search selection state, lock & unlock controls, toast
  host single-animation source.
- Every build still compiles with zero Swift warnings.

## [0.2.0] — Milestone: 110 pushed commits

- Accessibility sweep: VoiceOver labels, hints and custom actions for grid
  tiles, list rows, folder picker rows, selection bar, favorites actions,
  folder-picker rows, storage bar/donut, search chips & recents, sort sheet.
- Light-mode support: the theme exposes an adaptive palette so the app stays
  legible (and deliberately cinematic) in both appearances.
- Real actions wired into native context menus (favorite, duplicate, rename,
  move, zip, share, delete) — previously decorative placeholders.
- Engineering: cached byte formatter, shared free-name walker, shared
  file-system values reader, single favorite-toggle path, deflate size
  verification, hardened smoke-launch probe, generic settings decoding.
- Broader component preview coverage; every build still zero Swift warnings.

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