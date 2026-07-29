# Muzo — Premium Music Client

<p align="center">
  <img src="assets/logo.png" alt="Muzo Logo" width="150" height="150" />
</p>

<p align="center">
  <strong>A powerful, privacy-focused YouTube Music client built with Flutter.</strong><br/>
  Ad-free · Offline · Synced Lyrics · Liquid Glass UI · Smart Cache
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.Shashwat.Muzo">
    <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="60" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-lightgrey" alt="Platform" />
  <img src="https://img.shields.io/badge/Version-2.0.0-blueviolet" alt="Version" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

> [!WARNING]
> **GitHub Releases Discontinued**  
> No more releases or updates will be made on GitHub. All future updates will be distributed exclusively through the **[Google Play Store](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo)**.

Muzo is a feature-rich, privacy-focused YouTube Music client built with Flutter. It is now available on the [Google Play Store](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo)! It offers a premium ad-free experience with background playback, offline downloads, synchronized & karaoke lyrics, a modern Liquid Glass UI, smart background caching, Spotify playlist imports, a sleep timer, and community sharing — with or without an account.

---

## <img src="https://img.icons8.com/fluency/20/rocket.png" align="absmiddle"/> Key Features

### <img src="https://img.icons8.com/fluency/18/color-palette.png" align="absmiddle"/> Liquid Glass UI/UX
- **Dynamic Glassmorphic Themes** — Premium styling in both Dark and Light modes using the dynamic `liquid_glass_easy` package. Light Mode features a beautiful, semi-transparent white tint (light glassmorphism) that adapts dynamically to the album art.
- **Custom Shaders & Blur** — High-performance frosted glass panels, overlays, and custom shaders that adapt smoothly to artwork colors.
- **Contrast-Aware Elements** — Status bar icons, player controls, progress sliders, borders, and menus automatically invert colors based on the active theme for perfect legibility.
- **Big Screen & Desktop Optimization** — Optimized player layouts with responsive max-width constraints (up to 1300px), centered dialogs, and a dedicated top search bar and profile dropdown menu for desktop, laptop, and tablet formats.
- **Sleek iOS-Inspired Forms** — Rebuilt music upload/edit menus and notifications using modern pill-shaped inputs and circular badges.

### <img src="https://img.icons8.com/fluency/18/headphones.png" align="absmiddle"/> Immersive Audio & Synced Lyrics
- **Smooth Word-by-Word Karaoke** — Words in karaoke mode fill up with color gradually in real-time as the artist sings (running at a buttery-smooth 60+ FPS).
- **Line-by-Line Synced Sweep** — Synced lyrics feature a progressive sweep effect across the text, coloring repeated lines sequentially.
- **Active Line Highlight & Scrolling** — Active line slides slightly to the right and lights up. Scrolling or tapping a line glides smoothly rather than jumping abruptly.
- **Lofi Mode** — Transform any track into a Lofi vibe with slowed speed (0.9×), pitch correction, and native reverb effects.
- **Multi-Language Audio & Quality Control** — Detects and switches between available languages and streams in High, Medium, or Low quality.
- **Background Playback & Native Effects** — Keep music playing with the screen off while utilizing platform-specific audio effects.

### <img src="https://img.icons8.com/fluency/18/lightning-bolt.png" align="absmiddle"/> Smart Cache System
- **Asynchronous Background Caching** — Automatically caches the audio stream of newly added tracks in the background upon adding them to playlists, favorites, or the library.
- **Multi-Resolution Artwork Caching** — Downloads and saves both high-resolution and low-resolution thumbnails locally, ensuring immediate visual feedback without network delay.
- **Instant Zero-Wait Playback** — Bypasses network request times entirely for cached tracks, allowing immediate streaming of local audio streams.
- **Bandwidth-Aware Checks** — Skips download queues if a track has already been cached or downloaded to save battery and network data.

### <img src="https://img.icons8.com/fluency/18/books.png" align="absmiddle"/> Discovery, Import & Community
- **Spotify Playlist Import** — Paste any public Spotify playlist URL to instantly import your favorite tracks.
- **Community Feed & Sharing** — Search, stream, and discover tracks uploaded by the community in a dedicated global feed.
- **Artist Following** — Follow your favorite artists and channels directly from their profile pages to easily keep track of them.
- **Smart Queue & Infinite Playback** — Queue clearing successfully empties upcoming songs in auto-queue mode, and disables the clear button when only the active song is playing.
- **Offline Downloads** — Download songs and videos for offline listening.
- **Recently Played Grid** — Compact 2-column grid of recently played tracks on the home screen.
- **Custom Canvas Video Backgrounds** — Support for custom MP4 canvas video backgrounds with a dedicated uploader dashboard card.

