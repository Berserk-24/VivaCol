import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

/// Splash de bienvenida que reproduce el video de intro al abrir la app.
/// Al terminar el video (o al tocar "Saltar") continua hacia el onboarding;
/// si el usuario ya tiene sesion, el redirect del router lo lleva a /home.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/Intro-VivaCol.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((_) {
        _finish();
      });
    _controller.addListener(_checkEnd);
  }

  void _checkEnd() {
    final value = _controller.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration &&
        value.duration > Duration.zero) {
      _finish();
    }
  }

  void _finish() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/');
  }

  @override
  void dispose() {
    _controller.removeListener(_checkEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Saltar'),
            ),
          ),
        ],
      ),
    );
  }
}
