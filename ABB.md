# Welfog Flutter — AAB (Play Store) Build

## 1) Project folder
```powershell
cd C:\xampp\htdocs\welfog-app\new-flutter-version
```

## 2) Dependencies (first time / after pubspec change)
```powershell
C:\src\flutter\bin\flutter.bat pub get
```

## 3) Release AAB banane ki command
```powershell
C:\src\flutter\bin\flutter.bat build appbundle --release
```

## 4) Output file path
Build ke baad AAB yahan milegi:

```
C:\xampp\htdocs\welfog-app\new-flutter-version\build\app\outputs\bundle\release\app-release.aab
```

Yahi file Google Play Console pe upload karni hai.

Success example:
```
√ Built build\app\outputs\bundle\release\app-release.aab (74.9MB)
```

Agar purana error aaye (`failed to strip debug symbols`):
- Android `cmdline-tools` install hona chahiye
- `android/app/build.gradle.kts` mein release `ndk { debugSymbolLevel = "SYMBOL_TABLE" }` set hai

## 5) Version check (upload se pehle)
`pubspec.yaml` mein version badhao (Play Store pe `versionCode` hamesha pehle se bada hona chahiye):

```yaml
version: 1.1.29+64
```

- `1.1.29` = versionName (user ko dikhta hai)
- `64` = versionCode (Play Store internal; har upload pe +1)

Example next upload:
```yaml
version: 1.1.30+65
```

## 6) Signing (already set)
Release AAB `android/key.properties` + `upload-keystore.jks` se sign hoti hai.

Details: `keystore_info.txt`

## 7) Optional — clean build (agar error aaye)
```powershell
C:\src\flutter\bin\flutter.bat clean
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat build appbundle --release
```

## 8) Optional — APK bhi chahiye ho to (testing)
```powershell
C:\src\flutter\bin\flutter.bat build apk --release
```

APK path:
```
C:\xampp\htdocs\welfog-app\new-flutter-version\build\app\outputs\flutter-apk\app-release.apk
```

Play Store ke liye **AAB** use karo, APK nahi.
