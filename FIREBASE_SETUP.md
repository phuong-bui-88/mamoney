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
6. Go to **Rules** tab and replace content with the content from `firestore.rules` file in this project

## Step 4: Get Firebase Configuration

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

## Step 5: Update main.dart

Open `lib/main.dart` and update the Firebase initialization (you'll need to do this after getting your config):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseConfig.firebaseOptions,
  );
  runApp(const MyApp());
}
```

## Step 6: Test the Application

1. Run `flutter pub get` to install dependencies
2. Run `flutter run` to start the app
3. Create a test account and add some transactions
4. Verify data appears in Firestore Database

## Firestore Database Structure

```
users/
  {userId}/
    id: string
    email: string
    displayName: string
    createdAt: timestamp

transactions/
  {transactionId}/
    id: string
    userId: string
    description: string
    amount: number
    type: "income" | "expense"
    category: string
    date: timestamp
    createdAt: timestamp
```

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
