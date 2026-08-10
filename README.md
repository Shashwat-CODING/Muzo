<div align="center">

<img src="assets/logo 1.webp" alt="Muzo Logo" width="140" height="140" />

# Muzo

**A powerful, privacy-focused YouTube Music client built with Flutter.**
Ad-free · Offline · Synced Lyrics · Liquid Glass UI · Smart Cache

[![Get it on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo)

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-lightgrey)
![Version](https://img.shields.io/badge/Version-5.2.0-blueviolet)
![License](https://img.shields.io/badge/License-MIT-green)

</div>

<br/>

<div align="center">

## 🚨 THIS REPOSITORY IS NO LONGER UPDATED 🚨

### **Development has moved off GitHub. Muzo is now closed-source going forward.**
### **All active development and updates now ship exclusively through the Google Play Store.**

| | |
|:---:|:---:|
| ❌ **No new commits** | ❌ **No new GitHub releases** |
| ❌ **No APKs published here** | ❌ **Issues / PRs no longer tracked here** |
| ✅ **Continuous updates on Play Store** | ✅ **New features ship there first** |

### 👉 [**Get the latest version on Google Play**](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo) 👈

> **Already fixed:** most bugs and issues reported against this repo have already been resolved — but **only in the Play Store build**. This source code is an old, frozen snapshot and does **not** include those fixes.

*This code is preserved for historical/reference purposes only. Building from this source will **not** give you the current, bug-free experience — install from the Play Store instead.*

</div>

---

Muzo is a feature-rich, privacy-focused YouTube Music client built with Flutter, offering a premium ad-free experience with background playback, offline downloads, synchronized & karaoke lyrics, a modern Liquid Glass UI, smart background caching, Spotify playlist imports, a sleep timer, and community sharing — with or without an account.

---

## ✨ Key Features

### 🎨 Liquid Glass UI/UX
- **Dynamic Glassmorphic Themes** — Premium styling in both Dark and Light modes using the dynamic `liquid_glass_easy` package. Light Mode features a semi-transparent white tint that adapts dynamically to the album art.
- **Custom Shaders & Blur** — High-performance frosted glass panels, overlays, and custom shaders that adapt smoothly to artwork colors.
- **Contrast-Aware Elements** — Status bar icons, player controls, progress sliders, borders, and menus automatically invert colors based on the active theme for perfect legibility.
- **Big Screen & Desktop Optimization** — Responsive player layouts with max-width constraints (up to 1300px), centered dialogs, and a dedicated top search bar and profile dropdown for larger screens.
- **Sleek iOS-Inspired Forms** — Pill-shaped inputs and circular badges throughout upload/edit menus and notifications.

### 🎧 Immersive Audio & Synced Lyrics
- **Smooth Word-by-Word Karaoke** — Words fill up with color gradually in real time as the artist sings, running at a buttery-smooth 60+ FPS.
- **Line-by-Line Synced Sweep** — A progressive sweep effect colors repeated lines sequentially.
- **Active Line Highlight & Scrolling** — The active line slides slightly right and lights up; scrolling glides smoothly rather than jumping.
- **Lofi Mode** — Turn any track into a Lofi vibe with slowed speed (0.9×), pitch correction, and native reverb.
- **Multi-Language Audio & Quality Control** — Detects and switches between available languages and streams in High, Medium, or Low quality.
- **Background Playback & Native Effects** — Music keeps playing with the screen off, using platform-specific audio effects.

### ⚡ Smart Cache System
- **Asynchronous Background Caching** — Automatically caches new tracks in the background when added to playlists, favorites, or the library.
- **Multi-Resolution Artwork Caching** — Downloads and saves both high- and low-res thumbnails locally for instant visual feedback.
- **Instant Zero-Wait Playback** — Bypasses network request time entirely for cached tracks.
- **Bandwidth-Aware Checks** — Skips download queues for already-cached tracks to save battery and data.

### 📚 Discovery, Import & Community
- **Spotify Playlist Import** — Paste any public Spotify playlist URL to instantly import your tracks.
- **Community Feed & Sharing** — Search, stream, and discover tracks uploaded by the community.
- **Artist Following** — Follow favorite artists and channels directly from their profile pages.
- **Smart Queue & Infinite Playback** — Queue clearing empties upcoming songs in auto-queue mode; the clear button disables when only the active song remains.
- **Offline Downloads** — Download songs and videos for offline listening.
- **Recently Played Grid** — Compact 2-column grid of recently played tracks on the home screen.
- **Custom Canvas Video Backgrounds** — Support for custom MP4 canvas backgrounds with a dedicated uploader dashboard.

### 🔒 Privacy & Accounts
- **Optional Accounts & Cloud Sync** — Sign in with Google to upload your own tracks and view your Apple-style Profile Card.
- **Privacy First** — No login required; favorites, playlists, and history are stored locally by default.
- **Zero-Wait Launch** — Parallel background loading for instant app startup.
- **Ad-Free & Reliable** — RapidAPI and Metadata API Relay fallback (with Hugging Face bucket caching) guarantee playback.
- **Share to Play** — Share links from YouTube or YouTube Music directly into Muzo.
- **Muzo Deep Linking (`muzo://`)** — Full custom URL scheme to open/play songs (`muzo://s/<id>`), artists (`muzo://artist/<id>`), albums (`muzo://album/<id>`), and playlists (`muzo://playlist/<id>`).

---

## ☕ Support & Donations

If you love Muzo and want to support its ongoing development, consider donating — your support keeps the project alive and ad-free.

> **Note:** All crypto addresses below accept **USDT** on their respective networks.

**UPI (India):** `shashwat2817@fam`

<details>
<summary><strong>Cryptocurrency (USDT) addresses</strong></summary>

| Network | USDT Address |
| :--- | :--- |
| USDT (ERC-20) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| Optimism (OP) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| Arbitrum One (ARETH) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| opBNB | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| BNB Smart Chain (BEP-20) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| Solana (SOL) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| TRON (TRC-20) | `TRvZLT4F3W2xrKmduc6fQ6RLJM6Jy5ny7w` |
| Avalanche C-Chain (AVAX) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| Celo | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| Polygon (MATIC) | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |

</details>

---

## 🌍 Localisation

Muzo is fully localised into 20 languages, all at 100% coverage:

`en` `hi` `bn` `ar` `ru` `es` `fr` `de` `ja` `kk` `te` `as` `zh` `pa` `pl` `pt` `sr` `tr` `ur` `ko`

English · Hindi · Bengali · Arabic · Russian · Spanish · French · German · Japanese · Kazakh · Telugu · Assamese · Chinese · Punjabi · Polish · Portuguese · Serbian · Turkish · Urdu · Korean

---

## 📸 Screenshots

### 🏠 Home & Navigation
<p align="center">
  <img src="images/home.jpg" width="30%" alt="Home Screen" />
  <img src="images/home_with_miniplayer.jpg" width="30%" alt="Home with Mini Player" />
  <img src="images/library.jpg" width="30%" alt="Library" />
</p>

### 🔍 Search
<p align="center">
  <img src="images/search_with _results.jpg" width="30%" alt="Search Results" />
  <img src="images/search_with _search_suggestions.jpg" width="30%" alt="Search Suggestions" />
</p>

### 🎧 Player
<p align="center">
  <img src="images/Immersive_player.jpg" width="30%" alt="Immersive Player" />
  <img src="images/leagcy_player.jpg" width="30%" alt="Legacy Player" />
  <img src="images/song_queue.jpg" width="30%" alt="Song Queue" />
</p>

### 🎤 Lyrics
<p align="center">
  <img src="images/lyrics_with_controls.jpg" width="30%" alt="Lyrics with Controls" />
  <img src="images/lyrics_without_controls.jpg" width="30%" alt="Lyrics without Controls" />
</p>

### 👥 Community & Profile
<p align="center">
  <img src="images/community.jpg" width="30%" alt="Community Feed" />
  <img src="images/profile_screen.jpg" width="30%" alt="Profile Screen" />
</p>

### ⚙️ Settings & Customization
<p align="center">
  <img src="images/settings.jpg" width="30%" alt="Settings" />
  <img src="images/app_theme_selector.jpg" width="30%" alt="Theme Selector" />
  <img src="images/accent_color_selector.jpg" width="30%" alt="Accent Color" />
  <img src="images/custom_accent_color_selector.jpg" width="30%" alt="Custom Accent Color" />
  <img src="images/app_language_selector.jpg" width="30%" alt="Language Selector" />
</p>

### ℹ️ About
<p align="center">
  <img src="images/about_screen.jpg" width="30%" alt="About Screen" />
</p>

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev/) + [Dart](https://dart.dev/) |
| **State Management** | [Riverpod](https://riverpod.dev/) |
| **Audio Engine** | [Just Audio](https://pub.dev/packages/just_audio) & [Audio Service](https://pub.dev/packages/audio_service) |
| **YouTube Extraction** | [youtube_explode_dart](https://github.com/Hexer10/youtube_explode_dart) (fork by [anandnet](https://github.com/anandnet)) |
| **Music Metadata API** | [JioSaavn API](https://github.com/n-ce/Uma) — powered by [n-ce/Uma](https://github.com/n-ce/Uma) |
| **Lyrics** | [flutter_lyric](https://pub.dev/packages/flutter_lyric) + custom karaoke engine |
| **Local Storage** | [Hive](https://docs.hivedb.dev/) |
| **Networking** | [Dio](https://pub.dev/packages/dio) & [Http](https://pub.dev/packages/http) |
| **UI Components** | `liquid_glass_easy`, [FluentUI System Icons](https://pub.dev/packages/fluentui_system_icons), [Google Fonts](https://pub.dev/packages/google_fonts), [Cached Network Image](https://pub.dev/packages/cached_network_image) |
| **API** | Custom YouTube Internal API & RapidAPI (fallback) |

---

## ⚙️ Setup & Installation

> ⚠️ Reminder: this repo is a frozen, outdated snapshot — known issues from this version have already been fixed, but only in the Play Store build. For the real, up-to-date, bug-fixed app, install from the [Play Store](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo). The steps below are kept for historical/reference purposes only.

**Prerequisites:** Flutter SDK (latest stable), Dart SDK, Android Studio / VS Code, Java JDK 17

```bash
# Clone the repository
git clone https://github.com/Shashwat-CODING/Muzo.git
cd Muzo

# Install dependencies
flutter pub get

# Run the app
flutter run

# Build release APK (split by ABI for smaller size)
flutter build apk --split-per-abi
```

---

## 🙏 Acknowledgements

Muzo wouldn't exist without the incredible work of these developers and projects:

### YouTube Extraction
Huge thanks to **[Hexer10](https://github.com/Hexer10)**, original author of [youtube_explode_dart](https://github.com/Hexer10/youtube_explode_dart) — the backbone of Muzo's YouTube streaming and metadata extraction — and to **[anandnet](https://github.com/anandnet)** for maintaining an up-to-date fork.

### Animesh (n-ce) — fast-saavn & ytify
An enormous shoutout to **[Animesh (n-ce)](https://github.com/n-ce)**, creator of:
- **[fast-saavn](https://github.com/n-ce/saavn)** — the blazing-fast, open JioSaavn API powering Muzo's music metadata, song details, and search.
- **[ytify](https://github.com/n-ce/ytify)** — a beautifully minimal YouTube audio streaming web app that was a huge source of inspiration for Muzo's UI/UX and audio handling.

### Open-Source Libraries

| Package | Author / Maintainers |
|---|---|
| [just_audio](https://pub.dev/packages/just_audio) | [Ryan Heise](https://github.com/ryanheise) |
| [audio_service](https://pub.dev/packages/audio_service) | [Ryan Heise](https://github.com/ryanheise) |
| [riverpod](https://pub.dev/packages/flutter_riverpod) | [Remi Rousselet](https://github.com/rrousselGit) |
| [hive](https://pub.dev/packages/hive) | [Hive Authors](https://github.com/hivedb/hive) |
| [flutter_lyric](https://pub.dev/packages/flutter_lyric) | [flutter_lyric contributors](https://pub.dev/packages/flutter_lyric) |
| [palette_generator](https://pub.dev/packages/palette_generator) | [Flutter Team](https://github.com/flutter/packages) |
| [cached_network_image](https://pub.dev/packages/cached_network_image) | [Baseflow](https://github.com/Baseflow/flutter_cached_network_image) |
| [dio](https://pub.dev/packages/dio) | [cfug](https://github.com/cfug/dio) |
| [flutter_animate](https://pub.dev/packages/flutter_animate) | [gskinner](https://github.com/gskinner/flutter_animate) |
| [google_sign_in](https://pub.dev/packages/google_sign_in) | [Flutter Team](https://github.com/flutter/packages) |
| [app_links](https://pub.dev/packages/app_links) | [Julien Eluard](https://github.com/llfbandit) |

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">

Built with ❤️ using Claude AI, Gemini AI, and Antigravity

**By Shashwat**

</div>
