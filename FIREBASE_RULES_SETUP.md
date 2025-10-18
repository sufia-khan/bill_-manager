# Firebase Security Rules Setup

## Firestore Security Rules

### How to Apply These Rules

#### Option 1: Firebase Console (Recommended for Testing)

1. Go to your Firebase Console:
   https://console.firebase.google.com/project/bill-manager-3cdaf/firestore/rules

2. Click on the "Rules" tab

3. Copy and paste the rules from `firestore.rules` file

4. Click "Publish"

#### Option 2: Firebase CLI (For Production)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

### What These Rules Do

#### 1. **User Authentication Required**
- Only authenticated users can access data
- No anonymous access allowed

#### 2. **User Isolation**
- Users can only access their own bills
- Path: `/users/{userId}/bills/{billId}`
- Each user's data is completely isolated

#### 3. **Data Validation**
- Validates bill structure before saving
- Ensures required fields are present
- Validates data types (string, number, bool)
- Ensures amount is non-negative

#### 4. **CRUD Operations**
- **Read**: User can read their own bills
- **Create**: User can create bills in their collection
- **Update**: User can update their own bills
- **Delete**: User can delete their own bills

#### 5. **Security**
- Denies all other access by default
- Prevents cross-user data access
- Validates data integrity

### Rule Breakdown

```javascript
// User can only access their own bills
match /users/{userId}/bills/{billId} {
  allow read: if isOwner(userId);
  allow create: if isOwner(userId) && isValidBill();
  allow update: if isOwner(userId) && isValidBill();
  allow delete: if isOwner(userId);
}
```

**What this means:**
- `{userId}` must match `request.auth.uid` (logged-in user)
- All operations require authentication
- Create/Update require valid bill data structure

### Testing Rules in Firebase Console

1. Go to: https://console.firebase.google.com/project/bill-manager-3cdaf/firestore/rules

2. Click "Rules Playground"

3. Test scenarios:
   ```
   Location: /users/USER_ID/bills/BILL_ID
   
   ✅ Authenticated as USER_ID → Allow
   ❌ Authenticated as OTHER_USER → Deny
   ❌ Not authenticated → Deny
   ```

### Development vs Production Rules

#### Development (Current - Test Mode)
```javascript
// WARNING: Only for testing!
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2024, 12, 31);
    }
  }
}
```

#### Production (Recommended)
Use the rules in `firestore.rules` file - they provide proper security.

### Common Issues

#### Issue: "Missing or insufficient permissions"
**Cause**: User not authenticated or trying to access another user's data
**Solution**: 
- Ensure user is logged in
- Check `request.auth.uid` matches `userId` in path

#### Issue: "Document does not match required fields"
**Cause**: Missing required fields in bill data
**Solution**: 
- Ensure all required fields are present
- Check data types match validation rules

#### Issue: Rules not updating
**Cause**: Rules not published or cached
**Solution**:
- Click "Publish" in Firebase Console
- Wait a few seconds for propagation
- Clear app cache and restart

### Required Fields Validation

The rules validate these fields:

```javascript
{
  id: string,              // Bill ID
  title: string,           // Bill title
  vendor: string,          // Vendor name
  amount: number,          // Amount (>= 0)
  dueAt: string,          // Due date (ISO string)
  category: string,        // Category name
  isPaid: bool,           // Payment status
  isDeleted: bool,        // Soft delete flag
  updatedAt: string,      // Server timestamp
  clientUpdatedAt: string, // Client timestamp
  repeat: string,         // Repeat frequency
  notes: string (optional) // Optional notes
}
```

### Testing Your Rules

#### Test 1: Authenticated User Access (Should Pass)
```javascript
// User: user123
// Path: /users/user123/bills/bill1
// Result: ✅ Allow
```

#### Test 2: Cross-User Access (Should Fail)
```javascript
// User: user123
// Path: /users/user456/bills/bill1
// Result: ❌ Deny
```

#### Test 3: Unauthenticated Access (Should Fail)
```javascript
// User: null
// Path: /users/user123/bills/bill1
// Result: ❌ Deny
```

#### Test 4: Invalid Data (Should Fail)
```javascript
// User: user123
// Path: /users/user123/bills/bill1
// Data: { title: "Test" } // Missing required fields
// Result: ❌ Deny
```

### Monitoring Rules

1. Go to Firebase Console → Firestore → Usage tab
2. Monitor denied requests
3. Check for security violations
4. Review access patterns

### Best Practices

✅ **Do:**
- Always require authentication
- Validate data structure
- Use helper functions for readability
- Test rules before deploying
- Monitor denied requests

❌ **Don't:**
- Allow public read/write access
- Skip data validation
- Use test mode in production
- Expose sensitive data
- Allow cross-user access

### Quick Deploy Commands

```bash
# Test rules locally
firebase emulators:start --only firestore

# Deploy rules to production
firebase deploy --only firestore:rules

# View current rules
firebase firestore:rules get

# Validate rules
firebase firestore:rules validate
```

### Emergency: Rollback Rules

If something goes wrong:

1. Go to Firebase Console → Firestore → Rules
2. Click "History" tab
3. Select previous version
4. Click "Restore"

### Support

If you encounter issues:
1. Check Firebase Console logs
2. Test in Rules Playground
3. Verify user authentication
4. Check data structure matches validation

---

## Apply These Rules Now!

1. Copy content from `firestore.rules`
2. Go to: https://console.firebase.google.com/project/bill-manager-3cdaf/firestore/rules
3. Paste and click "Publish"
4. Test your app!

Your data will be secure and properly validated! 🔒
