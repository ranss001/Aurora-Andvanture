# Aurora Adventure Online (Godot 4.4.1)

Prototype game 3D adventure online multiplayer untuk Android.

## Fitur
- Dunia 3D sederhana dengan pepohonan dan landmark.
- Host / Join multiplayer menggunakan ENet UDP port `2456`.
- Maksimal 12 pemain (prototype).
- Gerak WASD, lompat, drag layar untuk kamera, tombol sentuh dasar.
- Build APK Debug otomatis melalui GitHub Actions.

## Build APK di GitHub
1. Buat repository GitHub baru.
2. Upload seluruh isi folder project ini ke branch `main` (jangan upload folder pembungkus `aurora_adventure`).
3. Buka tab **Actions** dan jalankan workflow **Build Android Debug APK**, atau push commit ke `main`.
4. Setelah selesai, buka workflow run dan unduh artifact `aurora-adventure-debug`.

Workflow menggunakan image `barichello/godot-ci:4.4.1` yang menyediakan Godot dan toolchain Android. Jika preset ekspor Android meminta konfigurasi tambahan, buka Godot Editor > Project > Export, pasang Android build template/export setup sesuai dokumentasi Godot, lalu commit perubahan `export_presets.cfg`.

## Multiplayer
- Semua pemain harus memakai versi game yang sama.
- Host menjalankan **Host World**. Teman memilih **Join World**, lalu memasukkan IP publik host.
- Izinkan / port-forward **UDP 2456** pada router/firewall host.
- Untuk tes di satu Wi-Fi, gunakan IP lokal host. `127.0.0.1` hanya mengarah ke perangkat itu sendiri.
- Untuk server internet yang selalu aktif, jalankan host pada VPS. Jangan bagikan IP publik jika tidak ingin orang lain masuk.

## Catatan prototype
Ini fondasi game, belum game komersial siap rilis. Sistem akun, matchmaking, keamanan server-authoritative, quest/inventory, animasi karakter, joystick analog, dan optimasi jaringan masih perlu dikembangkan. Jangan gunakan server publik tanpa validasi server dan perlindungan anti-cheat.
