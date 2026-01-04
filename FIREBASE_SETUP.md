# Firebase Setup Guide for MaMoney

## Prerequisites

Before you can run this app, you need to:
1. Have a Google account
2. Access to Firebase Console

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter a project name (e.g., "MaMoney")
4. Select your country and accept terms
5. Click "Create project"

## Step 2: Set Up Authentication

1. In Firebase Console, go to **Authentication** (left sidebar)
2. Click **Get Started**
3. Enable **Email/Password** provider:
   - Click on "Email/Password"
   - Toggle the switch to enable it
   - Click "Save"

## Step 3: Create Firestore Database

1. Go to **Firestore Database** (left sidebar)
2. Click **Create database**
3. Choose location (select one close to your region)
4. Start in **Production mode**
5. Click **Create**

## Step 4: Update Firestore Security Rules

The updated Firestore rules are designed to automatically create user documents when users sign up:

1. Go to **Firestore Database** → **Rules** tab
2. Replace the entire content with this:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to create their own user document during signup
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow create: if request.auth.uid == userId && request.auth.uid == userId;
      allow update: if request.auth.uid == userId;
      allow delete: if request.auth.uid == userId;
    }
    
    // Allow users to read and write their own transactions
    match /transactions/{transactionId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
      allow update: if request.auth.uid == resource.data.userId;
      allow delete: if request.auth.uid == resource.data.userId;
    }
  }
}
```

3. Click **Publish** to apply the rules

## Step 5: Get Firebase Configuration

1. Go to **Project Settings** (gear icon, top right)
2. Under "Your apps", select the Web app (or create one if not exists)
3. Copy the Firebase config object
4. Open `lib/services/firebase_config.dart`
5. Replace the placeholder values with your actual Firebase config values

Example of what you'll see:
```json
{
  "apiKey": "AIzaSyD...",
  "authDomain": "mamoney-xyz.firebaseapp.com",
  "projectId": "mamoney-xyz",
  "storageBucket": "mamoney-xyz.appspot.com",
  "messagingSenderId": "123456789",
  "appId": "1:123456789:web:abcdef..."
}
```

## Step 6: How User Data Gets Created

When a user **signs up**:
1. The app creates an account in Firebase Authentication
2. A user document is automatically created in Firestore with:
   - `id`: The user's unique ID
   - `email`: The user's email address
   - `displayName`: Extracted from the email (part before @)
   - `createdAt`: The signup timestamp

When a user **signs in**:
1. The app verifies the credentials in Firebase Authentication
2. The app checks if a user document exists in Firestore
3. If missing (shouldn't happen), it creates one automatically

## Step 7: Test the Application

1. Run `flutter pub get` to install dependencies
2. Run `flutter run` to start the app
3. **Create a test account** and verify:
   - You can sign up successfully
   - Go to Firebase Console → Firestore Database → **Collections** tab
   - You should see a `users` collection
   - Click into it and verify your user document is there
4. **Add some transactions** and verify:
   - You should see a `transactions` collection created
   - Your transactions should be visible there

## Firestore Database Structure

```
users/
  {userId}/
    id: string (unique user ID)
    email: string (user's email)
    displayName: string (extracted from email)
    createdAt: timestamp (signup time)

transactions/
  {transactionId}/
    id: string (unique transaction ID)
    userId: string (which user owns it)
    description: string (what the transaction is for)
    amount: number (how much)
    type: "income" | "expense"
    category: string (category of transaction)
    date: timestamp (when it happened)
    createdAt: timestamp (when it was added)
```

## Troubleshooting

### Users not appearing in Firestore after signup

**Check these:**
1. **Go to Firebase Console** → Firestore Database
2. Click **Collections** tab - do you see a `users` collection?
3. If yes, expand it - do you see documents?
4. If no documents appear:
   - Check the browser console for errors (F12 → Console)
   - Check Firestore Rules tab - are they correctly applied?
   - Verify Firebase is initialized with correct API keys

### Signup/Signin fails

1. Go to Firebase Console → Authentication → Users tab
2. Check if users are being created there
3. If users exist in Authentication but not in Firestore:
   - Check the Firestore Rules tab
   - Make sure rules match the format above (NOT Realtime Database format)
   - Click **Publish** after updating rules

### Data only in local storage, not in Firestore

This happens when Firebase isn't properly initialized:
1. Verify your Firebase config in `lib/services/firebase_config.dart` matches your project
2. Check that all required fields are filled:
   - `apiKey`
   - `projectId`
   - `appId`
   - `authDomain`
   - `messagingSenderId`

## Security Rules Explanation

The Firestore rules ensure:
- Users can only read/write their own data
- Only authenticated users can access transactions
- Each transaction is tied to a user and can only be modified by that user

## Troubleshooting

### "Permission denied" errors
- Make sure your Firestore rules are properly set
- Verify you're logged in to the app
- Check that the user ID in the transaction matches your current user's UID

### "Firebase app not initialized"
- Make sure `Firebase.initializeApp()` is called in main.dart
- Check that your Firebase config is correct

### "Network error"
- Verify you have internet connection
- Check Firebase Console for service status
- Try rebuilding the app

## Next Steps

After setting up Firebase:
1. Install the app on a device or emulator
2. Create an account
3. Add some transactions
4. View them in Firestore Console to verify data is being stored
