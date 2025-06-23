import 'package:flutter/material.dart';
import 'package:helikapter/screens/game/game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: Icon(Icons.flight_takeoff, color: Colors.cyanAccent),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/airplane.png', width: 120),
            const SizedBox(height: 24),
            const Text(
              'Welcome, Pilot!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  Text('Your Coins:', style: TextStyle(fontSize: 18, color: Colors.white70)),
                  SizedBox(height: 8),
                  Text('1000', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                ],
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
              ),
              icon: const Icon(Icons.play_arrow, color: Colors.black),
              label: const Text(
                'Start Game',
                style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GameScreen()),
                );
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[900],
    );
  }
}