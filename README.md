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
| State Management | `ChangeNotifier` + custom `Store` |
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
│   ├── main.dart          # App entry & root shell
│   ├── screens.dart       # All screens (Home, Counters, Time, Notes, Settings, Info)
│   ├── store.dart         # Data models, persistence, nav, sound
│   ├── theme.dart         # Palette, icons, reusable widgets (Btn, Field, etc.)
│   ├── lang.dart          # Localization loader
│   └── md/
│       ├── controller.dart # Live markdown editing controller
│       ├── editor.dart     # Live markdown editor widget
│       ├── preview.dart    # Markdown preview widget
│       └── syntax.dart     # Custom syntax highlighter
├── assets/
│   ├── audio/             # plus.mp3 / minus.mp3 for feedback sounds
│   └── lang/              # en.json, it.json (localization)
├── android/               # Android runner + SAF platform channel
├── ios/                   # iOS runner
├── web/                   # Web build
├── windows/               # Windows runner
├── macos/                 # macOS runner
├── linux/                 # Linux runner
└── test/                  # Tests (placeholder)
```

---

## 🎮 Customizing Sound & Language

### Audio

Place `plus.mp3` and `minus.mp3` in `assets/audio/`. These play on counter increments/decrements when the sound setting is enabled.

### Language

Add a new JSON file to `assets/lang/` (e.g., `de.json`) with the same key structure as `en.json`. The app automatically detects it at startup.

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
