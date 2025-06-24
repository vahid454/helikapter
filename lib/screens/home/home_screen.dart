import 'package:flutter/material.dart';
import 'package:helikapter/screens/game/game_screen.dart';
import 'package:helikapter/screens/wallet/wallet_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helikapter/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ValueNotifier<int> _walletBalance = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final prefs = await SharedPreferences.getInstance();
    _walletBalance.value = prefs.getInt('wallet_balance') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'HeliKapter',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.cyanAccent,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ValueListenableBuilder<int>(
              valueListenable: _walletBalance,
              builder: (context, value, _) {
                return Text('₹$value', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16));
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: Icon(Icons.flight_takeoff, color: Colors.cyanAccent),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.grey[850],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(Icons.flight_takeoff, color: Colors.cyanAccent, size: 40),
              title: const Text('Aviator Game', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: const Text('Tap to play the aviator-style game', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey[850],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(Icons.sports_basketball, color: Colors.amberAccent, size: 40),
              title: const Text('Balloon Game', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: const Text('Tap to play the upcoming balloon game', style: TextStyle(color: Colors.white70)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balloon game coming soon!')));
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey[900],
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.account_circle, size: 48, color: Colors.cyanAccent),
                  SizedBox(height: 12),
                  Text('Pilot Profile', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text('Profile', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.white),
              title: const Text('Wallet', style: TextStyle(color: Colors.white)),
              onTap: () {
                 debugPrint("Tapped Wallet Menu");
                 Navigator.pop(context); 
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ).then((_) {
                  _loadWalletBalance();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}