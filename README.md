# Torr9 Mobile 🚀

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen?style=for-the-badge)]()

A premium, high-performance mobile client for **Torr9**, built with Flutter. This application provides a seamless experience for managing torrents, interacting with the community via real-time chat, and tracking your sharing statistics with a modern, glassmorphic aesthetic.

## ✨ Key Features

### 💎 Premium UI/UX
- **Modern Dark Theme**: A custom-crafted aesthetic using Slate 900, Indigo, and Emerald accents.
- **Glassmorphism**: Subtle translucency and blur effects for a depth-rich experience.
- **Micro-animations**: Smooth transitions and interactive elements that feel alive.

### 💬 Real-time Communication
- **WebSocket-powered Chat**: Instant messaging across multiple channels.
- **Discord-style Emoji Autocomplete**: Triggered by `:`, featuring a wide range of custom emojis.
- **Smart Notifications**: Visual indicators for unread messages.

### 📁 Torrent Management
- **Advanced Search**: Integrated with TMDB for rich media metadata (posters, descriptions, ratings).
- **Comprehensive Details**: View file lists, comments, and detailed technical specs.
- **One-Click Download**: Seamlessly download `.torrent` files directly to your device.
- **Exclusive Content**: Stay updated with the latest exclusivities and featured releases.

### 📊 User Insights & Customization
- **Detailed Statistics**: Real-time tracking of Ratio, Upload, and Download data.
- **Profile Management**: Customize your avatar, citation, and account settings.
- **Adult Content Toggle**: Flexible content filtering based on user preference.

## 🛠️ Technology Stack

- **Core**: [Flutter](https://flutter.dev/) & [Dart](https://dart.dev/)
- **Networking**: [HTTP](https://pub.dev/packages/http) for API requests, [WebSockets](https://pub.dev/packages/web_socket_channel) for real-time chat.
- **State & Caching**: Custom `CacheService` for persistent local storage and session management.
- **Media**: [Cached Network Image](https://pub.dev/packages/cached_network_image) for optimized visual performance.
- **Storage**: [Path Provider](https://pub.dev/packages/path_provider) for local file system access.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- [Dart SDK](https://dart.dev/get-started/sdk/install)
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/torr9_mobile.git
   cd torr9_mobile
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Launchers & Splash (Optional)**
   ```bash
   flutter pub run flutter_launcher_icons:main
   flutter pub run flutter_native_splash:create
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

## 📂 Project Structure

```text
lib/
├── screens/          # UI Layers (Tabs, Detail Screens, Login)
├── torr9_api.dart    # API Wrapper & Service Layer
├── cache_service.dart # Local Persistence & Auth State
└── main.dart         # App Entry & Theme Configuration
```

## 🛡️ Security & Performance
- Secure JWT-based authentication.
- Optimized image loading and caching to minimize data usage.
- Efficient state management ensuring 60 FPS performance on most devices.

---

*Note: This is a community-driven mobile client. Ensure you adhere to the Torr9 platform rules while using this application.*
