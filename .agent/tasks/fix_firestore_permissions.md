Currently, your application is encountering `permission-denied` errors when trying to access or update notifications in Firestore. This typically happens when the Firestore Security Rules on the server do not match the queries or authentication state of the app.

Since you are running on an emulator or device (`d/VRI[MainActivity]`), the local `firestore.rules` file in your project workspace must be **deployed** to the Firebase server to take effect.

### 1. Fix: Deploy Firestore Rules

Run the following command in your terminal to deploy your rules:

```bash
firebase deploy --only firestore:rules
```

If you do not have the Firebase CLI installed or configured, you can also manually copy the content of your `firestore.rules` file and paste it into the **Firebase Console > Firestore Database > Rules** tab.

### 2. Implementation Status

I have made the following improvements to make the app more robust against these errors:

1.  **Updated `AndroidManifest.xml`**:
    *   Added `android:enableOnBackInvokedCallback="true"` to silence the warning.
    *   Added `INTERNET` permission to ensure reliable connectivity.

2.  **Updated `NotificationScreen.dart`**:
    *   Added user-friendly error handling for the Notification stream.
    *   If a permission error occurs, it now shows an "Access Denied" message with a "Log Out" button, which helps reset checking the authentication state.

3.  **Updated `NotificationHistoryService.dart`**:
    *   Added specific error catching for `permission-denied` during `markAllAsRead` operations preventing log noise.
    *   Confirmed that `checkAndAddTriggeredNotifications` logic correctly filters by user ID (prevents cross-user data writes that would fail rules).

### 3. Verification Steps

After deploying the rules:
1.  **Restart the App**: Fully close and reopen the app.
2.  **Log Out & Log In**: Go to Settings (or use the button if the error screen appears) and log out, then log back in. This ensures your specific Authentication Token is fresh.
3.  **Check Notifications**: Open the notification screen. The error should be gone.
