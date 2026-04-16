# Drift DB Inspector

A small desktop app for **Mac** that helps you **open and browse SQLite database files** from an Android app while your phone is plugged in.

You pick your device, type the app’s package name, and pull a copy of the database to your computer. Then you can look at tables, pages of rows, and search—like a simple database viewer.

## Who is this for?

People who use [Drift](https://pub.dev/packages/drift) (or plain SQLite) on Android and want to **inspect data** without digging through files on the device by hand.

## Before you run it

- **macOS** — this project only supports Mac (not Windows or Linux in this repo).
- **Flutter** — [install Flutter](https://docs.flutter.dev/get-started/install) and check it works (`flutter doctor`).
- **Android phone or emulator** with **USB debugging** on, and a **USB cable** (or a working emulator setup).
- **ADB** on your Mac — usually comes with Android Studio, or install “Platform Tools” from Google. The app runs `adb` commands for you; you should be able to run `adb devices` in a terminal and see your device.
- Your Android app must be **debuggable** (normal for debug builds). You need the **application id** (package name), e.g. `com.example.myapp`.

## Run the app

From this folder:

```bash
flutter pub get
flutter run -d macos
```

To build a release app:

```bash
flutter build macos
```

If something fails, run `flutter doctor` and fix what it says (especially the macOS / Xcode parts).

## Note

This tool copies database files to your Mac for **read-only** viewing. It does not change data on the phone by itself.
