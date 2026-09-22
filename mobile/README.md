# AgroYordam — mobil va web ilova (Flutter)

Bitta Flutter kod bazasi: **Android, iOS va Web**. Arxitektura — Clean Architecture + Riverpod + go_router.

```
lib/
  core/          dizayn tizimi (theme/app_colors.dart — yagona rang manbai), API klient, utils, umumiy widgetlar
  domain/        entity'lar (User, Crop, Diagnosis, Post, ...)
  data/          repository'lar (REST API chaqiruvlari)
  application/   Riverpod provayderlari, AuthController, mavzu (theme mode)
  presentation/  router + ekranlar: auth, home, diagnosis, garden, reminders, community, chat, catalog, profile, premium, admin
```

## Ishga tushirish

```bash
flutter pub get
# Web (backend http://localhost:8000 da)
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
# Android emulyator (backend manzili avtomatik 10.0.2.2:8000)
flutter run -d android
# Release build'lar
flutter build web --release --no-web-resources-cdn
flutter build apk --release --dart-define=API_URL=https://api.sizning-domen.uz
```

Web release nginx orqasida backend bilan bitta domenda ishlaydi (`API_URL` kerak emas).

## Testlar

```bash
flutter analyze
flutter test
```
