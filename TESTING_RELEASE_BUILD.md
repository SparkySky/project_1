# 🧪 Testing Release Build Guide

## MySafeZone Release Testing

---

## 📦 AFTER BUILD COMPLETES

Once you see:
```
✓ Built build/app/outputs/bundle/release/app-release.aab (XX MB)
```

You're ready to test!

---

## 🎯 TESTING OPTIONS

### Option 1: Install Directly (Recommended for Quick Testing)

**Using Flutter CLI:**
```bash
# Install the release build on connected device
flutter install --release
```

**This will:**
- Build and install the release APK automatically
- Use your release signing configuration
- Install on any connected Android device

**Requirements:**
- Device connected via USB with USB debugging enabled
- Device drivers installed

---

### Option 2: Install APK Manually

**Step 1: Build Release APK**
```bash
flutter build apk --release
```

**Output location:**
```
build/app/outputs/flutter-apk/app-release.apk
```

**Step 2: Transfer to Device**

**Method A: USB Cable**
```bash
# Install via ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Or if multiple devices
adb devices  # List devices
adb -s DEVICE_ID install build/app/outputs/flutter-apk/app-release.apk
```

**Method B: File Transfer**
1. Copy `app-release.apk` to your phone (USB, Bluetooth, cloud)
2. On phone: Open file manager
3. Tap the APK file
4. Allow "Install from unknown sources" if prompted
5. Tap "Install"

**Method C: Cloud Transfer**
1. Upload APK to Google Drive/Dropbox
2. Download on phone
3. Install from Downloads folder

---

### Option 3: Test AAB with bundletool (Most Accurate)

**Why:** AAB is what you'll submit to AGC, but you can't install it directly. Use bundletool to generate device-specific APKs.

**Step 1: Install bundletool**
```bash
# Download from:
# https://github.com/google/bundletool/releases
# Or use chocolatey:
choco install bundletool
```

**Step 2: Generate APK Set from AAB**
```bash
cd build/app/outputs/bundle/release

# Generate APK set (requires keystore)
bundletool build-apks --bundle=app-release.aab --output=app-release.apks --ks="C:\Users\alvin\Desktop\Conflict\project_1\android\app\keystore\mysafezone-release.jks" --ks-pass=pass:123Abc!@# --ks-key-alias=mysafezone --key-pass=pass:123Abc!@#
```

**Step 3: Install on Connected Device**
```bash
bundletool install-apks --apks=app-release.apks
```

---

## ✅ COMPLETE TESTING CHECKLIST

### Pre-Installation Tests

- [ ] **Check file size**
  ```bash
  Get-Item build\app\outputs\bundle\release\app-release.aab | Select-Object Name, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB, 2)}}
  ```
- [ ] **Verify signing**
  ```bash
  # For APK
  jarsigner -verify -verbose -certs build\app\outputs\flutter-apk\app-release.apk
  # Should show: "jar verified"
  ```

### Installation Tests

- [ ] App installs without errors
- [ ] No "App not installed" errors
- [ ] Installation completes in reasonable time (<30 seconds)
- [ ] App icon appears in launcher
- [ ] App name displays correctly

### Launch Tests

- [ ] **First Launch**
  - [ ] App launches without crashing
  - [ ] Splash screen appears
  - [ ] No ANR (Application Not Responding) errors
  - [ ] Loads in <3 seconds

- [ ] **Subsequent Launches**
  - [ ] App launches quickly
  - [ ] Maintains previous state (if applicable)

### Core Functionality Tests

#### 1. Authentication & Account
- [ ] Huawei Account login works
- [ ] Account information loads correctly
- [ ] Profile displays user details
- [ ] Logout works properly
- [ ] Re-login works

#### 2. Location Services
- [ ] Location permission requested
- [ ] GPS tracking works
- [ ] Background location tracking works
- [ ] Map displays correctly
- [ ] Current location marker shows
- [ ] Location updates in real-time

#### 3. Emergency Features
- [ ] SOS button accessible
- [ ] SOS button triggers alert
- [ ] Emergency contacts notified (test with real contact)
- [ ] Location shared with emergency contacts
- [ ] Audio recording works (if triggered)

