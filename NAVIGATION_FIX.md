# Navigation Black Screen Fix

## Problem
The app was showing a black screen when navigating back to home from any screen (Settings, Analytics, Calendar) either by:
- Back arrow button
- Bottom navigation bar
- After currency change with loading indicator

**Error**: `'_history.isNotEmpty': is not true` - Navigator assertion failure

## Root Cause
The issue was caused by using `Navigator.pushReplacementNamed()` which replaces the current route in the navigation stack. When combined with `Navigator.pop()`, this caused the navigation stack to become empty, resulting in the assertion error and black screen.

## Solution
Changed navigation pattern from `pushReplacementNamed` to `pushNamed` with `popUntil`:

### Before (Broken):
```dart
// This removes the current route and replaces it
Navigator.pushReplacementNamed(context, '/analytics');

// Later when popping, the stack becomes empty
Navigator.pop(context); // ❌ Causes black screen
```

### After (Fixed):
```dart
// Pop back to root first, then push new route
Navigator.popUntil(context, (route) => route.isFirst);
Navigator.pushNamed(context, '/analytics');

// Or just pop to go home
Navigator.popUntil(context, (route) => route.isFirst); // ✅ Works correctly
```

## Files Modified

1. **lib/screens/bill_manager_screen.dart**
   - Changed from `pushReplacementNamed` to `pushNamed`
   - Home screen now uses `pushNamed` for navigation

2. **lib/screens/settings_screen.dart**
   - Changed navigation to use `popUntil` + `pushNamed`
   - Fixed currency change navigation to properly close dialogs and return to home
   - Added error handling for currency change

3. **lib/screens/analytics_screen.dart**
   - Changed navigation to use `popUntil` + `pushNamed`
   - Home navigation now pops to root

4. **lib/screens/calendar_screen.dart**
   - Changed navigation to use `popUntil` + `pushNamed`
   - Home navigation now pops to root

## Navigation Pattern

### Bottom Navigation Bar:
- **Home (index 0)**: `Navigator.popUntil(context, (route) => route.isFirst)`
- **Analytics (index 1)**: Pop to root, then push analytics
- **Calendar (index 2)**: Pop to root, then push calendar
- **Settings (index 3)**: Pop to root, then push settings

### Back Button:
- Uses default `Navigator.pop(context)` which now works correctly

### Currency Change:
1. Show loading dialog
2. Change currency (await)
3. Close loading dialog
4. Close currency selector
5. Pop to root (home)
6. Show success snackbar

## Benefits
✅ No more black screens
✅ Proper navigation stack management
✅ Back button works correctly
✅ Bottom navigation works correctly
✅ Currency change navigation works correctly
✅ Maintains proper route history
