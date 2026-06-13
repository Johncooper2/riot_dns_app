# Riot DNS Changer v3.1.0

VPN-based DNS Changer for Android — بدون نیاز به root

---

## 🎯 ویژگی‌ها

- **VPN-based DNS Changer** — بدون root، اندروید ≥ 5
- **پشتیبانی از DoT / DoH / DoU** — انتخاب بهترین پروتکل برای حریم خصوصی
- **اسکن latency سرورهای Riot Games** — League of Legends + Wild Rift (17 سرور)
- **34 DNS سرور** — ایران، بین‌المللی، گیمینگ، امنیتی، آسیا
- **راهنمای تنظیم اندروید** — تنظیم Private DNS با چند تاپ
- **Secondary DNS** — fallback در صورت قطع اتصال
- **شروع خودکار بعد از ری‌استارت**

---

## 🔧 تغییرات v3.1.0

### Bug Fixes
- **VPN loop bug** — بسته‌های غیر-DNS الان از طریق protected socket فوروارد می‌شن (دیگه ترافیک قطع نمیشه)
- **SharedPreferences mismatch** — BootReceiver الان فایل درست `FlutterSharedPreferences` رو می‌خونه (auto-start واقعاً کار می‌کنه)
- **DoH URL fix** — از hostname استفاده می‌کنه بجای IP (خطای TLS certificate رفع شد)
- **DNS qtype encoding** — رکوردهای غیر-A درست کار می‌کنن
- **DoT TLS version** — نسخه واقعی TLS برمی‌گردونه بجای hardcoded

### Features
- **Secondary DNS** — با long-press روی هر سرور انتخاب کنید
- **DNS ذخیره واقعی** — دکمه ذخیره در settings واقعاً کار می‌کنه
- **Batch scanning** — اسکن 5 تا یکبار بجای همه همزمان (پرفورمنس بهتر)
- **Android 13+** — POST_NOTIFICATIONS permission اضافه شد
- **Android 14+** — FOREGROUND_SERVICE_SPECIAL_USE type اضافه شد

### Improvements
- حذف Kotlin plugin اضافی
- استفاده از `AppTheme.dark` بجای تعریف تکراری theme
- BootReceiver برای Android 8+ از `startForegroundService` استفاده می‌کنه

---

## 📦 Build

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📱 نحوه استفاده

1. نصب اپ
2. انتخاب DNS سرور از تب DNS
3. زدن دکمه Power در صفحه اصلی
4. قبول کردن درخواست VPN
5. تمام! همه اپ‌ها از DNS جدید استفاده می‌کنن

---

## 🔒 امنیت

- بدون root نیاز
- بدون ذخیره لاگ کاربر
- بدون ارسال اطلاعات به سرور خارجی
- DNS query‌ها فقط به سرور انتخابی فوروارد می‌شن
