# Muzo — Premium Music Client

<p align="center">
  <img src="assets/logo.png" alt="Muzo Logo" width="150" height="150" />
</p>

<p align="center">
  <strong>A powerful, privacy-focused YouTube Music client built with Flutter.</strong><br/>
  Ad-free · Offline · Lyrics · Gesture-driven · Beautiful
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-lightgrey" alt="Platform" />
  <img src="https://img.shields.io/badge/Version-3.4.0-blueviolet" alt="Version" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

Muzo is a feature-rich, privacy-focused YouTube Music client built with Flutter. It offers a premium ad-free experience with background playback, offline downloads, synchronized & karaoke lyrics, and a modern, fully gesture-driven UI — no account required.

---

## 🚀 Key Features

### 🎧 Immersive Audio Experience
- **Synced & Karaoke Lyrics** — Real-time synchronized lyrics that auto-scroll. Karaoke mode highlights individual words/syllables as they're sung.
- **Lyrics in Gesture Mode** — Frosted-glass lyrics panel above controls in gesture player — double-tap and volume swipe still work through it.
- **Lofi Mode** — Instantly transform any track into a Lofi vibe with slowed speed (0.9×), pitch correction, and native reverb effects.
- **Multi-Language Audio** — Automatically detects and lets you switch between available audio languages.
- **Background Playback** — Keep music playing while using other apps or with screen off.
- **Audio Quality Control** — Choose between High, Medium, and Low quality.
- **Native Audio Effects** — Platform-specific audio effects for a rich sound experience.

### 🕹️ Gesture Player
- **Full Gesture Control** — Fully immersive gesture-based player where album art fills the entire screen.
- **Double-Tap to Play/Pause** — Toggle playback anywhere with an animated flash icon.
- **Swipe Left/Right** — Skip to next or previous track.
- **Swipe Down to Close** — Swipe down on the left half to dismiss the player.
- **Volume Bar** — Swipe up/down on the right half to control volume — frosted-glass vertical bar with fill indicator.
- **Bottom Controls Popup** — Glassmorphic popup with title, artist, progress bar, queue, lyrics, and favorite buttons.

### 📚 Library & Discovery
- **Auto-Queue** — Automatically queues recommended songs for endless playback.
- **Smart Library** — Organize music with **Favorites**, **History**, and custom **Playlists**.
- **Channel Subscriptions** — Subscribe to favorite artists and YouTube channels.
- **Offline Downloads** — Download songs and videos for offline listening.
- **Smart Search** — Quickly find songs, artists, albums, and playlists.
- **Recently Played Grid** — Compact 2-column grid of recently played tracks on the home screen.

### 🎨 Modern UI/UX
- **Sleek Glassmorphism** — Beautiful glassmorphic elements and smooth animations throughout.
- **Immersive Player** — Dynamic blurred album art background for a premium visual experience.
- **Dynamic Theming** — UI automatically adapts colors from the currently playing album art.
- **Marquee Titles** — Auto-scrolling text for long song and artist names.
- **Smooth Transitions** — Fluid zoom and slide animations between screens.
- **Consistent Dark Theme** — Optimized contrast and colors for a comfortable dark mode.

### 🛡️ Privacy & Reliability
- **Zero-Wait Launch** — App initializes instantly with parallel background loading.
- **Ad-Free Streaming** — Enjoy music without interruptions.
- **Privacy Focused** — No login required. All data (favorites, playlists, history) stored locally.
- **RapidAPI Fallback** — Robust fallback ensures playback reliability if the primary API fails.
- **Share to Play** — Share links from YouTube or YouTube Music directly into Muzo.

---

## 📸 Screenshots

<p align="center">
  <img src="images/1.jpg" width="30%" />
  <img src="images/2.jpg" width="30%" />
  <img src="images/3.jpg" width="30%" />
  <img src="images/4.jpg" width="30%" />
  <img src="images/5.jpg" width="30%" />
  <img src="images/6.jpg" width="30%" />
  <img src="images/7.jpg" width="30%" />
  <img src="images/8.jpg" width="30%" />
  <img src="images/9.jpg" width="30%" />
  <img src="images/10.jpg" width="30%" />
  <img src="images/11.jpg" width="30%" />
  <img src="images/12.jpg" width="30%" />
  <img src="images/13.jpg" width="30%" />
  <img src="images/14.jpg" width="30%" />
