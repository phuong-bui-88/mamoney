// Firebase Configuration for Web
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyDN15pQ1DpyhPzwdacbopu961VimNdfT00',
    appId: '1:191326204730:web:26c3a0f5a4e0130e859603',
    messagingSenderId: '191326204730',
    projectId: 'mamoney-24390',
    authDomain: 'mamoney-24390.firebaseapp.com',
    databaseURL: 'https://mamoney-24390-default-rtdb.firebaseio.com',
    storageBucket: 'mamoney-24390.firebasestorage.app',
  );
}

// To get these values:
// 1. Go to Firebase Console (https://console.firebase.google.com/)
// 2. Create a new project or select existing
// 3. Go to Project Settings
// 4. Under "Your apps", select the Web app
// 5. Copy the config values to above constants
