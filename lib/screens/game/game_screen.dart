import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  double _multiplier = 1.0;
  bool _isCrashed = false;
  bool _isRunning = false;
  final _betController = TextEditingController();
  late final Ticker _ticker;
  double _elapsed = 0;
  double? _sessionCrashPoint;
  double _balance = 10000; // Initial balance

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updateGame);
  }

  void _updateGame(Duration elapsed) {
    setState(() {
      _elapsed += 0.05;
      _multiplier = double.parse((1 + _elapsed * 0.25).toStringAsFixed(2));

      // simulate crash
      if (_multiplier >= (_sessionCrashPoint ?? _crashPoint)) {
        _isCrashed = true;
        _isRunning = false;
        _ticker.stop();
      }
    });
  }

  double get _crashPoint => Random().nextDouble() * 5 + 1.5; // random crash between 0x and 500x

  void _startGame() {
    if (_isRunning) return;

    final bet = double.tryParse(_betController.text);
    if (bet == null || bet <= 0 || bet > _balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or insufficient bet amount!')),
      );
      return;
    }

    setState(() {
      _balance -= bet;
      _isCrashed = false;
      _isRunning = true;
      _elapsed = 0;
      _multiplier = 1.0;
      _sessionCrashPoint = _crashPoint;
    });

    _ticker.start();
  }

  void _cashOut() {
    if (!_isCrashed && _isRunning) {
      final bet = double.tryParse(_betController.text);
      if (bet != null) {
        setState(() {
          _balance += bet * _multiplier;
        });
      }

      _ticker.stop();
      setState(() {
        _isRunning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cashed out at ${_multiplier}x!')),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _betController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white24, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '💰 Balance: ₹${_balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background color
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                    ),
                  ),
                  // Helicopter animation placeholder
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    bottom: _isCrashed ? 0 : _elapsed * 30,
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      height: 60,
                    ),
                  ),
                  // Multiplier / crash indicator
                  Positioned(
                    top: 40,
                    child: Text(
                      _isCrashed ? '💥 Crashed at $_multiplier x' : '${_multiplier.toStringAsFixed(2)}x',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _isCrashed ? Colors.red : Colors.cyanAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _betController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Enter Bet Amount',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 16),
                        prefixIcon: const Icon(Icons.monetization_on, color: Colors.cyanAccent),
                        filled: true,
                        fillColor: Colors.white10,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.cyanAccent),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.cyan),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Start'),
                        ),
                        ElevatedButton(
                          onPressed: _cashOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Cash Out'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}