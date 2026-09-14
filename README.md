# OpenFocusly

> **A calm place to track, focus, and reflect — fully offline, private, and local.**

OpenFocusly is a cross-platform productivity app built with Flutter that lets you track numbers, set goals, manage notes, run focus sessions, and keep a calendar — all without sending a single byte of your data off your device.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white&style=flat-square)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white&style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## ✨ Features

### 🔢 Counters
- Create unlimited counters with custom **name**, **value**, **step**, and **symbol**.
- Organize counters into **folders** for a tidy workspace.
- Set **value goals** and **money goals** — optionally derive money from a multiplier or track it independently.
- Pin important counters to keep them one tap away.
- Swipe actions: pin/unpin, delete.
- Full-screen counter view with big tap targets, volume-button control, keep-screen-on, and built-in stopwatch.

### ⏱️ Focus Timer
- Simple, distraction-free **Pomodoro-style timer** with customizable durations (5 to 60+ minutes).
- Visual progress ring and a clean start/pause/reset interface.
- Automatically logs a note when a session completes.

### 📅 Calendar & Events
- Monthly calendar view with date badges showing notes/events.
- Add notes directly from any day.
- Search across all notes and events.

### 📝 Markdown Notes
- **Live markdown editor** with inline formatting hints (bold, italic, code, links, headings).
- **Syntax highlighting** for fenced code blocks (Dart, JS, TS, Java, Kotlin).
- Live preview mode.
- Read-only mode for distraction-free reading.
- Notes are stored as real `.md` files in a user-selected folder via **Android SAF** (Storage Access Framework) — no cloud, no proprietary format.

### 🌍 Localization
- English 🇬🇧 and Italian 🇮🇹 built-in.
- Easy to extend with additional JSON files under `assets/lang/`.

### 🎨 Appearance
- Light, dark, and system themes.
- Clean, minimal design with a soft blue accent and card-based layout.

### 🔔 Feedback
- Optional haptic vibration and sound effects (`plus.mp3`, `minus.mp3`).
- Remap volume buttons to increment/decrement counters.

### 💾 Data Control
- All state stored locally in a single JSON file.
- **Backup** to any location (JSON) and **restore** from backup.
- Export/import notes as a single Markdown file.
- Nothing ever leaves your device.

---

## 📱 Supported Platforms

OpenFocusly runs on:

- **Android** (primary, with SAF-based file access)
- **iOS**
- **Web**
- **Windows**
- **macOS**
- **Linux**

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | **Flutter** (Dart) |
| State Management | `ChangeNotifier` + custom `Store` (three global singletons) |
| Design system | hand-drawn `CustomPaint` icons, no icon font, no Material widgets |
| Navigation | Custom `Nav` controller (no external packages) |
| File Access | Android Storage Access Framework via platform channels |
| Code Highlighting | Custom-built Dart/JS/TS/Java/Kotlin highlighter |
| Localization | JSON-based custom loader |

No third-party packages are used — everything is built from scratch for maximum reliability and control.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x) — [install guide](https://docs.flutter.dev/get-started/install)
- For Android: Android Studio with SDK 17+ (Java 17 target)
- For desktop: CMake, Ninja, and platform-specific toolchains

### Clone & Run
```bash
git clone https://github.com/CarbonWalls/OpenFocusly.git
cd OpenFocusly
flutter pub get
flutter run
```

### Build a Release APK

```
flutter build apk --release
```

---

## 📂 Project Structure

```
OpenFocusly/
├── lib/
│   └── main.dart          # the whole app: models, store, nav, theme, icons, screens
├── test/
│   ├── screens_test.dart  # golden-shot harness — renders 22 real screens to PNG
│   └── goldens/           # reference renders (light, dark, wide, empty states)
├── legacy/
│   └── lib/               # an earlier modular refactor, kept for reference; not built
├── assets/
│   ├── icon/              # launcher icon source
│   ├── audio/             # optional drop-in sounds
│   └── lang/              # reserved (UI strings are compiled into main.dart)
├── android/               # Flutter runner + the `saf` platform channel (MainActivity.kt)
├── ios/  web/  windows/  macos/  linux/
└── pubspec.yaml           # zero runtime dependencies
```

Everything lives in `lib/main.dart` on purpose: no package graph, no codegen, no
build runners. The file is organised in commented sections — tokens, palette,
icons, models, nav, primitives, chrome, focus engine, shell, then one section
per screen.

### Reviewing the UI without a device

The golden harness boots the real widget tree (mocked platform channel) and
writes one PNG per screen, so interface changes can be reviewed in seconds
instead of a full Flutter + Gradle cycle:

```bash
flutter test --update-goldens test/screens_test.dart   # ~30s for 22 screens
```

---

## 🎮 Customizing Sound & Language

### Audio

Counter taps use the platform's own light click/tick (`SystemSound`) — no audio
files are required. The end-of-session chime can be any sound you already own:
**Settings → Focus → Completion sound** opens the system picker and stores the
document URI, which the Android side plays through the notification channel.

The volume keys can drive the focused counter instead of the media volume
(full-screen counter view → the clock toggle).

### Language

Italian and English are compiled in (`const it` / `const en` maps in
`main.dart`, with a second-generation override map for newer strings).
Switching is instant and lives in Settings → Language. `assets/lang/` is kept
for a future runtime loader but is not read yet.

---

## 🔒 Privacy

OpenFocusly is **100% local-first**. There is:

- No analytics
- No cloud sync
- No telemetry
- No internet permission required (except during development hot-reload)

Your data belongs to you — always.

---

## 📄 License

Released under the [MIT License](https://LICENSE).

Copyright (c) 2026 CarbonWalls

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs via Issues
- Suggest features
- Submit pull requests

Please keep the codebase dependency-free and aligned with the existing minimal design philosophy.
