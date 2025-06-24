import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Returns color based on crash multiplier value
  Color getCrashColor(double value) {
    if (value < 1.0) return Colors.red;
    if (value < 2.0) return Colors.redAccent.shade100;
    if (value < 3.0) return Colors.orangeAccent.shade100;
    if (value < 5.0) return Colors.yellowAccent.shade100;
    if (value < 10.0) return Colors.lightGreen.shade200;
    if (value < 20.0) return Colors.greenAccent.shade100;
    if (value < 50.0) return Colors.greenAccent.shade200;
    return Colors.greenAccent.shade400;
  }
  bool _isPlayerInGame = false;
  double _multiplier = 1.0;
  bool _isCrashed = false;
  bool _isRunning = false;
  final _betController = TextEditingController();
  final _triggerController = TextEditingController();
  bool _autoCashOutEnabled = false;
  late final Ticker _ticker;
  double _elapsed = 0;
  double? _sessionCrashPoint;
  double _balance = 0; // Initial balance set to 0
  bool _hasStarted = false;

  bool _autoBetEnabled = false;
  List<double> _recentCrashes = [];
  List<bool> _recentWins = [];

  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasAutoCashedOut = false; // Prevent repeated auto cash out

  String _countdownText = '';

  // Track if user wants to join next round after clicking Start during countdown
  bool _joinNextRound = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updateGame);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadWalletBalance();
     // Start game immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGame();
    });
  }
  Future<void> _loadWalletBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _balance = prefs.getInt('wallet_balance')?.toDouble() ?? 0.0;
    });
  }

  Future<void> _updateWalletBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wallet_balance', newBalance.toInt());
  }

  void _updateGame(Duration elapsed) {
    setState(() {
      _elapsed += 0.05;
      _multiplier = double.parse((1 + _elapsed * 0.25).toStringAsFixed(2));

      final trigger = double.tryParse(_triggerController.text);
      if (_isRunning &&
          !_isCrashed &&
          _autoCashOutEnabled &&
          trigger != null &&
          _multiplier >= trigger &&
          !_hasAutoCashedOut) {
        _cashOut();
        _hasAutoCashedOut = true;
      }

      if (_multiplier >= (_sessionCrashPoint ?? 0)) {
        if (_hasAutoCashedOut) return; // Don't crash again if already cashed out

        _isCrashed = true;
        _isRunning = false;
        _ticker.stop();

        final bet = double.tryParse(_betController.text);
        bool won = false;
        if (bet != null && _autoCashOutEnabled) {
          final trigger = double.tryParse(_triggerController.text);
          if (trigger != null && trigger <= _sessionCrashPoint!) {
            won = true;
            // Credit is handled in _cashOut via auto-cash, so nothing here.
            _confettiController.play();
            _audioPlayer.play(AssetSource('sounds/win.mp3'));
          }
        }
        _recentCrashes.insert(0, _sessionCrashPoint ?? 0);
        _recentWins.insert(0, won);
        if (_recentCrashes.length > 10) {
          _recentCrashes.removeLast();
          _recentWins.removeLast();
        }

        // Schedule countdown label update without showing SnackBar
        for (int i = 4; i >= 1; i--) {
          Future.delayed(Duration(seconds: 5 - i), () {
            if (mounted && !_isRunning) {
              setState(() {
                _countdownText = 'Next game in $i sec';
              });
            }
          });
        }

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isRunning) {
            setState(() {
              _countdownText = '';
              _isCrashed = false;
            });

            // If user queued to join next round, apply balance deduction here
            if (_joinNextRound) {
              final bet = double.tryParse(_betController.text);
              if (bet != null && bet > 0 && bet <= _balance) {
                _balance -= bet;
                _updateWalletBalance(_balance);
                _isPlayerInGame = true;
              }
            }

            _startGame();
          }
        });
      }
    });
  }

  double generateCrashPoint(double currentBalance) {
    final random = Random.secure();
    final roll = random.nextDouble();

    if (roll < 0.5) {
      // 50% chance for crash between 0x and 1.0x (including instant busts)
      return double.parse((roll * 1.0).toStringAsFixed(2));
    } else if (roll < 0.8) {
      // 30% chance for crash between 1.01x and 2.0x
      final innerRoll = Random.secure().nextDouble();
      final crash = 1.01 + innerRoll * (2.0 - 1.01);
      return double.parse(crash.toStringAsFixed(2));
    } else {
      // 20% chance for crash between 2.01x and 100.0x
      final innerRoll = Random.secure().nextDouble();
      final crash = 2.01 + innerRoll * (100.0 - 2.01);
      return double.parse(crash.toStringAsFixed(2));
    }
  }
    
  void _startGame() {
    final bet = double.tryParse(_betController.text);
    final trigger = double.tryParse(_triggerController.text);
    final hasValidBet = bet != null && bet > 0 && bet <= _balance;

    if (_autoBetEnabled && (trigger == null || trigger <= 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Auto Cashout is required for Auto Bet")),
      );
      return;
    }

    _autoCashOutEnabled = trigger != null && trigger > 1;

    if (_isRunning) {
      if (hasValidBet) {
        _joinNextRound = true;
        _isPlayerInGame = false;
      }
      return;
    }

    if (_isCrashed) {
      if (hasValidBet) {
        _joinNextRound = true;
        _isPlayerInGame = true;
      }
      return;
    }

    if (hasValidBet) {
      _balance -= bet!;
      _updateWalletBalance(_balance);
      _isPlayerInGame = true;
    }

    setState(() {
      _isCrashed = false;
      _isRunning = true;
      _elapsed = 0;
      _multiplier = 1.0;
      _sessionCrashPoint = generateCrashPoint(_balance);
      _hasAutoCashedOut = false;
      _joinNextRound = false;
    });

    _ticker.start();
  }

  void _cashOut() {
    if (_isCrashed || !_isRunning || _hasAutoCashedOut || !_isPlayerInGame) return;

    final bet = double.tryParse(_betController.text);
    final hasValidBet = bet != null && bet > 0;
    if (!hasValidBet) return;

    setState(() {
      double finalMultiplier = _multiplier;
      final trigger = double.tryParse(_triggerController.text);
      if (_autoCashOutEnabled && trigger != null && trigger <= _multiplier) {
        finalMultiplier = trigger;
      }
      _balance += bet! * finalMultiplier;
      _hasAutoCashedOut = true;
      _isRunning = false;
      _isCrashed = true;
      _isPlayerInGame = false;
      _autoBetEnabled = false;
    });

    _updateWalletBalance(_balance);
    _confettiController.play();
    _audioPlayer.play(AssetSource('sounds/win.mp3'));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cashed out at ${_multiplier}x!')),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _betController.dispose();
    _triggerController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
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
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      numberOfParticles: 8,
                      minimumSize: const Size(4, 4),
                      maximumSize: const Size(8, 8),
                      gravity: 0.3,
                      colors: [Colors.green, Colors.yellow, Colors.cyan],
                    ),
                  ),
                  // Helicopter animation with floating fly motion
                  AnimatedAlign(
                    alignment: Alignment.center,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedPadding(
                      padding: EdgeInsets.only(
                        bottom: 40 + sin(_elapsed * 3) * 30, // simulate up/down flight
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
                    child: Column(
                      children: [
                        Text(
                          (_isCrashed && !_hasAutoCashedOut)
                              ? '💥 Crashed at $_multiplier x'
                              : '${_multiplier.toStringAsFixed(2)}x',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _isCrashed ? Colors.red : Colors.cyanAccent,
                          ),
                        ),
                        if (_countdownText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _countdownText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    child: SizedBox(
                      height: 30,
                      width: MediaQuery.of(context).size.width,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentCrashes.length,
                        itemBuilder: (context, index) {
                          final crash = _recentCrashes[index];
                          final color = getCrashColor(crash);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${crash.toStringAsFixed(2)}x',
                                style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Row with CheckboxListTile and Stop Auto Bet button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: CheckboxListTile(
                                    value: _autoBetEnabled,
                                    onChanged: (val) {
                                      setState(() => _autoBetEnabled = val ?? false);
                                    },
                                    title: const Text('Auto Bet', style: TextStyle(color: Colors.white)),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                if (_autoBetEnabled)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _cashOut();
                                        setState(() {
                                          _autoBetEnabled = false;
                                          _isRunning = false;
                                          _isCrashed = true;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      child: const Text('Stop'),
                                    ),
                                  ),
                              ],
                            ),
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
                                  child: Text(_autoBetEnabled ? 'Start Auto Bet' : 'Start'),
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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