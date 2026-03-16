import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/screens/home_screen.dart';
import 'package:mamoney/screens/transaction_list_screen.dart';
import 'package:mamoney/screens/ask_screen.dart';
import 'package:mamoney/services/auth_provider.dart';
import 'package:mamoney/services/chat_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TransactionListScreen(),
    AskScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize ChatProvider with current user ID
    _initializeChatProvider();
  }

  /// Initialize ChatProvider with user ID for Firestore storage
  Future<void> _initializeChatProvider() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final userId = authProvider.user?.uid;

    await chatProvider.init(userId);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Ask',
          ),
        ],
      ),
    );
  }
}
