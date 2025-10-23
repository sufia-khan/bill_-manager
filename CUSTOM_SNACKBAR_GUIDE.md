# Custom SnackBar - Beautiful Notifications 🎨

## Overview

A beautiful, reusable snackbar widget that provides consistent, professional notifications throughout the app.

## Features

✅ **4 Types:** Success, Error, Warning, Info  
✅ **Beautiful Design:** Rounded corners, icons, shadows  
✅ **Consistent Styling:** Same look across the entire app  
✅ **Action Support:** Optional action buttons  
✅ **Easy to Use:** Simple one-line calls  
✅ **Customizable:** Duration, messages, actions  

---

## File Location

**New File:** `lib/widgets/custom_snackbar.dart`

---

## Usage

### Basic Usage

```dart
import '../widgets/custom_snackbar.dart';

// Success message
CustomSnackBar.showSuccess(context, 'Bill saved successfully!');

// Error message
CustomSnackBar.showError(context, 'Failed to delete bill');

// Warning message
CustomSnackBar.showWarning(context, 'Please check your internet connection');

// Info message
CustomSnackBar.showInfo(context, 'Syncing bills...');
```

### With Custom Duration

```dart
CustomSnackBar.showSuccess(
  context,
  'Bill restored!',
  duration: const Duration(seconds: 5),
);
```

### With Action Button

```dart
CustomSnackBar.showSuccess(
  context,
  'Bill deleted',
  actionLabel: 'Undo',
  onAction: () {
    // Undo the deletion
    billProvider.restoreBill(billId);
  },
);
```

---

## Snackbar Types

### 1. Success (Green)
**Color:** `#059669`  
**Icon:** Check circle  
**Use for:** Successful operations

```dart
CustomSnackBar.showSuccess(context, 'Bill saved successfully!');
```

**Examples:**
- Bill created
- Bill updated
- Bill restored
- Payment marked
- Sync completed

---

### 2. Error (Red)
**Color:** `#EF4444`  
**Icon:** Error circle  
**Use for:** Failed operations

```dart
CustomSnackBar.showError(context, 'Failed to save bill');
```

**Examples:**
- Delete operations
- Failed saves
- Network errors
- Validation errors
- Permission denied

---

### 3. Warning (Orange)
**Color:** `#FF8C00`  
**Icon:** Warning triangle  
**Use for:** Important notices

```dart
CustomSnackBar.showWarning(context, 'Please enable notifications');
```

**Examples:**
- Missing permissions
- Incomplete data
- Approaching limits
- Configuration needed
- Important reminders

---

### 4. Info (Blue)
**Color:** `#3B82F6`  
**Icon:** Info circle  
**Use for:** Informational messages

```dart
CustomSnackBar.showInfo(context, 'Syncing bills in background...');
```

**Examples:**
- Background processes
- Tips and hints
- Status updates
- Feature announcements
- General information

---

## Design Specifications

### Visual Design

```
┌─────────────────────────────────────────┐
│ [Icon]  Message text here...   [Action] │
└─────────────────────────────────────────┘
```

### Styling Details

- **Border Radius:** 12px
- **Padding:** 16px horizontal, 14px vertical
- **Margin:** 16px all sides
- **Behavior:** Floating
- **Elevation:** 6
- **Icon Size:** 24px
- **Icon Background:** White with 20% opacity
- **Icon Border Radius:** 8px
- **Text Size:** 15px
- **Text Weight:** 500 (Medium)
- **Action Button:** White text on semi-transparent background

---

## Migration Guide

