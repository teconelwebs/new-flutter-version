# Welfog Flutter App (NEW)

Main Flutter app with clean feature-based structure. Play/Reels lives in a separate local package.

## Folder structure

```
Welfog-NEW/
├── lib/
│   ├── main.dart                 # App entry
│   ├── app.dart                  # MaterialApp setup
│   ├── core/
│   │   ├── constants/            # Route names, app constants
│   │   ├── router/               # Main app routing
│   │   └── theme/                # App theme
│   └── features/
│       ├── splash/
│       ├── login/
│       ├── address/
│       ├── home/
│       ├── search/
│       ├── cart/
│       └── product/
└── flutter_play_module/          # Play/Reels only (copied from old project)
```

## Run

1. Install Flutter SDK and add to PATH
2. From this folder:

```bash
flutter create . --project-name welfog --org com.welfog
flutter pub get
flutter run
```

> `flutter create .` adds `android/` and `ios/` folders. Run it once if they are missing.

## Play module

Play screens are imported from `flutter_play_module` via path dependency:

```yaml
welfog_flutter_play:
  path: ./flutter_play_module
```

Do not put home/cart/login code inside `flutter_play_module`.

## Android package (Play Store)

When generating native projects, use:

- Package: `com.welfog.app`
- versionCode: `64` or higher (see `pubspec.yaml`)
