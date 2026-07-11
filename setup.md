# Welfog-NEW Android Setup Commands

## 1) Project folder open
```powershell
cd C:\xampp\htdocs\welfog-app\Welfog-NEW
```

## 2) USB device check
```powershell
C:\platform-tools\adb.exe devices
```
Expected: device id ke samne `device` likha ho.

If `offline` aaye:
```powershell
C:\platform-tools\adb.exe kill-server
C:\platform-tools\adb.exe start-server
C:\platform-tools\adb.exe devices
```

## 3) Dependencies install (first time / after pubspec change)
```powershell
C:\src\flutter\bin\flutter.bat pub get
```

## 4) Fresh install + run on phone (debug)
Ye app build karega, phone me install karega, aur run karega:
```powershell
C:\src\flutter\bin\flutter.bat run -d I7IV5X5DNV5HHULR
```

## 5) Real-time update while app running (same terminal)
`flutter run` chal raha ho tab:
- `r` = Hot Reload (UI/code quick update)
- `R` = Hot Restart (state reset ke saath restart)
- `q` = Quit run session
- `d` = Detach (app phone me chalti rahegi)

## 6) Update install command (APK rebuild + reinstall)
Manual update test ke liye:
```powershell
C:\src\flutter\bin\flutter.bat build apk --debug
C:\platform-tools\adb.exe -s I7IV5X5DNV5HHULR install -r .\build\app\outputs\flutter-apk\app-debug.apk
```
`-r` ka matlab existing app ko replace/update karna.

## 7) Completely fresh reinstall (old app remove + new install)
```powershell
C:\platform-tools\adb.exe -s I7IV5X5DNV5HHULR uninstall com.welfog.app
C:\src\flutter\bin\flutter.bat run -d I7IV5X5DNV5HHULR
```

## 8) If multiple devices connected
Pehle ids dekho:
```powershell
C:\src\flutter\bin\flutter.bat devices
```
Phir target id ke saath run:
```powershell
C:\src\flutter\bin\flutter.bat run -d <DEVICE_ID>
```

C:\src\flutter\bin\flutter.bat run
