# 🔐 Keystore Quick Reference

## ⚡ Generate Keystore (DO THIS FIRST!)

```powershell
cd C:\Users\alvin\Desktop\Conflict\project_1\android\app\keystore
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore mysafezone-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mysafezone
```

## ✏️ Update Credentials

Edit `android/keystore.properties`:
```properties
storePassword=YOUR_PASSWORD_HERE
keyPassword=YOUR_PASSWORD_HERE
keyAlias=mysafezone
storeFile=app/keystore/mysafezone-release.jks
```

## 🏗️ Build Commands

```bash
# App Bundle (Recommended)
flutter build appbundle --release

# APK
flutter build apk --release

# Split APKs (Smaller)
flutter build apk --split-per-abi --release
```

## 💾 Backup Checklist

- [ ] Copy `mysafezone-release.jks` to USB drive
- [ ] Upload to cloud storage (encrypted)
- [ ] Save to password manager
- [ ] Document credentials securely
- [ ] Test restore from backup

## 📍 Important Locations

- **Keystore File:** `android/app/keystore/mysafezone-release.jks`
- **Credentials:** `android/keystore.properties`
- **Output APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **Output AAB:** `build/app/outputs/bundle/release/app-release.aab`

## ⚠️ NEVER COMMIT
- `*.jks`
- `keystore.properties`
- `android/app/keystore/` folder

---

For complete details, see [KEYSTORE_SETUP.md](KEYSTORE_SETUP.md)

