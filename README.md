# Mview

Mview is a Flutter-based application designed for cross-platform compatibility, supporting Android, iOS, macOS, Windows, and web platforms.

---

## Table of Contents

1. [Features](#features)
2. [Requirements](#requirements)
3. [Setup Instructions](#setup-instructions)
4. [Running the Project](#running-the-project)
5. [Folder Structure](#folder-structure)

---

## Features

- Cross-platform support: Android, iOS, macOS, Windows, and web.
- Bluetooth integration using `flutter_blue_plus_windows`.
- Customizable UI with assets and themes.
- Modular architecture for scalability.

---

## Requirements

Before setting up the project, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.4.3 or higher)
- Dart SDK (comes with Flutter)
- Android Studio (for Android development)
- Xcode (for iOS/macOS development)
- Visual Studio (for Windows development)
- A device or emulator for testing
- Node.js (optional, for web development)

---

## Setup Instructions

1. **Clone the Repository**:
   git clone <repository-url>
   cd Mview

2. **Install Dependencies**: Run the following command to fetch all required packages:
`flutter pub get`

3. **Set Up Platforms**:

Android: Open the android folder in Android Studio and ensure the SDK is configured.
iOS/macOS: Open the ios/Runner.xcworkspace or macos/Runner.xcworkspace in Xcode and configure signing.
Windows: Open the windows folder in Visual Studio and ensure the required dependencies are installed.
Web: Ensure you have the latest version of Chrome or Edge installed.


## Running the Project

Run on Android:
`flutter run -d android`

Run on iOS:
`flutter run -d ios`

Run on macOS:
`flutter run -d macos`

Run on Windows:
`flutter run -d windows`

Run on Web:
`flutter run -d web`


**Build for Release:**

Android: `flutter build apk`

iOS: `flutter build ios`

macOS: `flutter build macos`

Windows: `flutter build windows`

Web: `flutter build web`


## Folder Structure
```
Mview/
├── android/          # Android-specific files
├── ios/              # iOS-specific files
├── macos/            # macOS-specific files
├── windows/          # Windows-specific files
├── lib/              # Main Flutter codebase
├── assets/           # Images, fonts, and other assets
├── test/             # Unit and widget tests
├── pubspec.yaml      # Flutter dependencies and configurations
└── README.md         # Project documentation
```