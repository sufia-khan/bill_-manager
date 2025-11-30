# Testing Mode Guide

## 🧪 Testing Toggle Added to Settings

A testing section has been added to the Settings screen to help you test all Pro feature states without waiting for the trial to expire.

## Location
Settings > Testing Mode section (purple box at the top)

## Available Test Modes

### 1. **Trial Start** (Green)
- 90 days remaining
- All Pro features unlocked
- Shows "Trial Period" in subscription card

### 2. **Trial Middle** (Blue)
- 45 days remaining
- All Pro features still unlocked
- Good for testing mid-trial experience

### 3. **Trial Ending** (Orange)
- 7 days remaining
- Shows urgency messaging
- Tests "upgrade now" prompts

### 4. **Trial Expired** (Red)
- 0 days remaining
- All Pro features locked
- Shows "Trial Expired" state
- Perfect for testing Pro feature dialogs

### 5. **Pro Member** (Gold)
- Active subscription
- All features unlocked
- Shows "Pro" badge and subscription type

### 6. **Real Mode** (Grey)
- Uses actual registration date
- Production behavior
- Default state

## How to Use

1. Open Settings screen
2. Find the purple "🧪 TESTING MODE" box
3. Tap any button to switch modes
4. App updates immediately
5. Test Pro feature dialogs, subscription screen, etc.

## What to Test

### Trial Expired Mode
- Try adding 6th bill → Shows "Unlimited Bills" dialog
- Try changing currency → Shows "Currency Settings" dialog
- Try archiving bill → Shows "Archive Bills" dialog
- Try adding recurring bill → Shows "Recurring Bills" dialog
- Try adding notes → Shows "Bill Notes" dialog
- Check subscription card → Shows "Trial Expired"

### Pro Member Mode
- All features should work
- Subscription card shows "Pro" status
- No feature locks anywhere

### Trial Start Mode
- All features work
- Shows days remaining
- Tests trial experience

## Important Notes

⚠️ **REMOVE THIS SECTION BEFORE PRODUCTION**

This testing section is marked with:
- Purple background
- "DEV ONLY" red badge
- Science icon 🧪

To remove for production:
1. Delete `_buildTestingSection()` method
2. Remove the call in the build method
3. Set `TrialService.testMode = null` permanently

## Current State Display

The testing box shows:
- Current mode at the bottom
- Active button is highlighted
- Toast notification on mode change

---

Happy testing! 🚀
