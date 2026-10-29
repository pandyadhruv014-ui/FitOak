import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';
import 'screens/auth_screens.dart';
import 'screens/main_app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  double _syncProgress = 0.0;
  String _syncStatusText = "Connecting to FitOak server...";

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _performRealDataSync();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _performRealDataSync() async {
    if (mounted) setState(() { _syncProgress = 0.20; _syncStatusText = "Initializing session..."; });
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) setState(() { _syncProgress = 0.60; _syncStatusText = "Syncing fitness logs & database..."; });
    await dailyTracker.checkSavedSession();

    if (mounted) setState(() { _syncProgress = 1.0; _syncStatusText = "Sync complete!"; });
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (dailyTracker.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainAppShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGateScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/splash_background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF121212)),
          ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _syncStatusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "${(_syncProgress * 100).toInt()}%",
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      const iconSize = 32.0;
                      final iconPosition =
                          (_syncProgress * (trackWidth - iconSize))
                              .clamp(0.0, trackWidth - iconSize);

                      return SizedBox(
                        height: 36,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              width: (iconPosition + (iconSize / 2)).clamp(0.0, trackWidth),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              left: iconPosition,
                              child: RotationTransition(
                                turns: _rotationController,
                                child: Image.asset(
                                  'assets/loading_icon.png',
                                  width: iconSize,
                                  height: iconSize,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.fitness_center,
                                    color: Colors.deepOrange,
                                    size: iconSize,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}