### <img src="https://img.icons8.com/fluency/18/security-shield-green.png" align="absmiddle"/> Privacy & Accounts
- **Optional Accounts & Cloud Sync** — Create an account or sign in with Google to upload your own tracks and view your Apple-style Profile Card.
- **Privacy First** — No login required. All data (favorites, playlists, history) is stored locally by default.
- **Zero-Wait Launch** — Parallel background loading ensures instant app initialization.
- **Ad-Free & Reliable** — Uninterrupted listening with robust RapidAPI and Metadata API Relay fallback (utilizing Hugging Face bucket caching) to guarantee playback.
- **Share to Play** — Share links from YouTube or YouTube Music directly into Muzo.
- **Muzo Deep Linking (`muzo://`)** — Full custom URL scheme support to instantly open/play songs (`muzo://s/<id>`), artists (`muzo://artist/<id>`), albums (`muzo://album/<id>`), and playlists (`muzo://playlist/<id>`) directly via browser links or shared Ytify integration URLs.

---

## <img src="https://img.icons8.com/fluency/20/coffee-to-go.png" align="absmiddle"/> Support & Donations

If you love Muzo and want to support its ongoing development, consider buying me a coffee or donating! Your support keeps the project alive and ad-free.

> [!NOTE]
> All cryptocurrency addresses below accept **USDT** on their respective networks.

### <img src="https://img.icons8.com/fluency/18/qr-code.png" align="absmiddle"/> UPI (India)
- **UPI ID:** `shashwat22817@fam`

### <img src="https://img.icons8.com/fluency/18/bitcoin.png" align="absmiddle"/> Cryptocurrency (USDT)

| Network | USDT Address |
| :--- | :--- |
| **USDT (ERC-20)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **Optimism (OP)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **Arbitrum One (ARETH)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **opBNB** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **BNB Smart Chain (BEP-20)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **Solana (SOL)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **TRON (TRC-20)** | `TRvZLT4F3W2xrKmduc6fQ6RLJM6Jy5ny7w` |
| **Avalanche C-Chain (AVAX)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **Celo** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |
| **Polygon (MATIC)** | `0xAF01BD2867122f46e3cFeC9449068E021C746f25` |

---

## <img src="https://img.icons8.com/fluency/20/globe.png" align="absmiddle"/> Localisation Status

Muzo is fully localised and supports multiple languages. Below is the translation completion status for each supported language:

| Language | Code | Progress | Coverage |
| :--- | :---: | :--- | :---: |
| **English** | `en` | ████████████████████ | 100% |
| **Hindi** | `hi` | ████████████████████ | 100% |
| **Bengali** | `bn` | ████████████████████ | 100% |
| **Arabic** | `ar` | ████████████████████ | 100% |
| **Russian** | `ru` | ████████████████████ | 100% |
| **Spanish** | `es` | ████████████████████ | 100% |
| **French** | `fr` | ████████████████████ | 100% |
| **German** | `de` | ████████████████████ | 100% |
| **Japanese** | `ja` | ████████████████████ | 100% |
| **Kazakh** | `kk` | ████████████████████ | 100% |
| **Telugu** | `te` | ████████████████████ | 100% |
| **Assamese** | `as` | ████████████████████ | 100% |
| **Chinese** | `zh` | ████████████████████ | 100% |
| **Punjabi** | `pa` | ████████████████████ | 100% |
| **Polish** | `pl` | ████████████████████ | 100% |
| **Portuguese**| `pt` | ████████████████████ | 100% |
| **Serbian** | `sr` | ████████████████████ | 100% |
| **Turkish** | `tr` | ████████████████████ | 100% |
| **Urdu** | `ur` | ████████████████████ | 100% |
| **Korean** | `ko` | ████████████████████ | 100% |

---

## <img src="https://img.icons8.com/fluency/20/camera.png" align="absmiddle"/> Screenshots

### <img src="https://img.icons8.com/fluency/18/home.png" align="absmiddle"/> Home & Navigation

<p align="center">
  <img src="images/home.jpg" width="30%" alt="Home Screen" />
  <img src="images/home_with_miniplayer.jpg" width="30%" alt="Home with Mini Player" />
  <img src="images/library.jpg" width="30%" alt="Library" />