#### 4. Sensors & Audio
- [ ] Microphone permission works
- [ ] Audio recording functional
- [ ] Speech-to-text works
- [ ] Sensor data collected (accelerometer, gyroscope)
- [ ] No excessive battery drain

#### 5. Incident Reporting
- [ ] Can create new incident
- [ ] Photo capture works
- [ ] Video capture works
- [ ] Audio recording works
- [ ] File upload works
- [ ] Incident saved to cloud
- [ ] Can view incident history
- [ ] Can view incident details

#### 6. Community Features
- [ ] Community feed loads
- [ ] Can view other incidents
- [ ] Map shows nearby incidents
- [ ] Can interact with community posts

#### 7. Push Notifications
- [ ] Notification permission works
- [ ] Push notifications received
- [ ] Notification tap opens correct screen
- [ ] Notification sound/vibration works

#### 8. Cloud Services
- [ ] Data syncs to cloud
- [ ] CloudDB reads/writes work
- [ ] Cloud Storage uploads work
- [ ] Can retrieve stored media
- [ ] Offline mode handles gracefully

### Performance Tests

#### Speed & Responsiveness
- [ ] UI is smooth (60 FPS)
- [ ] No lag when scrolling
- [ ] Buttons respond immediately
- [ ] No frozen screens
- [ ] Animations smooth

#### Memory & Resources
- [ ] App doesn't crash after extended use (>30 mins)
- [ ] Memory usage reasonable (<200 MB)
- [ ] Battery drain acceptable
  ```
  Check: Settings → Battery → App battery usage
  Should not be in top 3 unless actively used
  ```
- [ ] Storage usage reasonable
  ```
  Check: Settings → Apps → MySafeZone → Storage
  ```

#### Network
- [ ] Works on WiFi
- [ ] Works on mobile data
- [ ] Handles poor connection gracefully
- [ ] Offline mode works (if applicable)
- [ ] Reconnects automatically

### Security Tests

- [ ] Release build is NOT debuggable
  ```bash
  # Check APK
  aapt dump badging build\app\outputs\flutter-apk\app-release.apk | Select-String "debuggable"
  # Should show nothing or "debuggable='false'"
  ```
