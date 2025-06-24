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

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updateGame);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadWalletBalance();
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

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isRunning && _autoBetEnabled) {
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

    final betText = _betController.text.trim();
    if (betText.isEmpty) return;

    // Ensure auto cashout is set if auto bet is enabled
    if (_autoBetEnabled && (_triggerController.text.trim().isEmpty || double.tryParse(_triggerController.text) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Auto Cashout is required for Auto Bet")),
      );
      return;
    }

    final bet = double.tryParse(betText);
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
      _hasAutoCashedOut = false; // Reset auto cash out guard
    });
    _updateWalletBalance(_balance);
    _ticker.start();
  }

  void _cashOut() {
    // Prevent repeated cash out
    if (_isCrashed || !_isRunning) return;
    if (_hasAutoCashedOut) return;
    final bet = double.tryParse(_betController.text);
    if (bet != null) {
      setState(() {
        double finalMultiplier = _multiplier;
        final trigger = double.tryParse(_triggerController.text);
        if (_autoCashOutEnabled && trigger != null && trigger <= _multiplier) {
          finalMultiplier = trigger;
        }
        // Credit only the amount based on the trigger multiplier, not the crash multiplier
        _balance += bet * finalMultiplier;
        _hasAutoCashedOut = true;
      });
      _updateWalletBalance(_balance);
      _confettiController.play();
      _audioPlayer.play(AssetSource('sounds/win.mp3'));
    }

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
                    child: Text(
                      _isCrashed ? '💥 Crashed at $_multiplier x' : '${_multiplier.toStringAsFixed(2)}x',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _isCrashed ? Colors.red : Colors.cyanAccent,
                      ),
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
                          final won = _recentWins[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: won ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${crash.toStringAsFixed(2)}x',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                                if (_isRunning && _autoBetEnabled)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _cashOut();
                                        setState(() {
                                          _autoBetEnabled = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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