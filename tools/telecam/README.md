# TeleCam — камера для визуальной самопроверки

Маленькое macOS-приложение: захватывает кадр встроенной камеры каждые 2 секунды и пишет JPEG.
Нужно, чтобы ИИ-агент сам видел экран телевизора (Tizen 2.4 не отдаёт скриншоты по сети).

## Сборка

```bash
mkdir -p TeleCam.app/Contents/MacOS
cat > TeleCam.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TeleCam</string>
    <key>CFBundleIdentifier</key><string>local.aitv.telecam</string>
    <key>CFBundleName</key><string>TeleCam</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSCameraUsageDescription</key><string>Показ экрана телевизора агенту для проверки шагов настройки.</string>
</dict>
</plist>
PLIST
swiftc -O telecam.swift -o TeleCam.app/Contents/MacOS/TeleCam \
  -framework AVFoundation -framework AppKit -framework CoreImage -framework Foundation
codesign --force --deep --sign - TeleCam.app
open TeleCam.app      # macOS спросит доступ к камере — разрешить
```

Остановка: `pkill -f TeleCam`. Кадры пишутся в `$TELECAM_DIR` (по умолчанию `./snapshots`).
