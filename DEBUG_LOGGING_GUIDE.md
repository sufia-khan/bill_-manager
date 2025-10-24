# Debug Logging Guide

## Overview
Debug prints have been added to help you track bill creation, updates, and notification scheduling in real-time.

## What You'll See in the Console

### 1. When Adding a Bill

```
═══════════════════════════════════════════════════════
📝 BILL ADDED SUCCESSFULLY
═══════════════════════════════════════════════════════
Title: Electricity Bill
Amount: $150.00
Due Date: 2025-10-25 00:00:00.000
Category: Utilities
Repeat: monthly
Reminder Timing: 1 Day Before
Notification Time: 14:0
═══════════════════════════════════════════════════════
```

### 2. When Scheduling a Notification

```
🔔 ATTEMPTING TO SCHEDULE NOTIFICATION
─────────────────────────────────────────────────────
📋 Using per-bill notification settings
Bill: Electricity Bill
Due Date: 2025-10-25 00:00:00.000
Days Before Due: 1
Notification Time: 14:00
Calculated Notification Date: 2025-10-24 at 14:00
Current Time: 2025-10-24 13:00:00.000
─────────────────────────────────────────────────────
```

Then from `notification_service.dart`:

```
✅ Notification scheduled successfully!
Bill: Electricity Bill
Due date: 2025-10-25 00:00:00.000
Notification time: 2025-10-24 14:00:00.000+00:00
Days before: 1
Time: 14:0
```

OR if the time is in the past:

```
⚠️ Notification time 2025-10-24 14:00:00.000+00:00 is in the past for bill: Electricity Bill. 
Due date: 2025-10-25 00:00:00.000, Days before: 1, Time: 14:0
```

### 3. Pending Notifications List

After adding or updating a bill, you'll see:

```
📋 PENDING NOTIFICATIONS LIST
═══════════════════════════════════════════════════════
Total: 2 notification(s) scheduled

1. ID: 123456789
   Title: Bill Due Tomorrow
   Body: Electricity Bill - $150.00 due to Electricity Bill
   Payload: abc-123-def

2. ID: 987654321
   Title: Bill Due in 1 Week
   Body: Internet Bill - $80.00 due to Internet Bill
   Payload: xyz-789-uvw

═══════════════════════════════════════════════════════
```

OR if no notifications are scheduled:

```
📋 PENDING NOTIFICATIONS LIST
═══════════════════════════════════════════════════════
⚠️  No notifications scheduled
═══════════════════════════════════════════════════════
```

### 4. When Updating a Bill

```
═══════════════════════════════════════════════════════
✏️  BILL UPDATED
═══════════════════════════════════════════════════════
Title: Electricity Bill
Amount: $175.00
Due Date: 2025-10-26 00:00:00.000
Is Paid: false
═══════════════════════════════════════════════════════
```

Followed by notification scheduling logs and pending notifications list.

### 5. When Marking a Bill as Paid

```
═══════════════════════════════════════════════════════
✏️  BILL UPDATED
═══════════════════════════════════════════════════════
Title: Electricity Bill
Amount: $150.00
Due Date: 2025-10-25 00:00:00.000
Is Paid: true
═══════════════════════════════════════════════════════

🔕 Cancelling notification for paid bill

📋 PENDING NOTIFICATIONS LIST
═══════════════════════════════════════════════════════
Total: 1 notification(s) scheduled
...
```

### 6. When Notifications are Disabled

```
🔔 ATTEMPTING TO SCHEDULE NOTIFICATION
─────────────────────────────────────────────────────
❌ Notifications are disabled globally
─────────────────────────────────────────────────────
```

## How to Use This Information

### Scenario 1: Notification Not Appearing
1. Add a bill
2. Check the console for:
   - ✅ "Notification scheduled successfully!" - Good!
   - ⚠️ "Notification time ... is in the past" - Problem! The time has already passed
   - ❌ "Notifications are disabled globally" - Enable notifications in settings

### Scenario 2: Verify Notification is Scheduled
1. Add a bill
2. Look for the "PENDING NOTIFICATIONS LIST"
3. Your bill should appear in the list with the correct time

### Scenario 3: Check Notification Time Calculation
1. Add a bill
2. Look at the "ATTEMPTING TO SCHEDULE NOTIFICATION" section
3. Compare:
   - "Due Date" - When the bill is due
   - "Days Before Due" - How many days before
   - "Calculated Notification Date" - When notification will trigger
   - "Current Time" - Right now
4. If "Calculated Notification Date" is before "Current Time", the notification won't be scheduled

## Quick Reference

| Symbol | Meaning |
|--------|---------|
| ✅ | Success - notification scheduled |
| ⚠️ | Warning - notification not scheduled (time in past) |
| ❌ | Error - notifications disabled or other issue |
| 📝 | Bill added |
| ✏️ | Bill updated |
| 🔔 | Attempting to schedule notification |
| 🔕 | Cancelling notification |
| 📋 | Pending notifications list |
| 🌐 | Using global settings |
| 📋 | Using per-bill settings |

## Example: Successful Notification Setup

```
═══════════════════════════════════════════════════════
📝 BILL ADDED SUCCESSFULLY
═══════════════════════════════════════════════════════
Title: Test Bill
Amount: $10.00
Due Date: 2025-10-27 00:00:00.000
Category: Other
Repeat: none
Reminder Timing: 1 Day Before
Notification Time: 14:0
═══════════════════════════════════════════════════════

🔔 ATTEMPTING TO SCHEDULE NOTIFICATION
─────────────────────────────────────────────────────
📋 Using per-bill notification settings
Bill: Test Bill
Due Date: 2025-10-27 00:00:00.000
Days Before Due: 1
Notification Time: 14:00
Calculated Notification Date: 2025-10-26 at 14:00
Current Time: 2025-10-24 13:00:00.000
─────────────────────────────────────────────────────

✅ Notification scheduled successfully!
Bill: Test Bill
Due date: 2025-10-27 00:00:00.000
Notification time: 2025-10-26 14:00:00.000+00:00
Days before: 1
Time: 14:0

📋 PENDING NOTIFICATIONS LIST
═══════════════════════════════════════════════════════
Total: 1 notification(s) scheduled

1. ID: 123456789
   Title: Bill Due in 2 Days
   Body: Test Bill - $10.00 due to Test Bill
   Payload: abc-123-def

═══════════════════════════════════════════════════════
```

This shows:
- ✅ Bill was added successfully
- ✅ Notification was scheduled for Oct 26 at 2:00 PM
- ✅ Current time (Oct 24 1:00 PM) is before notification time
- ✅ Notification appears in pending list

## Tips

1. **Always check the console after adding a bill** to verify the notification was scheduled
2. **Look for the ✅ symbol** - this means success
3. **If you see ⚠️**, the notification time is in the past - adjust your settings
4. **Check "PENDING NOTIFICATIONS LIST"** to see all scheduled notifications
5. **Compare "Calculated Notification Date" with "Current Time"** to understand why a notification wasn't scheduled
