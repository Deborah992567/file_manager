# Nova Files

A production-grade iOS file manager built with SwiftUI, targeting iOS 17+.

Nova Files is a self-contained file browser with a cinematic dark interface:
folder navigation (grid + list), search, favorites, color tags, a biometric
Locked Folder, archive extraction/inspection, batch operations, drag & drop,
and storage analytics — **zero third-party dependencies**.

## Features

- **Browse** — grid & list views, breadcrumb trails, quick-access chips
  (Recents, Favorites, Locked Folder, Downloads), animated hero folder
  expansion, pull-to-refresh.
- **Search** — live, debounced, full-sandbox search grouped by file kind,
  with kind filters and a persisted recent-searches row.
- **Favorites & Tags** — star anything, color-tag files, filter by kind.
- **Locked Folder** — Face ID / Touch ID gated private folder.
- **Operations** — rename, move, copy, delete-to-trash with **Undo**,
  multi-select batch actions, zip compress, drag & drop, document & photo
  import.
- **Preview** — native Quick Look for documents/media/archives, plus a rich
  metadata preview sheet.
- **Storage** — animated donut chart of the whole sandbox by category,
  device usage bar, cache cleanup with freed-space reporting.
- **Security** — optional biometric app lock on launch.

## Design System

Everything visual flows from a single source of truth in
`FileManagerApp/Utilities/`:

- `Theme.swift` — cinematic dark palette (#0A0A0C base), typography, shadows.
- `AppMotion.swift` — one shared spring (`response 0.4, dampingFraction 0.8`).
- `Haptics.swift` — lightweight static haptic generators.

## Architecture

MVVM with observation-driven state:

```
FileManagerApp/
  App/          Entry point, AppState (phase routing, toasts, app lock)
  Models/       FileItem, FolderNode, settings, preferences, toast messages
  Services/     FileService, StorageService, SecurityService, SearchService,
                ZipService (hand-rolled zlib-based archive support)
  ViewModels/   One per screen (Folder, Search, Favorites, Settings,
                LockedFolder, Preview)
  Views/        Root, Browser, Search, Favorites, Settings, Storage,
                LockedFolder, Preview sheet, onboarding & splash
  Components/   Reusable views (tab bar, cells, rows, toasts, chips, …)
  Utilities/    Theme, motion, haptics, formatters, extensions
```

`FileService` owns all filesystem mutations (and the trash/undo bookkeeping);
view models are thin coordinators; views never touch the filesystem directly.

## Build

Open `FileManagerApp.xcodeproj` in Xcode 16+ (the project uses synchronized
file-system groups, so new files under `FileManagerApp/` are picked up
automatically) and run the `FileManager` scheme on an iOS 17+ simulator or
device. No package resolution or CocoaPods needed.

Or from the terminal:

```sh
./scripts/build.sh                    # Debug, generic iOS simulator
```

## Verification

```sh
./scripts/verify_services.sh          # 11/11 headless checks (zip + formatting)
./scripts/smoke_launch.sh             # boot sim, install, launch, confirm alive
```

## License

All rights reserved. This project is a personal build-milestone showcase.