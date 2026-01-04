# Firebase Database Management Guide

## Quick Overview

The MaMoney app uses Firebase to store two main types of data:

### 1. Users Collection
Stores user profile information when they sign up.

**Location in Firebase Console:**
- Firestore Database → Collections → `users`

**What gets stored:**
```
users/
 {userId}
   ├── id: "user-unique-id"
   ├── email: "user@example.com"
   ├── displayName: "user"
   └── createdAt: "2026-01-03T10:30:00.000Z"
```

### 2. Transactions Collection
Stores all money transactions (income/expenses).

**Location in Firebase Console:**
 Collections → `transactions`

**What gets stored:**
```
transactions/
 {transactionId}
   ├── id: "transaction-id"
   ├── userId: "user-id-who-owns-it"
   ├── description: "Salary"
   ├── amount: 5000
   ├── type: "income"
   ├── category: "Salary"
   ├── date: "2026-01-03T00:00:00.000Z"
   └── createdAt: "2026-01-03T10:30:00.000Z"
```

## How to View Your Data

### Step 1: Open Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your MaMoney project

### Step 2: Navigate to Firestore Database
- Click "Firestore Database" in the left sidebar

### Step 3: View Collections Tab
- Click the **Collections** tab
- You should see two collections: `users` and `transactions`

### Step 4: Explore the Data
- Click on any collection to see documents
- Click on any document to see its fields
- You can expand nested fields to view all data

## How to Manually Add Data (if needed)

### To Add a User Document:
1. Go to Collections → `users`
2. Click "+ Add document"
3. Enter the user ID (must match Firebase Auth UID)
4. Add fields:
   - `id`: The user's unique ID
   - `email`: User's email address
   - `displayName`: Display name
   - `createdAt`: Timestamp (set to now)

### To Add a Transaction:
1. Go to Collections → `transactions`
2. Click "+ Add document"
3. Enter a transaction ID
4. Add fields:
   - `id`: Unique transaction ID
   - `userId`: The ID of the user who owns it
   - `description`: What the transaction is for
   - `amount`: The amount (as a number)
   - `type`: "income" or "expense"
   - `category`: Category (e.g., "Salary", "Food")
   - `date`: When the transaction occurred
   - `createdAt`: When it was added

## How to Delete Data

### Delete a Specific Document:
1. Navigate to the collection
2. Find the document
3. Click the three dots (⋮) menu
4. Click "Delete"

### Delete an Entire Collection:
1. Click the three dots (⋮) on the collection name
2. Click "Delete collection"
3. Confirm deletion

 **Warning:** Deleting a collection will delete all documents in it!

## Understanding the Security Rules

The Firestore Rules control who can read and write to the database.

**Current Rules (in `firestore.rules`):**

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own user document
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow create: if request.auth.uid == userId;
      allow update: if request.auth.uid == userId;
      allow delete: if request.auth.uid == userId;
    }
    
    // Users can only read/write their own transactions
    match /transactions/{transactionId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
      allow update: if request.auth.uid == resource.data.userId;
      allow delete: if request.auth.uid == resource.data.userId;
    }
  }
}
```

**What this means:**
- Users can only read their own data
- Users can only create/update/delete their own data
- No one can access another user's data
- Unauthenticated users cannot access any data

## How the App Interacts with Firebase

### When User Signs Up:
1. App creates Firebase Auth account
2. App automatically creates user document in Firestore
3. User is now logged in
4. Data stored: email, displayName, createdAt

### When User Adds a Transaction:
1. App creates transaction document in Firestore
2. Transaction is linked to the user via `userId` field
3. Only that user can see/edit/delete it

### When User Signs Out:
1. App clears local session
2. User is logged out
3. Data remains in Firestore (not deleted)

### When User Signs Back In:
1. App verifies credentials
2. App loads user's transactions from Firestore
3. User can continue where they left off

## Debugging Tips

### Check if Data is Being Saved:
1. Create a test account in the app
2. Go to Firebase Console → Firestore Database → Collections
3. Refresh the page
4. Check if a new user document appears in the `users` collection

### Check Authentication:
 Authentication → Users
2. You should see users that signed up with the app
3. If users are in Auth but not in Firestore, check the Firestore Rules

### Check Browser Console for Errors:
1. In your app, open Developer Tools (F12)
2. Go to Console tab
3. Look for any Firebase-related error messages
4. These can help diagnose connection or permission issues

## Common Issues and Solutions

### Issue: User signed up but data not in Firestore
**Solution:**
1. Check if user appears in Firebase Auth
2. Check Firestore Rules are correctly published
3. Check browser console for error messages
4. Try signing out and signing back in

### Issue: Cannot create transactions
**Solution:**
1. Make sure you're signed in
2. Check that the `userId` field matches your authenticated user ID
3. Check Firestore Rules allow write access
4. Check browser console for errors

### Issue: Transactions not showing up
**Solution:**
 transactions
2. Manually check if documents are being created
3. Verify the `userId` field in transactions matches your user ID
4. Check the browser console for any errors

## Monitoring Quota and Limits

Firebase Firestore has free tier limits:
- **Reads**: 50,000 per day
- **Writes**: 20,000 per day
- **Deletes**: 20,000 per day

Check your usage:
1. Go to Firebase Console → Project Settings (gear icon)
2. Click "Usage and billing" tab
3. You can see current usage for the month

For a personal app, you'll rarely exceed these limits!

