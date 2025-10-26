# Huawei ID Linking to Email Accounts - Complete Guide

## 🎯 Overview
This feature allows users who registered with **Email + Password** to link their **Huawei ID** to the same account. After linking, they get access to their Huawei profile picture and can sign in with either method.

---

## ✨ Key Benefits

### 1. **Profile Picture** 🖼️
- Email accounts don't have profile pictures by default
- Link Huawei ID → Get your Huawei profile picture automatically
- Picture appears in profile and throughout the app

### 2. **Flexible Sign-In** 🔐
- Start with email + password
- Link Huawei ID
- Now you can sign in with **either** method
- Same account, same data, more options!

### 3. **Native AGConnect Linking** 🔗
- Uses AGConnect Auth's native `link()` method
- Not CloudDB-level merging - this is proper provider linking
- One AGCUser with multiple authentication providers

---

## 📝 How It Works

### User Journey:

```
1. User registers with email: user@example.com + password
   └─> AGCUser created (providerId: Email)
   
2. User goes to Profile page
   └─> Sees "Link Huawei ID" card
   
3. User clicks "Link Huawei Account"
   └─> Huawei Account Kit authentication starts
   
4. User signs in with Huawei ID
   └─> AGCUser.link(huaweiCredential) is called
   
5. ✅ Linked successfully!
   └─> Same AGCUser now has both providers
   └─> Profile picture appears
   └─> Can sign in with either email or Huawei ID
```

### Technical Flow:

```dart
// Step 1: Get current user (email login)
AGCUser currentUser = await AGCAuth.instance.currentUser;

// Step 2: Get Huawei Account credentials
AuthAccount huaweiAccount = await AccountAuthManager.getService().signIn();
AGCAuthCredential credential = HuaweiAuthProvider.credentialWithToken(token);

// Step 3: Link credentials to current user
SignInResult result = await currentUser.link(credential);

// Step 4: Now result.user has both providers linked!
// result.user.photoUrl → Huawei profile picture ✅
// result.user.email → Original email ✅
// result.user.providerId → Shows linked providers ✅
```

---

## 🎨 UI Components

### Profile Page - Link Card

**Appears when:**
- User is logged in with Email provider (providerId == 12)
- Huawei ID is NOT already linked

**Card Design:**
```
┌─────────────────────────────────────────┐
│ 🔗  Link Huawei ID                      │
│     Get your profile picture &          │
│     easier sign-in                      │
│                                         │
│  [ Link Huawei Account ]  (Button)     │
└─────────────────────────────────────────┘
```

**After linking:**
- Card disappears (Huawei ID is now linked)
- Profile picture appears in header
- User info section shows linked providers

---

## 🔧 Implementation Details

### Files Modified:

#### 1. **`lib/signup_login/auth_service.dart`**
Added new method:
```dart
Future<AGCUser?> linkHuaweiID(BuildContext? context)
```

**What it does:**
- Gets current logged-in user
- Initiates Huawei Account authentication
- Calls `AGCUser.link()` with Huawei credential
- Updates CloudDB with Huawei info (username, photo)
- Shows success message

#### 2. **`lib/profile/profile_page.dart`**
Added:
- `_isHuaweiIdLinked()` - Checks if Huawei ID is already linked
- `_buildLinkHuaweiIdCard()` - UI card prompting user to link
- `_handleLinkHuaweiId()` - Handler for link button click

---

## 🧪 Testing Scenarios

### Test Case 1: Link Huawei ID to Email Account
1. Register with email: `test@example.com` + password ✉️
2. Go to Profile page
3. ✅ Should see "Link Huawei ID" card
4. Click "Link Huawei Account"
5. Sign in with Huawei ID (use same email or different - both work)
6. ✅ Should see success message
7. ✅ Profile picture should appear
8. ✅ Link card should disappear
9. Log out and try signing in with Huawei ID
10. ✅ Should work! Same account, all data preserved

### Test Case 2: Already Linked
1. User has already linked Huawei ID
2. Go to Profile page
3. ✅ Should NOT see "Link Huawei ID" card
4. ✅ Profile picture should be visible

### Test Case 3: Sign in Methods After Linking
1. User has linked Huawei ID to email account
2. Log out
3. Sign in with **email + password**
   - ✅ Works, profile picture visible
4. Log out
5. Sign in with **Huawei ID**
   - ✅ Works, same account, same data

