import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:helikapter/screens/auth/login_screen.dart';
import 'package:helikapter/screens/home/home_screen.dart';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HeliKapterApp());
}

class HeliKapterApp extends StatelessWidget {
  const HeliKapterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeliKapter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyanAccent,brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _flyController;
  late Animation<Offset> _flyAnimation;
  bool _showHelicopter = false;
  bool _typingDone = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flyAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(4, -4), // fully off-screen to top-right
    ).animate(CurvedAnimation(parent: _flyController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _flyController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: MediaQuery.of(context).size.height / 2 - 160,
            child: SlideTransition(
              position: _flyAnimation,
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 100,
              ),
            ),
          ),
          Center(
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
              child: AnimatedTextKit(
                isRepeatingAnimation: false,
                animatedTexts: [
                  TyperAnimatedText('HeliKapter', speed: Duration(milliseconds: 100)),
                ],
                onFinished: () {
                  setState(() {
                    _typingDone = true;
                    _showHelicopter = true;
                  });
                  _audioPlayer.play(AssetSource('sounds/heli_fly.mp3'));
                  _flyController.forward();
                  Future.delayed(const Duration(seconds: 2), () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}