</p>

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev/) + [Dart](https://dart.dev/) |
| **State Management** | [Riverpod](https://riverpod.dev/) |
| **Audio Engine** | [Just Audio](https://pub.dev/packages/just_audio) & [Audio Service](https://pub.dev/packages/audio_service) |
| **YouTube Extraction** | [youtube_explode_dart](https://github.com/Hexer10/youtube_explode_dart) (fork by [anandnet](https://github.com/anandnet)) |
| **Music Stream API** | [JioSaavn API](https://github.com/n-ce/fast-saavn) — powered by [n-ce/fast-saavn](https://github.com/n-ce/fast-saavn) |
| **Lyrics** | [flutter_lyric](https://pub.dev/packages/flutter_lyric) + custom karaoke engine |
| **Local Storage** | [Hive](https://docs.hivedb.dev/) |
| **Networking** | [Dio](https://pub.dev/packages/dio) & [Http](https://pub.dev/packages/http) |
| **UI Components** | [FluentUI System Icons](https://pub.dev/packages/fluentui_system_icons), [Google Fonts](https://pub.dev/packages/google_fonts), [Cached Network Image](https://pub.dev/packages/cached_network_image) |
| **API** | Custom YouTube Internal API & RapidAPI (fallback) |

---

## ⚙️ Setup & Installation

### Prerequisites

- Flutter SDK (Latest Stable)
- Dart SDK
- Android Studio / VS Code
- Java JDK 17

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Shashwat-CODING/Muzo.git
   cd Muzo
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

4. **Build release APK** (split by ABI for smaller size):
   ```bash
   flutter build apk --split-per-abi
   ```

---

## 🤝 Contributing

Contributions are welcome! Whether it's reporting a bug, suggesting a feature, or writing code, your help is appreciated.

### How to Contribute

1. **Fork the Project**
2. **Create your Feature Branch** (`git checkout -b feature/AmazingFeature`)
3. **Commit your Changes** (`git commit -m 'Add some AmazingFeature'`)
4. **Push to the Branch** (`git push origin feature/AmazingFeature`)
5. **Open a Pull Request**

### Development Guidelines

- Follow the existing code style.
- Use `flutter analyze` to check for linting errors.
- Ensure new features are tested before submitting a PR.

---

## 🙏 Acknowledgements

Muzo wouldn't exist without the incredible work of these developers and projects. Huge thanks to:

### 🎬 youtube_explode_dart
A massive thank you to **[Hexer10](https://github.com/Hexer10)**, the original author of [youtube_explode_dart](https://github.com/Hexer10/youtube_explode_dart) — the backbone of Muzo's YouTube streaming and metadata extraction. Also special thanks to **[anandnet](https://github.com/anandnet)** for maintaining an up-to-date fork that keeps Muzo working with the latest YouTube changes.

### 🎵 Animesh (n-ce) — fast-saavn & ytify
An enormous shoutout to **[Animesh (n-ce)](https://github.com/n-ce)** — creator of:
- **[fast-saavn](https://github.com/n-ce/saavn)** — the blazing-fast, open JioSaavn API that powers Muzo's music streaming to make app even faster and more reliable.
- **[ytify](https://github.com/n-ce/ytify)** — a beautifully minimal YouTube audio streaming web app that was a **huge source of inspiration** during Muzo's development. Animesh's approach to UI, UX, and YouTube audio handling influenced many of Muzo's design decisions. Thank you for the open-source spirit and for being so helpful throughout the development journey! 🙌

### 📦 Open-Source Libraries
Muzo stands on the shoulders of these amazing Flutter/Dart packages:

| Package | Author / Maintainers |
|---|---|
| [just_audio](https://pub.dev/packages/just_audio) | [Ryan Heise](https://github.com/ryanheise) |
| [audio_service](https://pub.dev/packages/audio_service) | [Ryan Heise](https://github.com/ryanheise) |
| [riverpod](https://pub.dev/packages/flutter_riverpod) | [Remi Rousselet](https://github.com/rrousselGit) |
| [hive](https://pub.dev/packages/hive) | [Hive Authors](https://github.com/hivedb/hive) |
| [flutter_lyric](https://pub.dev/packages/flutter_lyric) | [lyric contributors](https://pub.dev/packages/flutter_lyric) |
| [palette_generator](https://pub.dev/packages/palette_generator) | [Flutter Team](https://github.com/flutter/packages) |
| [cached_network_image](https://pub.dev/packages/cached_network_image) | [Baseflow](https://github.com/Baseflow/flutter_cached_network_image) |
| [dio](https://pub.dev/packages/dio) | [cfug](https://github.com/cfug/dio) |
| [flutter_animate](https://pub.dev/packages/flutter_animate) | [gskinner](https://github.com/gskinner/flutter_animate) |

---

## 📝 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

<p align="center">
  Built with
  <img src="https://uxwing.com/wp-content/themes/uxwing/download/relationship-love/red-heart-icon.png" alt="love" height="16" />
  <img src="https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/claude-ai-icon.png" alt="Claude AI" height="16" />
  <img src="https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/google-gemini-icon.png" alt="Gemini AI" height="16" />
  <img src="https://files.brandlogos.net/svg/HNipmYPqfV/Google_Antigravity-logo_brandlogos.net_e23c83.svg" alt="Antigravity" height="16" />
  <br/>
  By <strong>Shashwat</strong>
</p>
