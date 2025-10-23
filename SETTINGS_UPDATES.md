# Settings Screen Updates

## New Features Added

### 1. Edit Profile Functionality
- **Location**: Profile card at the top of settings screen
- **Features**:
  - Tap on profile card to edit display name
  - Shows current name and email
  - Email is read-only (cannot be changed)
  - Updates Firebase Auth profile
  - Updates Firestore user document
  - Shows success/error feedback

### 2. Privacy & Security Dialog
- **Location**: Privacy & Security tile in settings
- **Features**:
  - Comprehensive privacy guidelines
  - Clear explanations of data handling
  - "Clear All Data" functionality

### 3. Privacy Guidelines
The following privacy guidelines are displayed:

1. **Data Encryption**
   - All data is encrypted and securely stored in Firebase

2. **Cloud Backup**
   - Bills are automatically backed up to the cloud

3. **No Third-Party Sharing**
   - Personal data is never shared with third parties

4. **Data Control**
   - Users have full control to delete their data anytime

5. **Local Notifications**
   - Notifications are processed locally on the device

### 4. Clear All Data Feature
- **Location**: Inside Privacy & Security dialog (Danger Zone)
- **Features**:
  - Clears all bills from local storage
  - Deletes all bills from Firebase
  - Cancels all scheduled notifications
  - Account remains active (unlike Delete Account)
  - Shows confirmation dialog with warnings
  - Loading indicator during operation
  - Success/error feedback

## User Flow

### Edit Profile
1. Tap on profile card
2. Edit display name in dialog
3. Click "Save"
4. Profile updates in Firebase and UI refreshes

### Clear All Data
1. Tap "Privacy & Security"
2. Read privacy guidelines
3. Scroll to "Danger Zone"
4. Click "Clear All Data"
5. Confirm in warning dialog
6. Wait for data to be cleared
7. See success message

## Technical Implementation

### Methods Added
- `_showEditProfileDialog()` - Handles profile editing
- `_showPrivacySecurityDialog()` - Shows privacy guidelines and clear data option
- `_buildPrivacyItem()` - Helper to build privacy guideline items
- `_showClearAllDataDialog()` - Handles data clearing with confirmation

### UI Updates
- Profile card now has edit icon and is tappable
- Privacy & Security tile opens comprehensive dialog
- Clear All Data button styled as danger action
- Loading states with blur backdrop
- Success/error snackbars for feedback

## Differences: Clear All Data vs Delete Account

| Feature | Clear All Data | Delete Account |
|---------|---------------|----------------|
| Account Status | Remains Active | Deleted |
| Bills Data | Cleared | Cleared |
| Firebase Auth | Kept | Deleted |
| Can Login Again | Yes | No |
| Can Add New Bills | Yes | No |