### Test Case 4: Error Handling
1. Try to link Huawei ID that's already used by another account
2. ✅ Should show error: "This Huawei ID is already linked to another account."

---

## 🔍 Provider Info Structure

After linking, `AGCUser.providerInfo` contains:

```json
[
  {
    "providerId": "12",  // Email provider
    "uid": "user@example.com",
    "displayName": null,
    "photoUrl": null,
    "email": "user@example.com"
  },
  {
    "providerId": "10",  // Huawei ID provider
    "uid": "huawei_unique_id",
    "displayName": "John Doe",
    "photoUrl": "https://huawei-profile-pic-url",
    "email": "user@example.com"
  }
]
```

The `_isHuaweiIdLinked()` method checks this array for providerId "10".

---

## ⚠️ Important Notes

### 1. **One-Way Operation**
- Linking is permanent (unless you implement unlink)
- Users can't accidentally unlink without custom UI

### 2. **Email Matching Not Required**
- Huawei ID email doesn't have to match registration email
- AGConnect handles the linking securely by account UID

### 3. **Profile Picture Priority**
- AGCUser.photoUrl comes from Huawei ID after linking
- No manual photo upload needed

### 4. **CloudDB Email Storage**
- Email is still stored in CloudDB for backward compatibility
- But the source of truth is AGCUser.email

---

## 🚀 Next Steps & Enhancements

### Potential Additions:

1. **Unlink Feature**
```dart
await currentUser.unlink(AuthProviderType.Huawei);
```

2. **Link Other Providers**
- Google
- Facebook
- Phone number
Same pattern, different credentials!

3. **Show Linked Providers in Profile**
Display badges for each linked provider:
```
Sign-in Methods: 
[Email] [Huawei ID] [Google]
```

4. **Primary Provider Selection**
Let users choose their preferred sign-in method

---

## 🐛 Troubleshooting

### Issue: "Link failed"
**Causes:**
- Huawei ID already linked to another account
- Network issues
- HMS Core not available

**Solution:**
- Check error message in SnackBar
- Verify HMS Core is installed and updated
- Check debug logs for detailed error code

### Issue: Profile picture not showing after link
**Causes:**
- Huawei account doesn't have a profile picture
- Network issue loading image
- Cache issue

**Solution:**
- Verify Huawei account has profile picture set
- Force refresh: log out and back in
- Check `AGCUser.photoUrl` in debug logs

### Issue: Link card still showing after linking
**Causes:**
- UI not refreshed
- providerInfo not updated

**Solution:**
- Call `_userProvider.refreshUser()`
- Check `_isHuaweiIdLinked()` logic
- Verify `AGCUser.providerInfo` contains Huawei provider

---

## 📊 Comparison: CloudDB Linking vs AGConnect Linking

| Feature | CloudDB Linking | AGConnect Linking (This Implementation) |
|---------|----------------|----------------------------------------|
| **Account Structure** | Two separate AGCUsers | One AGCUser with multiple providers |
| **Profile Picture** | Manual upload needed | ✅ Automatic from Huawei |
| **Sign-in Flexibility** | Only one method works | ✅ Both methods work |
| **Data Migration** | Manual CloudDB merge | ✅ Native AGConnect merge |
| **Complexity** | High | ✅ Low (uses native API) |
| **Recommended** | ❌ No | ✅ Yes |

---

## 🎉 Benefits Summary

✅ **Seamless Experience**: One account, multiple sign-in options  
✅ **Profile Pictures**: Automatic from Huawei ID  
✅ **Native Support**: Uses AGConnect's built-in linking  
✅ **Flexible**: Users choose their preferred sign-in method  
✅ **Secure**: AGConnect handles authentication  
✅ **Clean Code**: Minimal custom logic needed  

---

## 📞 API Reference

### AGConnect Auth Methods Used:

```dart
// Link credential to current user
Future<SignInResult> AGCUser.link(AGCAuthCredential credential)

// Unlink provider (future enhancement)
Future<SignInResult> AGCUser.unlink(AuthProviderType provider)

// Check linked providers
List<Map<String, String>>? AGCUser.providerInfo
```

### Huawei Account Kit Methods Used:

```dart
// Get Huawei account
AuthAccount await AccountAuthManager.getService(params).signIn()

// Create credential
AGCAuthCredential HuaweiAuthProvider.credentialWithToken(String token)
```

---

Generated: October 25, 2025  
Feature: Huawei ID Linking for Email Accounts

