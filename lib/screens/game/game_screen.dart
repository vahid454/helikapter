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
  final _triggerController = TextEditingController();
  bool _autoCashOutEnabled = false;
  late final Ticker _ticker;
  double _elapsed = 0;
  double? _sessionCrashPoint;
  double _balance = 10000; // Initial balance
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updateGame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _startGame();
      _hasStarted = true;
    }
  }

  void _updateGame(Duration elapsed) {
    setState(() {
      _elapsed += 0.05;
      _multiplier = double.parse((1 + _elapsed * 0.25).toStringAsFixed(2));

      final trigger = double.tryParse(_triggerController.text);
      if (_isRunning && !_isCrashed && trigger != null && _multiplier >= trigger && _autoCashOutEnabled) {
        _cashOut(); // Auto cash out
      }

      if (_multiplier >= (_sessionCrashPoint ?? 0)) {
        _isCrashed = true;
        _isRunning = false;
        _ticker.stop();

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isRunning) {
            _startGame();
          }
        });
      }
    });
  }

  double generateCrashPoint(double currentBalance) {
    final random = Random();
    final base = (1 / (1 - random.nextDouble())).clamp(1.0, 20.0);

    if (currentBalance > 15000) {
      return double.parse(min(base, 2.5).toStringAsFixed(2));
    } else if (currentBalance < 100) {
      return double.parse(max(base, 2.0).toStringAsFixed(2));
    }

    return double.parse(base.toStringAsFixed(2));
  }

  void _startGame() {
    if (_isRunning) return;

    final bet = double.tryParse(_betController.text);
    if (bet == null || bet <= 0 || bet > _balance) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or insufficient bet amount!')),
        );
      });
      return;
    }

    final trigger = double.tryParse(_triggerController.text);
    _autoCashOutEnabled = trigger != null && trigger > 1;

    setState(() {
      _balance -= bet;
      _isCrashed = false;
      _isRunning = true;
      _elapsed = 0;
      _multiplier = 1.0;
      _sessionCrashPoint = generateCrashPoint(_balance);
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
    _triggerController.dispose();
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
                  // XY Axis lines
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AxisPainter(),
                    ),
                  ),
                  // Helicopter animation with floating fly motion
                  AnimatedAlign(
                    alignment: Alignment.center,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedPadding(
                      padding: EdgeInsets.only(
                        bottom: 30 + sin(_elapsed) * 10, // simulate up/down flight
                      ),
                      duration: const Duration(milliseconds: 300),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        height: 60,
                      ),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _triggerController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Auto Cashout Multiplier (e.g. 1.20)',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 16),
                        prefixIcon: const Icon(Icons.auto_mode, color: Colors.amberAccent),
                        filled: true,
                        fillColor: Colors.white10,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.amberAccent),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.amber),
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

class _AxisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    // Y-axis
    canvas.drawLine(Offset(40, 0), Offset(40, size.height), paint);
    // X-axis
    canvas.drawLine(Offset(0, size.height - 60), Offset(size.width, size.height - 60), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}