### Before (Old Style)

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text('Bill saved!'),
      ],
    ),
    backgroundColor: const Color(0xFF059669),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ),
);
```

### After (New Style)

```dart
CustomSnackBar.showSuccess(
  context,
  'Bill saved!',
  duration: const Duration(seconds: 2),
);
```

**Benefits:**
- ✅ 80% less code
- ✅ Consistent styling
- ✅ Easier to maintain
- ✅ Better UX

---

## Implementation Status

### ✅ Already Updated

1. **Archived Bills Screen** (`lib/screens/archived_bills_screen.dart`)
   - Delete bill snackbar
   - Delete all snackbar
   - Restore bill snackbar

### 🔄 To Be Updated

The following files should be updated to use the new snackbars:

1. **Bill Manager Screen** (`lib/screens/bill_manager_screen.dart`)
   - Mark as paid success
   - Undo payment success
   - Delete bill confirmation

2. **Add Bill Screen** (`lib/screens/add_bill_screen.dart`)
   - Bill created success
   - Bill updated success
   - Validation errors

3. **Settings Screen** (`lib/screens/settings_screen.dart`)
   - Profile updated
   - Notification settings changed
   - Currency changed
   - Permission warnings

4. **Calendar Screen** (`lib/screens/calendar_screen.dart`)
   - Any notifications

5. **Analytics Screen** (`lib/screens/analytics_screen.dart`)
   - Any notifications

6. **Main App** (`lib/main.dart`)
   - Permission dialogs
   - Notification permission warnings

---

## Search and Replace Guide

### Find All Old Snackbars

Search for:
```
ScaffoldMessenger.of(context).showSnackBar
```

### Common Patterns to Replace

#### Pattern 1: Success Message
**Old:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text('Success message'),
      ],
    ),
    backgroundColor: const Color(0xFF059669),
    behavior: SnackBarBehavior.floating,
  ),
);
```

**New:**
```dart
CustomSnackBar.showSuccess(context, 'Success message');
```

#### Pattern 2: Error Message
**Old:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Error message'),
    backgroundColor: Colors.red,
  ),
);
```

**New:**
```dart
CustomSnackBar.showError(context, 'Error message');
```

---

## Best Practices

### 1. Keep Messages Short
✅ Good: "Bill saved successfully!"  
❌ Bad: "Your bill has been successfully saved to the database and will now appear in your list of bills"

### 2. Use Appropriate Types
- Success: Completed actions
- Error: Failed actions
- Warning: Important notices
- Info: Background processes

### 3. Add Actions When Useful
```dart
CustomSnackBar.showSuccess(
  context,
  'Bill deleted',
  actionLabel: 'Undo',
  onAction: () => restoreBill(),
);
```

### 4. Set Appropriate Durations
- Quick actions: 2 seconds
- Important messages: 3-4 seconds
- With actions: 4-5 seconds

---

## Examples from Real Use Cases

### Bill Created
```dart
CustomSnackBar.showSuccess(
  context,
  '${bill.title} created successfully!',
);
```

### Bill Deleted
```dart
CustomSnackBar.showError(
  context,
  '${bill.title} deleted',
  actionLabel: 'Undo',
  onAction: () => billProvider.restoreBill(bill.id),
);
```

### Permission Warning
```dart
CustomSnackBar.showWarning(
  context,
  'Please enable notifications to receive bill reminders',
  duration: const Duration(seconds: 4),
);
```

### Sync Status
```dart
CustomSnackBar.showInfo(
  context,
  'Syncing ${billCount} bills...',
  duration: const Duration(seconds: 2),
);
```

---

## Testing Checklist

- [ ] Success snackbar shows with green background
- [ ] Error snackbar shows with red background
- [ ] Warning snackbar shows with orange background
- [ ] Info snackbar shows with blue background
- [ ] Icons display correctly
- [ ] Messages are readable
- [ ] Action buttons work
- [ ] Duration is appropriate
- [ ] Snackbars are dismissible
- [ ] Multiple snackbars queue properly

---

## Benefits

### For Users
- ✅ Beautiful, modern design
- ✅ Clear visual feedback
- ✅ Consistent experience
- ✅ Easy to understand

### For Developers
- ✅ Less code to write
- ✅ Consistent styling
- ✅ Easy to maintain
- ✅ Type-safe
- ✅ Reusable

---

## Next Steps

1. **Update remaining screens** to use new snackbars
2. **Remove old snackbar code** after migration
3. **Test all snackbars** across the app
4. **Document any custom use cases**

---

## Ready to Use! 🚀

The custom snackbar is ready and already implemented in the Archived Bills screen. Start using it in other screens for a consistent, beautiful notification experience!
