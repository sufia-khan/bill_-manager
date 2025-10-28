# Quick Guide: Deleting Recurring Bills

## 🎯 "Delete Only This Occurrence" - What You Need to Know

### What Happens:
✅ **This bill is deleted** - The selected occurrence is removed  
✅ **Notification cancelled** - You won't get reminded about this one  
✅ **Future bills continue** - Next bills will still appear  
✅ **Automatic creation works** - New bills are created as scheduled  

### What DOESN'T Happen:
❌ Recurrence is NOT stopped  
❌ Future bills are NOT deleted  
❌ Other notifications are NOT cancelled  
❌ The series is NOT ended  

---

## 📊 Examples

### Example 1: Gym Membership (10 months)
```
You're on month 3 of 10
You delete month 3

Result:
✅ Months 1-2: Already paid (kept in history)
❌ Month 3: DELETED
✅ Months 4-10: Will still be created and charged

Message: "This occurrence deleted. 7 occurrences remaining."
```

### Example 2: Netflix (Forever)
```
You're on month 8
You delete month 8

Result:
✅ Months 1-7: Already paid (kept in history)
❌ Month 8: DELETED
✅ Months 9, 10, 11... forever: Will still be created

Message: "This occurrence deleted. 2 future bills scheduled, more will be created."
```

---

## 🤔 When to Use Each Option

### Use "Delete Only This Occurrence" When:
- ✅ You want to skip ONE payment
- ✅ You'll resume payments next month
- ✅ You got a free month or credit
- ✅ You already paid elsewhere
- ✅ You want to keep the subscription active

**Example:** "I got a free month of gym, so I'll skip this month's bill but keep my membership."

### Use "Delete This and All Future" When:
- ✅ You're cancelling the service NOW
- ✅ You don't want future bills
- ✅ You want to stop the recurrence
- ✅ You're switching to a different plan

**Example:** "I'm cancelling my gym membership starting this month."

### Use "Delete Entire Series" When:
- ✅ You want to remove ALL history
- ✅ You made a mistake creating the bill
- ✅ You want a clean slate
- ✅ You're cleaning up old data

**Example:** "I created this bill by mistake, delete everything."

---

## 💡 Pro Tips

### Tip 1: Skipping Months
If you want to skip a few months but keep the subscription:
1. Delete each occurrence individually
2. Future bills will continue automatically
3. No need to recreate the recurring rule

### Tip 2: Checking Remaining Bills
After deleting, the message tells you:
- How many occurrences are left
- Whether more will be created
- What happens next

### Tip 3: Undo Not Available
Once you delete an occurrence:
- It's marked as deleted in the database
- You can't undo it
- But future bills are unaffected

### Tip 4: Notifications
- Deleted occurrence = notification cancelled
- Future occurrences = notifications still scheduled
- New bills = notifications created automatically

---

## 📱 What You'll See

### Success Messages:

**Limited Recurrence:**
- "This occurrence deleted. 9 occurrences remaining."
- "This occurrence deleted. 1 occurrence remaining."
- "Bill deleted successfully. This was the last occurrence."

**Forever Recurring:**
- "This occurrence deleted. Next occurrence will be created automatically."
- "This occurrence deleted. 3 future bills scheduled, more will be created."

---

## ⚠️ Important Notes

1. **Recurrence Continues:** Deleting one occurrence does NOT stop the recurring rule
2. **Future Bills Safe:** All future bills remain scheduled
3. **Automatic Creation:** New bills are created when you pay current ones
4. **Notifications Active:** Future notifications will still fire
5. **No Renumbering:** Sequence numbers stay the same (e.g., Month 4 stays Month 4)

---

## 🔄 How Automatic Creation Works

```
You have: Netflix (Monthly, Forever)

Current state:
- Month 8 (Current)
- Month 9 (Scheduled)
- Month 10 (Scheduled)

You delete Month 8:
- Month 8 (DELETED)
- Month 9 (Becomes current)
- Month 10 (Still scheduled)

You pay Month 9:
- Month 9 (Paid)
- Month 10 (Becomes current)
- Month 11 (Created automatically) ← NEW!

You pay Month 10:
- Month 10 (Paid)
- Month 11 (Becomes current)
- Month 12 (Created automatically) ← NEW!

And so on... forever!
```

---

## ✅ Quick Decision Tree

```
Do you want to stop ALL future bills?
├─ YES → Use "Delete This and All Future"
└─ NO → Continue...

Do you want to remove ALL history?
├─ YES → Use "Delete Entire Series"
└─ NO → Continue...

Do you just want to skip THIS payment?
└─ YES → Use "Delete Only This Occurrence" ✓
```

---

## 📞 Need Help?

If you're unsure which option to choose:
- Read the descriptions in the delete dialog
- Check the message preview
- Remember: "Delete Only This Occurrence" is the safest option
- You can always delete more later if needed

**Remember:** Deleting one occurrence is like skipping a payment - everything else continues as normal!
