# AgroYordam logotipi

- `logo-mark.svg` — **asosiy manba**: belgi (A harfi ichida quyosh va dala egatlari, chapda barglar, o'ngda AI tarmog'i), shaffof fon.
- `app-icon.svg` — ilova belgisi (yumaloq kvadrat, to'q yashil fon); `app-icon-maskable.svg` — Android/PWA maskable (to'liq fon).
- `logo-mark.png` — ilova ichida ishlatiladi (`BrandLogo` vidjeti).

Ranglar: yashil `#A3E553 → #4CB540 → #1B7C36`, quyosh `#FFE684 → #F7B82D`, fon `#1F6E3C → #0A2A17`.
Shior: «Qishloq xo'jaligi uchun aqlli yechim».

Belgini o'zgartirgach, hamma o'lchamlarni qayta yasash (`mobile/` papkasida, Node + Playwright kerak):

```bash
python3 tool/brand/build_svgs.py assets/brand          # app-icon*.svg ni logo-mark.svg dan yig'adi
R=android/app/src/main/res
node tool/brand/render.js '[["assets/brand/app-icon.svg","'$R'/mipmap-mdpi/ic_launcher.png",48],
 ["assets/brand/app-icon.svg","'$R'/mipmap-hdpi/ic_launcher.png",72],["assets/brand/app-icon.svg","'$R'/mipmap-xhdpi/ic_launcher.png",96],
 ["assets/brand/app-icon.svg","'$R'/mipmap-xxhdpi/ic_launcher.png",144],["assets/brand/app-icon.svg","'$R'/mipmap-xxxhdpi/ic_launcher.png",192],
 ["assets/brand/app-icon.svg","web/icons/Icon-192.png",192],["assets/brand/app-icon.svg","web/icons/Icon-512.png",512],
 ["assets/brand/app-icon-maskable.svg","web/icons/Icon-maskable-192.png",192],["assets/brand/app-icon-maskable.svg","web/icons/Icon-maskable-512.png",512],
 ["assets/brand/app-icon.svg","web/favicon.png",64],["assets/brand/logo-mark.svg","assets/brand/logo-mark.png",512]]'
cp assets/brand/logo-mark.svg web/admin/logo.svg
```
