<div align="center">

<img src="assets/logo 1.webp" alt="Muzo Logo" width="140" height="140" />

# Muzo

**A powerful, aesthetic, privacy-focused streaming music client built with Jetpack Compose.**  
Offline Downloads · Synced Karaoke Lyrics · Liquid Glass UI · Smart Cache · Hi-Res Audio

[![Get it on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo)

[![Kotlin](https://img.shields.io/badge/Kotlin-2.0+-7F52FF?style=flat&logo=kotlin&logoColor=white)](https://kotlinlang.org/)
[![Jetpack Compose](https://img.shields.io/badge/Jetpack_Compose-Material_3-4285F4?style=flat&logo=android&logoColor=white)](https://developer.android.com/jetpack/compose)
[![Media3](https://img.shields.io/badge/Media3-ExoPlayer-00C853?style=flat&logo=google&logoColor=white)](https://developer.android.com/media/media3)
[![Platform](https://img.shields.io/badge/Platform-Android_8.0%2B-blue?style=flat&logo=android&logoColor=white)](https://android.com)
[![Version](https://img.shields.io/badge/Version-6.5.2-blueviolet?style=flat)](https://github.com/myself-tsuki/muzu-new)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

</div>

<br/>

<div align="center">

## 📢 Important Notice

### **Muzo is now closed-source. All latest updates ship exclusively on Google Play.**
### **The Flutter version of Muzo will soon be open-sourced here on GitHub!**

| | |
|:---:|:---:|
| 🔒 **Current App is Closed-Source** | 📲 **Active Updates on Google Play** |
| 💙 **Flutter Version Coming Soon** | 🌐 **Will be Open-Sourced on GitHub** |

### 👉 [**Download the Latest Build on Google Play**](https://play.google.com/store/apps/details?id=com.Shashwat.Muzo) 👈

> **Note:** While current production development is closed-source, the complete **Flutter edition** of Muzo will be open-sourced publicly on GitHub soon for the community.

</div>

---

Muzo is a modern, high-performance Android music streaming application that blends fluid liquid glassmorphism, dynamic artwork tinting, and cutting-edge audio engine technology into an unparalleled listening experience — with or without an account.

---

## ✨ Key Features

### 🎨 Liquid Glass UI/UX
- **Dynamic Glassmorphic Themes** — Translucent liquid glass panels, dynamic specular highlights, and real-time backdrop blur.
- **Dynamic Artwork Adaptation** — Status bars, player controls, progress sliders, and background gradients adapt automatically to the album art colors for perfect visual harmony.
- **5 Bespoke Player Styles** — Seamlessly switch between Default, Immersive, BitChord, Minimal, and Ytify themes to fit your visual mood.
- **Tablet & Foldable Optimization** — Fully responsive layouts with adaptive column arrangements, dual-pane tablet views, and compact landscape controls.

### 🎧 Immersive Audio & Synced Lyrics
- **Word-by-Word Karaoke & Synced Lyrics** — Real-time lyrics tracking with smooth coloring as the artist sings, powered by multi-source aggregation (LRCLIB, KuGou, and YouTube Timed Lyrics).
- **Lo-Fi Mode** — Instantly transform any song into a relaxed Lo-Fi vibe with slowed speed (0.9×), pitch correction, and native reverb.
- **Lossless & Spatial Audio Support** — High-resolution audio pipeline with Dolby Atmos detection and preference toggles.
- **Equalizer & Native DSP Effects** — Built-in parametric equalizer, audio normalization, bass boost, and pitch adjustments.
- **Gapless Playback & Background Service** — Non-stop background music playback with persistent media controls and lock screen art via AndroidX Media3 ExoPlayer.

### ⚡ Smart Cache System
- **Intelligent Background Caching** — Automatically caches played songs, favorites, and playlists to minimize mobile data and battery consumption.
- **Multi-Resolution Artwork Cache** — Caches high- and low-resolution thumbnails locally for instantaneous visual rendering without flicker.
- **Zero-Wait Playback** — Bypasses network request latency completely for pre-cached tracks.
- **Offline Downloads** — Download songs and canvas media directly to your device for offline listening anytime, anywhere.

### 📚 Discovery, Import & Personalization
- **Spotify Playlist Import** — Paste any public Spotify playlist URL to instantly import your favorite tracks.
- **Looping Video Backgrounds** — Seamless integration with Spotify Canvas MP4 looping visuals and animated album artwork.
- **Smart Queue & Infinite Playback** — Dynamic queue management with auto-radio recommendations and seamless queue clearing.
- **Artist Following & Discovery** — Follow your favorite artists, explore curated mood mixes, new releases, and trending charts.

### 🔒 Privacy & Cloud Sync
- **Privacy First** — No account required to enjoy all core playback, search, and library features; data stays securely on your device.
- **Optional Cloud Sync** — Sign in with Google or MUZO account to synchronize your library, playlists, and favorites across devices.
- **Deep Linking (`muzo://`)** — Full custom URL scheme to open and share songs, albums, artists, and playlists seamlessly.

---

## 🛠️ Architecture & Tech Stack

| Layer | Technology |
|---|---|
| **Language** | [Kotlin 2.0+](https://kotlinlang.org/) |
| **UI Framework** | [Jetpack Compose](https://developer.android.com/jetpack/compose) (Material Design 3 + Custom Glass Surfaces) |
| **Audio Engine** | [AndroidX Media3 (ExoPlayer)](https://developer.android.com/media/media3) |
| **Networking** | [OkHttp](https://square.github.io/okhttp/) & [Ktor](https://ktor.io/) |
| **Image Loading** | [Coil 3](https://coil-kt.github.io/coil/) with custom hardware blurs & palette extraction |
| **State Management** | Kotlin Coroutines, `StateFlow`, and `SharedFlow` |
| **Local Storage** | Jetpack DataStore & Encrypted SharedPreferences |
| **Lyrics & Metadata** | LRCLIB, KuGou, and YouTube InnerTube |

---

## ⚙️ Building from Source

### Prerequisites
- Android Studio Ladybug (2024.2+) or newer
- JDK 17 or higher
- Android SDK with API 34+

```bash
# Clone the repository
git clone https://github.com/myself-tsuki/muzu-new.git
cd muzu-new

# Build Debug APK
./gradlew assembleDebug

# Build Release APK
./gradlew assembleRelease
```

---

## ☕ Support & Donations

If you love Muzo and want to support its ongoing development, consider donating — your support keeps the project alive!

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

## 🙏 Acknowledgements

- **ArchiveTune**: For inspiration in architectural structure and refined player elements.
- **LRCLIB**: For high-quality, synchronized lyrics.
- **InnerTube**: For reliable streaming and catalog metadata resolution.

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more details.

---

<div align="center">

Built with ❤️ by **Shashwat**

</div>
