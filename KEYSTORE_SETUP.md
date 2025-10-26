# 🔐 Keystore Setup & Management Guide

## MySafeZone App Signing Configuration

This document contains critical information about your app's signing configuration. **READ THIS CAREFULLY!**

---

## ⚠️ CRITICAL WARNINGS

1. **NEVER commit your keystore or keystore.properties to version control**
   - These files are already added to `.gitignore`
   - Verify before every commit

2. **Losing your keystore means losing access to your app**
   - You cannot update your app on AGC Connect without the original keystore
   - You would need to publish as a completely new app
   - All existing users would need to uninstall and reinstall

3. **Keep multiple secure backups**
   - Store in different physical locations
   - Use encrypted storage (e.g., encrypted USB drives, password managers)
   - Consider cloud storage with encryption (Google Drive with encryption, 1Password, LastPass, etc.)

---

## 📋 Setup Checklist

### ✅ Step 1: Generate Your Keystore (MANUAL STEP REQUIRED)

**You need to run this command in PowerShell or Command Prompt:**

\`\`\`powershell
# Navigate to the keystore directory
cd C:\Users\alvin\Desktop\Conflict\project_1\android\app\keystore

# Generate the keystore
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore mysafezone-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mysafezone
\`\`\`

**When prompted, provide:**

| Prompt | Example Value | Notes |
|--------|---------------|-------|
| Keystore password | `YourSecurePassword123!` | **MINIMUM 6 characters** - Write this down! |
| Re-enter password | `YourSecurePassword123!` | Must match |
| First and last name | `MySafeZone Team` or Your Name | Can be your name or company |
| Organizational unit | `Development` | Your department/team |
| Organization | `meowResQ` | Your company name |
| City or Locality | `Manila` | Your city |
| State or Province | `Metro Manila` | Your state/province |
| Country Code | `PH` | **2-letter code** (US, UK, PH, etc.) |
| Is this correct? | `yes` | Type "yes" to confirm |
| Key password | Press `Enter` | Uses same password as keystore |

**Important Notes:**
- The keystore will be valid for ~27 years (10,000 days)
- Use a **strong password** that you can remember
- **Never use spaces** in the password to avoid command-line issues

---

### ✅ Step 2: Update keystore.properties

After generating your keystore, edit `android/keystore.properties`:

\`\`\`properties
storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
keyPassword=YOUR_ACTUAL_KEY_PASSWORD
keyAlias=mysafezone
storeFile=app/keystore/mysafezone-release.jks
\`\`\`

**Replace:**
- `YOUR_ACTUAL_KEYSTORE_PASSWORD` with your keystore password
- `YOUR_ACTUAL_KEY_PASSWORD` with your key password (usually same as keystore password)

**Example:**
\`\`\`properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=mysafezone
storeFile=app/keystore/mysafezone-release.jks
\`\`\`

---

### ✅ Step 3: Verify Configuration

Run a test build to ensure everything is configured correctly:

\`\`\`bash
# Build release APK
flutter build apk --release

# Or build App Bundle (recommended for AGC)
flutter build appbundle --release
\`\`\`

If successful, you'll see:
- `Built build/app/outputs/flutter-apk/app-release.apk` (for APK)
- `Built build/app/outputs/bundle/release/app-release.aab` (for App Bundle)

---

## 🔒 Keystore Backup Strategy

### Immediate Backups (Do This NOW!)

1. **Copy keystore file to multiple locations:**
   \`\`\`
   Source: C:\Users\alvin\Desktop\Conflict\project_1\android\app\keystore\mysafezone-release.jks
   \`\`\`

   **Backup locations:**
   - External USB drive (encrypted)
   - Cloud storage (Google Drive, Dropbox) in encrypted folder
   - Password manager (1Password, LastPass) as secure document
   - Another computer/laptop
   - Email to yourself (but encrypt it first!)

2. **Save credentials securely:**
   
   Create a text file with this information and store it with the keystore:
   
   \`\`\`
   MySafeZone App Keystore Credentials
   ===================================
   Keystore Password: [your password]
   Key Password: [your password]
   Key Alias: mysafezone
   Package Name: com.meowResQ.mysafezone
   Generated: [date]
   
   Keystore Details:
   - First/Last Name: [what you entered]
   - Organization Unit: [what you entered]
   - Organization: meowResQ
   - City: [your city]
   - State: [your state]
   - Country: [your country code]
   \`\`\`

### Recommended Backup Tools

- **1Password / LastPass**: Store keystore as secure document + credentials
- **Bitwarden**: Free and secure password manager
- **Google Drive**: Upload encrypted zip file
- **External HDD**: Keep offline encrypted backup
- **Company Server**: If working in a team

---

## 📦 Building Release APK/AAB

### For AGC Connect (App Gallery)

**App Bundle (Recommended):**
\`\`\`bash
flutter build appbundle --release
\`\`\`
Output: `build/app/outputs/bundle/release/app-release.aab`

**APK:**
\`\`\`bash
flutter build apk --release
\`\`\`
Output: `build/app/outputs/flutter-apk/app-release.apk`

**Split APKs (smaller downloads):**
\`\`\`bash
flutter build apk --split-per-abi --release
\`\`\`
Outputs:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)

---

## 🔍 Verify APK Signature

To verify your APK is properly signed:

\`\`\`powershell
# Using Android Studio's apksigner
& "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
\`\`\`

You should see:
- `jar verified.`
- Certificate details matching your keystore

---

## 🛠️ What We've Configured

### Files Created/Modified:

1. **`android/keystore.properties`** ✅
   - Stores signing credentials (NOT in git)
   - Must be filled with your actual passwords

2. **`android/app/build.gradle.kts`** ✅
   - Loads keystore.properties
   - Configures signingConfigs for release
   - Enables ProGuard/R8 for code obfuscation
   - Optimizes release builds

3. **`android/app/proguard-rules.pro`** ✅
   - ProGuard rules for code obfuscation
   - Protects Flutter and Huawei HMS code
   - Removes debug logging in release

4. **`.gitignore`** ✅
   - Prevents committing keystore files
   - Protects keystore.properties

5. **`android/app/keystore/`** ✅
   - Directory for your keystore file
   - **You need to generate mysafezone-release.jks here**

---

## 🚨 Troubleshooting

### "keystore not found" error
- Ensure you've generated the keystore using the command above
- Verify the file exists: `android/app/keystore/mysafezone-release.jks`
- Check that `keystore.properties` has correct path

### "keystore password was incorrect"
- Double-check your password in `keystore.properties`
- Ensure no extra spaces or quotes around the password
- Try generating a new keystore if forgotten

### Build fails with ProGuard errors
- Check `android/app/proguard-rules.pro`
- Add specific keep rules for any libraries causing issues
- Temporarily disable ProGuard by setting `isMinifyEnabled = false`

### "Execution failed for task ':app:lintVitalRelease'"
- This is a lint warning check
- Fix any critical lint errors, or
- Add to `android/app/build.gradle.kts`:
  \`\`\`kotlin
  lintOptions {
      checkReleaseBuilds false
      abortOnError false
  }
  \`\`\`

---

## 📝 Team Collaboration

If working with a team:

1. **DO NOT** share keystore via Git/GitHub
2. **DO** share securely via:
   - Encrypted email
   - Secure file sharing (e.g., Dropbox with password)
   - Team password manager (1Password Teams, LastPass Enterprise)
   - In-person USB transfer

3. **Each developer needs:**
   - Copy of `mysafezone-release.jks`
   - Copy of `keystore.properties` with actual passwords
   - Both files in correct locations

---

## ✅ Final Verification Checklist

Before publishing to AGC Connect:

- [ ] Keystore generated successfully (`mysafezone-release.jks` exists)
- [ ] `keystore.properties` filled with actual passwords
- [ ] Keystore backed up to at least 3 different locations
- [ ] Credentials saved securely (password manager, encrypted document)
- [ ] Test release build completes without errors
- [ ] APK/AAB file installs and runs on test device
- [ ] ProGuard optimization working (app size reduced)
- [ ] All sensitive files in `.gitignore`
- [ ] No keystore files committed to git (run `git status` to verify)

---

## 📞 Support

If you encounter issues:

1. Verify all steps in this document
2. Check Flutter/Android documentation
3. Review AGC Connect documentation
4. Reach out to the development team

---

## 🔗 Useful Resources

- [Android App Signing Docs](https://developer.android.com/studio/publish/app-signing)
- [Flutter Build & Release](https://docs.flutter.dev/deployment/android)
- [AGC Connect Publishing](https://developer.huawei.com/consumer/en/doc/distribution/app/agc-release_app)
- [ProGuard Configuration](https://developer.android.com/studio/build/shrink-code)

---

**Generated:** 2025-10-26  
**App:** MySafeZone  
**Package:** com.meowResQ.mysafezone  
**Developer:** meowResQ

