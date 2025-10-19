# Testing Recurring Bills Feature

## How to Test Recurring Bill Auto-Creation

The recurring bills feature automatically creates the next instance of a bill when:
1. The bill is marked as paid, OR
2. The bill's due date has passed

## ✨ NEW: Repeat Count Feature

You can now specify how many times a bill should repeat! Options include:
- **Forever ♾️** - Unlimited repetitions (default)
- **2, 3, 5, 10 times** - Quick presets
- **Custom ✏️** - Enter any number you want

The system will automatically stop creating new instances once the limit is reached!

### Quick Test with "1 Minute (Testing)" Option

I've added a special "1 Minute (Testing)" option to help you verify the feature works:

#### Steps to Test:

1. **Create a Test Bill**
   - Open the app and tap "Add Bill"
   - Fill in the details:
     - Title: "Test Recurring Bill"
     - Vendor: "Test Vendor"
     - Amount: Any amount (e.g., $10)
     - Category: Any category
     - **Repeat: Select "1 Minute (Testing)"**
     - Due Date: Set to current date/time or past date
   - Save the bill

2. **Mark the Bill as Paid**
   - Find the bill in your list
   - Tap on it to open details
   - Mark it as "Paid"
   - This triggers the maintenance process

3. **Wait 1 Minute**
   - The next instance should be created automatically
   - You can also restart the app to trigger maintenance immediately

4. **Verify the New Instance**
   - Check your bill list
   - You should see a new unpaid bill with:
     - Same title, vendor, amount, category
     - Due date 1 minute after the original
     - Status: Upcoming/Unpaid
     - Recurring sequence number incremented

### Testing with Real Intervals

Once you've verified it works with "1 Minute (Testing)", you can test with real intervals:

- **Weekly**: Creates next instance 7 days later
- **Monthly**: Creates next instance 1 month later (preserves day of month)
- **Quarterly**: Creates next instance 3 months later
- **Yearly**: Creates next instance 1 year later

### How the Auto-Creation Works

1. **On App Startup**: Maintenance runs automatically
2. **When Marking as Paid**: Triggers maintenance immediately
3. **Checks**: 
   - Finds all bills with repeat != 'none'
   - Checks if they're paid OR past due date
   - Calculates next due date based on repeat type
   - Creates new instance if it doesn't already exist

### What Gets Copied to New Instance

- ✅ Title
- ✅ Vendor
- ✅ Amount
- ✅ Category
- ✅ Notes
- ✅ Repeat type
- ✅ Parent bill ID (links to original)
- ✅ Sequence number (increments)

### What's Different in New Instance

- ❌ Status: Always starts as "Unpaid"
- ❌ Due Date: Calculated based on repeat type
- ❌ Payment Date: Null (not paid yet)
- ❌ ID: New unique ID

### Viewing Recurring Bill Info

When you open a recurring bill's details, you'll see:
- 🔄 Recurring icon badge
- "Repeats: [frequency]" section
- "Next Due Date: [date]" (if applicable)
- Sequence number (if it's part of a series)

### Important Notes

- **No Duplicates**: The system prevents creating duplicate instances
- **Offline Support**: Works even without internet connection
- **Sync**: New instances sync to Firebase when online
- **Past Bills**: After 30 days of being paid, bills move to "Past Bills" screen

### Removing the Test Option

After testing, you can remove the "1 Minute (Testing)" option by:
1. Opening `lib/screens/add_bill_screen.dart`
2. Removing the line: `'1 Minute (Testing)', // For testing recurring bills`
3. Opening `lib/services/recurring_bill_service.dart`
4. Removing the case: `case '1 minute (testing)':`

Or just leave it - it won't hurt anything!

## Troubleshooting

**Q: New instance not created?**
- Check if the bill's repeat is set to something other than "None"
- Verify the bill is marked as paid OR the due date has passed
- Try restarting the app to trigger maintenance

**Q: Multiple instances created?**
- This shouldn't happen - the system checks for duplicates
- If it does, please check the logs for errors

**Q: Next due date calculation wrong?**
- Check the repeat type is set correctly
- For monthly bills, edge cases like Jan 31 → Feb 28 are handled automatically

## Example Test Scenario

```
1. Create bill:
   - Title: "Netflix"
   - Amount: $15.99
   - Repeat: "1 Minute (Testing)"
   - Due: Today

2. Mark as paid

3. Wait 1 minute (or restart app)

4. Expected result:
   - Original bill: Paid, due today
   - New bill: Unpaid, due 1 minute from original due date
   - Both linked by parentBillId
```

Enjoy testing! 🎉
