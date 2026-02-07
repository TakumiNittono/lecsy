# App Review Response

## Submission ID: a808f6e7-5a74-4f49-8cb5-d4c06678da6c
## App: lecsy v1.0

---

## Guideline 2.3.3 - Accurate Metadata (iPad Screenshots)

**Status**: Resolved

We have added additional iPad screenshots that showcase the app's core functionality, including the recording interface and lecture library.

---

## Guideline 4.0 - Design (Permission Request Language)

**Status**: Resolved

We have updated the Info.plist to include the `NSMicrophoneUsageDescription` directly in the file to ensure the permission request is displayed in English, matching the app's primary language.

The permission message reads:
> "Microphone access is required to record and transcribe your lectures."

All UI text in the app is in English, consistent with the App Store listing.

---

## Guideline 5.1.1(v) - Account Deletion

**Status**: Already Implemented

The account deletion feature is available in the app. Here is how to access it:

### Steps to Delete Account:

1. **Sign in** to the app (if not already signed in)
2. Navigate to the **Settings** tab (bottom navigation)
3. In the Account section, tap **"Delete Account"**
4. A confirmation dialog will appear with the message:
   > "Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted."
5. Tap **"Delete"** to confirm

### What happens when account is deleted:

- The user's account is permanently deleted from our authentication system
- All associated data (transcripts, recordings) are permanently removed
- The user is signed out and returned to the login screen
- This action cannot be undone

### Screenshot Location:

Settings Tab → Account Section → "Delete Account" button (red text)

---

## Summary

All three issues have been addressed:

| Guideline | Issue | Resolution |
|-----------|-------|------------|
| 2.3.3 | iPad screenshots only show login | Added screenshots showing app functionality |
| 4.0 | Permission language mismatch | Added NSMicrophoneUsageDescription to Info.plist |
| 5.1.1(v) | No account deletion | Already implemented at Settings > Delete Account |

We have submitted a new build with these updates. Thank you for your review.