- [ ] Code is obfuscated (can't easily decompile)
- [ ] Keystore signature verified
- [ ] HTTPS used for all network calls
- [ ] Sensitive data encrypted

### Device Compatibility

Test on multiple devices if possible:

**Minimum:** 
- [ ] One Huawei device (P30, Mate 20, or later)

**Recommended:**
- [ ] Huawei device with HMS
- [ ] Different Android versions (10, 11, 12, 13, 14)
- [ ] Different screen sizes
- [ ] Low-end device (2GB RAM)
- [ ] High-end device (8GB+ RAM)

### Edge Cases

- [ ] **Permissions Denied**
  - App handles denied permissions gracefully
  - Shows clear message about why permission needed
  - Provides way to re-enable permissions

- [ ] **No Internet**
  - App doesn't crash without internet
  - Shows appropriate "offline" message
  - Queues actions for later (if applicable)

- [ ] **Low Battery**
  - App works in battery saver mode
  - Background features respect power saving

- [ ] **Low Storage**
  - App handles low storage gracefully
  - Doesn't crash if can't save files

- [ ] **Account Issues**
  - Handles Huawei Account logout
  - Handles account switching
  - Handles expired tokens

### Regression Tests

- [ ] All features that worked in debug still work in release
- [ ] No new crashes
- [ ] No performance degradation
- [ ] UI looks identical to debug build

---

## 🐛 COMMON ISSUES & FIXES

### Issue 1: App Crashes on Launch

**Possible Causes:**
- ProGuard/R8 removed necessary code
- Missing permissions in manifest

**Fix:**
```bash
# Check logs
adb logcat | Select-String "MySafeZone"

# Or see full crash
adb logcat AndroidRuntime:E *:S
```

**If ProGuard issue:** Add keep rules in `proguard-rules.pro`

---

### Issue 2: Features Don't Work

**Check:**
- API keys present (not removed by obfuscation)
- All permissions granted
- Network connectivity
- HMS services installed on device

**Debug:**
```bash
# View logs while using app
adb logcat -c  # Clear logs
adb logcat | Select-String "flutter"
```

---

### Issue 3: App Size Too Large

**Check current size:**
```bash
Get-Item build\app\outputs\bundle\release\app-release.aab | Select Length
```

**If over 100MB:**
- Check if all unused dependencies removed
- Verify R8 is enabled
- Check for large assets

---

### Issue 4: "App Not Installed"

**Causes:**
- Different signing key than previous install
- Corrupted APK
- Insufficient storage

**Fix:**
```bash
# Uninstall existing version first
adb uninstall com.meowResQ.mysafezone

# Then install new version
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

### Issue 5: Permissions Not Working

**Check:**
```
Settings → Apps → MySafeZone → Permissions
```

**Ensure requested:**
- Location (Allow all the time)
- Camera
- Microphone
- Storage
- Phone (for SMS/calls if used)

---

## 📊 PERFORMANCE MONITORING

### Monitor CPU Usage
```bash
# While app is running
adb shell top | Select-String "mysafezone"
```

### Monitor Memory
```bash
adb shell dumpsys meminfo com.meowResQ.mysafezone
```

### Monitor Battery
```bash
adb shell dumpsys batterystats com.meowResQ.mysafezone
```

### Monitor Network
```bash
adb shell dumpsys netstats | Select-String "mysafezone"
```

---

## ✅ READY FOR SUBMISSION CRITERIA

Before uploading to AGC Connect, ensure:

### Must Pass:
- [ ] ✅ No crashes during 30-minute test session
- [ ] ✅ All core features working
- [ ] ✅ Permissions work correctly
- [ ] ✅ Location tracking functional
- [ ] ✅ Emergency SOS works
- [ ] ✅ Push notifications received
- [ ] ✅ Huawei Account login works
- [ ] ✅ App signed with release keystore
- [ ] ✅ App size reasonable (<150 MB)
- [ ] ✅ Launch time <3 seconds
- [ ] ✅ UI smooth (no lag)

### Should Pass:
- [ ] ✅ Tested on 2+ devices
- [ ] ✅ Battery usage acceptable
- [ ] ✅ Memory usage under control
- [ ] ✅ Works offline gracefully
- [ ] ✅ Edge cases handled

### Nice to Have:
- [ ] Tested on low-end device
- [ ] Tested on Android 10, 11, 12, 13, 14
- [ ] Performance profiled
- [ ] Security audit done

---

## 🎯 QUICK TEST COMMAND SEQUENCE

```bash
# 1. Check device connected
adb devices

# 2. Install release build
flutter install --release

# 3. Watch logs
adb logcat -c && adb logcat | Select-String "flutter"

# 4. Use app and test all features

# 5. Check for crashes
adb logcat AndroidRuntime:E *:S

# 6. Uninstall when done
adb uninstall com.meowResQ.mysafezone
```

---

## 📱 TEST DEVICES

**Your Test Device Info:**
```
Device Model: ___________________________
Android Version: ________________________
HMS Core Version: _______________________
Screen Size: ____________________________
RAM: ____________________________________
```

**Test Date:** __________  
**Build Version:** 1.0.0+1  
**Tester:** __________

---

## 🎉 TESTING COMPLETE!

Once all tests pass:
1. ✅ Document any issues found and fixed
2. ✅ Take final screenshots for AGC listing
3. ✅ Prepare release notes
4. ✅ Ready to upload to AGC Connect!

---

**Good luck with testing! 🚀**

---

## 📞 QUICK REFERENCE

**APK Location:** `build/app/outputs/flutter-apk/app-release.apk`  
**AAB Location:** `build/app/outputs/bundle/release/app-release.aab`  
**Package Name:** `com.meowResQ.mysafezone`  
**Min Android:** 10 (API 29)  
**Target Android:** 14 (API 34)

**Install:** `flutter install --release`  
**Uninstall:** `adb uninstall com.meowResQ.mysafezone`  
**Logs:** `adb logcat | Select-String "flutter"`

