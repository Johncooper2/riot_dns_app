# Riot DNS Changer v3.0
## اپ موبایل Flutter — DNS Scanner + VPN Changer

---

## ساختار پروژه

```
riot_dns_app/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/riotdns/app/
│       │   ├── MainActivity.java       ← Flutter ↔ Android bridge
│       │   ├── RiotVpnService.java     ← VPN DNS proxy (بدون root)
│       │   └── BootReceiver.java       ← Auto-start on boot
│       └── res/xml/
│           └── network_security_config.xml
├── lib/
│   ├── main.dart                       ← Entry point
│   ├── theme.dart                      ← Dark gaming theme
│   ├── models/
│   │   ├── dns_server.dart             ← DNS data + 38 سرور
│   │   └── game_server.dart            ← Riot servers + 17 سرور
│   ├── services/
│   │   ├── dns_scanner.dart            ← تست DoU / DoT / DoH
│   │   └── vpn_service.dart            ← MethodChannel bridge
│   ├── widgets/
│   │   └── common.dart                 ← LatencyBadge, DnsCard, ...
│   └── screens/
│       ├── home_screen.dart            ← VPN power button
│       ├── dns_screen.dart             ← اسکن و انتخاب DNS
│       ├── game_screen.dart            ← تست سرور LoL / Wild Rift
│       └── settings_screen.dart        ← تنظیمات
└── pubspec.yaml
```

---

## مراحل Build

### ۱. نصب Flutter
```bash
# دانلود از flutter.dev
# اضافه کردن به PATH

flutter doctor   # باید همه چک‌ها سبز بشن
```

### ۲. نصب Android SDK
- **Android Studio** رو نصب کن (فقط برای SDK، نه برای کدنویسی)
- یا از command line:
```bash
# دانلود command line tools از developer.android.com/studio
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### ۳. Clone/Copy پروژه
```bash
# این پوشه رو جایی بذار
cd riot_dns_app
flutter pub get
```

### ۴. Build APK
```bash
# Debug APK (برای تست سریع)
flutter build apk --debug

# Release APK (بهینه، سبک‌تر)
flutter build apk --release

# Split APK per ABI (کوچک‌تر)
flutter build apk --split-per-abi --release
```

### ۵. نصب روی گوشی
```bash
# گوشی رو با USB وصل کن + USB Debugging فعال
flutter install

# یا مستقیم کپی APK:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## قابلیت‌های اپ

### 🏠 خانه
- دکمه Power برای روشن/خاموش VPN
- نمایش DNS فعال و پروتکل
- آمار سرورها

### 🌐 DNS
- اسکن همزمان همه DNS سرورها
- نمایش latency، jitter، loss
- تشخیص پروتکل: DoU + DoT + DoH
- فیلتر بر اساس دسته و پروتکل
- راهنمای تنظیم اندروید (swipe چپ)
- فعال‌سازی با یک دکمه

### 🎮 بازی
- تست ping به سرورهای LoL و Wild Rift
- نمودار latency
- رتبه‌بندی بهترین سرور

### ⚙️ تنظیمات
- شروع خودکار بعد از ری‌استارت
- DNS دستی
- راهنمای پروتکل‌ها

---

## نحوه کار VPN

```
گوشی ─── DNS query ──→ tun0 (VPN interface)
                          ↓
                   RiotVpnService.java
                          ↓
                   PRIMARY_DNS:53
                          ↓
                   جواب برمی‌گرده
```

- **بدون root** — از Android VpnService API استفاده می‌کنه
- **اندروید ≥ 5** (API 21)
- فقط ترافیک DNS (UDP port 53) رو intercept می‌کنه
- Secondary DNS به عنوان fallback

---

## پروتکل‌ها در اندروید

| پروتکل | پورت | رمزنگاری | روش اندروید |
|--------|------|----------|-------------|
| DoU    | 53   | ❌        | IP استاتیک Wi-Fi |
| DoT    | 853  | ✅ TLS    | Private DNS (اندروید ≥ 9) |
| DoH    | 443  | ✅ HTTPS  | اپ AdGuard / Intra |