</p>

### <img src="https://img.icons8.com/fluency/18/search.png" align="absmiddle"/> Search

<p align="center">
  <img src="images/search_with _results.jpg" width="30%" alt="Search Results" />
  <img src="images/search_with _search_suggestions.jpg" width="30%" alt="Search Suggestions" />
</p>

### <img src="https://img.icons8.com/fluency/18/headphones.png" align="absmiddle"/> Player

<p align="center">
  <img src="images/Immersive_player.jpg" width="30%" alt="Immersive Player" />
  <img src="images/leagcy_player.jpg" width="30%" alt="Legacy Player" />
  <img src="images/song_queue.jpg" width="30%" alt="Song Queue" />
</p>

### <img src="https://img.icons8.com/fluency/18/microphone.png" align="absmiddle"/> Lyrics

<p align="center">
  <img src="images/lyrics_with_controls.jpg" width="30%" alt="Lyrics with Controls" />
  <img src="images/lyrics_without_controls.jpg" width="30%" alt="Lyrics without Controls" />
</p>

### <img src="https://img.icons8.com/fluency/18/conference-call.png" align="absmiddle"/> Community & Profile

<p align="center">
  <img src="images/community.jpg" width="30%" alt="Community Feed" />
  <img src="images/profile_screen.jpg" width="30%" alt="Profile Screen" />
</p>

### <img src="https://img.icons8.com/fluency/18/settings.png" align="absmiddle"/> Settings & Customization

<p align="center">
  <img src="images/settings.jpg" width="30%" alt="Settings" />
  <img src="images/app_theme_selector.jpg" width="30%" alt="Theme Selector" />
  <img src="images/accent_color_selector.jpg" width="30%" alt="Accent Color" />
  <img src="images/custom_accent_color_selector.jpg" width="30%" alt="Custom Accent Color" />
  <img src="images/app_language_selector.jpg" width="30%" alt="Language Selector" />
</p>

### <img src="https://img.icons8.com/fluency/18/information.png" align="absmiddle"/> About

<p align="center">
  <img src="images/about_screen.jpg" width="30%" alt="About Screen" />
</p>

---

## <img src="https://img.icons8.com/fluency/20/maintenance.png" align="absmiddle"/> Tech Stack

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

## <img src="https://img.icons8.com/fluency/20/settings.png" align="absmiddle"/> Setup & Installation

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

## <img src="https://img.icons8.com/fluency/20/handshake.png" align="absmiddle"/> Contributing

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

## <img src="https://img.icons8.com/fluency/20/like.png" align="absmiddle"/> Acknowledgements

Muzo wouldn't exist without the incredible work of these developers and projects. Huge thanks to:

### <img src="https://img.icons8.com/fluency/18/youtube.png" align="absmiddle"/> youtube_explode_dart
A massive thank you to **[Hexer10](https://github.com/Hexer10)**, the original author of [youtube_explode_dart](https://github.com/Hexer10/youtube_explode_dart) — the backbone of Muzo's YouTube streaming and metadata extraction. Also special thanks to **[anandnet](https://github.com/anandnet)** for maintaining an up-to-date fork that keeps Muzo working with the latest YouTube changes.

### <img src="https://img.icons8.com/fluency/18/music.png" align="absmiddle"/> Animesh (n-ce) — fast-saavn & ytify
An enormous shoutout to **[Animesh (n-ce)](https://github.com/n-ce)** — creator of:
- **[fast-saavn](https://github.com/n-ce/saavn)** — the blazing-fast, open JioSaavn API that powers Muzo's music metadata, song details, and search results.
- **[ytify](https://github.com/n-ce/ytify)** — a beautifully minimal YouTube audio streaming web app that was a **huge source of inspiration** during Muzo's development. Animesh's approach to UI, UX, and YouTube audio handling influenced many of Muzo's design decisions. Thank you for the open-source spirit and for being so helpful throughout the development journey!

### <img src="https://img.icons8.com/fluency/18/open-box.png" align="absmiddle"/> Open-Source Libraries
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
| [google_sign_in](https://pub.dev/packages/google_sign_in) | [Flutter Team](https://github.com/flutter/packages) |
| [app_links](https://pub.dev/packages/app_links) | [Julien Eluard](https://github.com/llfbandit) |

---

## <img src="https://img.icons8.com/fluency/20/terms-and-conditions.png" align="absmiddle"/> License

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
