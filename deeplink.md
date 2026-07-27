# Muzo Deep Link Reference

Muzo registers the custom URI scheme **`muzo://`** on Android. Any link in the form `muzo://<path>` opened on a device with Muzo installed will launch the app and navigate directly to the requested content.

---

## Scheme

```
muzo://
```

---

## Endpoints

### 🎵 Play a Song

```
muzo://s/<videoId>
```

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `videoId` | `string` | YouTube video ID of the track |

**Example**
```
muzo://s/dQw4w9WgXcW
```
**Behaviour** — Immediately begins playback of the song with the given video ID.

---

### 👤 Open Artist Profile

```
muzo://artist/<channelId>
```

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `channelId` | `string` | YouTube Music channel / browse ID of the artist |

**Example**
```
muzo://artist/UCkZFKKK-0YB0FvwoS8P7nig
```
**Behaviour** — Opens the full artist screen (bio, top songs, albums, singles).

---

### 💿 Open Album

```
muzo://album/<albumId>
```

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `albumId` | `string` | YouTube Music album browse ID |

**Example**
```
muzo://album/MPREb_0HtvKmMfDR5
```
**Behaviour** — Opens the album detail screen with its full track listing.

---

### 📋 Play a Playlist

```
muzo://playlist/<playlistId>
```

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `playlistId` | `string` | YouTube / YouTube Music playlist ID |

**Example**
```
muzo://playlist/PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI
```
**Behaviour** — Fetches all tracks in the playlist and begins playback from the first track.

---

### 🔍 Open Search

```
muzo://search/<query>
```

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `query` | `string` | URL-encoded search term |

**Example**
```
muzo://search/imagine%20dragons
```
**Behaviour** — Opens the Search screen with the query pre-filled.

> **Note** — Search deep linking is defined in [`YtifyLinks`](lib/utils/ytify_links.dart) but the in-app route handler for it is not yet wired. Song, artist, album, and playlist are fully functional.

---

## Calling from a Browser / Web App

Custom `muzo://` URIs work directly from HTML or JavaScript:

```html
<!-- HTML anchor -->
<a href="muzo://s/dQw4w9WgXcW">Open in Muzo</a>
```

```javascript
// JavaScript redirect
window.location.href = 'muzo://s/dQw4w9WgXcW';
```

> **Ytify integration** — The Ytify web app ([ytify.pp.ua](https://ytify.pp.ua)) uses this to power its **"Open in Muzo"** button. Muzo shares content as `https://ytify.pp.ua/s/<id>` links; Ytify then offers a button that fires the corresponding `muzo://` URI.

---

## Android Setup

The scheme is declared in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml):

```xml
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="muzo" />
</intent-filter>
```

The routing logic lives in [`_handleDeepLink`](lib/widgets/main_layout.dart) inside `MainLayout`.

---

## Implementation Files

| File | Role |
| :--- | :--- |
| [`lib/utils/ytify_links.dart`](lib/utils/ytify_links.dart) | Generates Ytify share URLs for all content types |
| [`lib/widgets/main_layout.dart`](lib/widgets/main_layout.dart) | Initialises `app_links`, receives URIs, routes to screens |
| [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) | Registers `muzo://` intent-filter |
