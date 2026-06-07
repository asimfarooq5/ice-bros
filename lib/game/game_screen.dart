import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game_controller.dart';
import 'game_painter.dart';
import 'models.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final GameController _controller;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    // Guard against the huge first-frame delta and any long pauses.
    if (dt > 0 && dt < 0.1) {
      _controller.update(dt);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: GameController.worldWidth / GameController.worldHeight,
                child: CustomPaint(painter: GamePainter(_controller), child: Container()),
              ),
            ),
            Align(alignment: Alignment.topCenter, child: _Hud(controller: _controller)),
            Align(alignment: Alignment.bottomCenter, child: _Controls(controller: _controller)),
            _GameOverOverlay(controller: _controller),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final GameController controller;

  const _Hud({required this.controller});

  static const _label = TextStyle(
    color: Color(0xFF7FE0FF),
    fontSize: 12,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    letterSpacing: 1,
  );

  static const _value = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    letterSpacing: 1,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF120C24),
          border: Border(bottom: BorderSide(color: Color(0xFF1B1530), width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1UP SCORE', style: _label),
                Text(controller.score.toString().padLeft(6, '0'), style: _value),
              ],
            ),
            Row(
              children: List.generate(
                controller.player.lives,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: _PixelHeart(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small blocky heart icon, styled to match the pixel-art HUD.
class _PixelHeart extends StatelessWidget {
  const _PixelHeart();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 16,
      child: CustomPaint(painter: _PixelHeartPainter()),
    );
  }
}

class _PixelHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 6;
    final paint = Paint()..color = const Color(0xFFE0473B)..isAntiAlias = false;
    const grid = [
      '.##.##.',
      '#######',
      '#######',
      '.#####.',
      '..###..',
      '...#...',
    ];
    for (var y = 0; y < grid.length; y++) {
      for (var x = 0; x < grid[y].length; x++) {
        if (grid[y][x] == '#') {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Controls extends StatelessWidget {
  final GameController controller;

  const _Controls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _ControlButton(
                icon: Icons.arrow_back,
                onPressedDown: () => controller.setMoveLeft(true),
                onPressedUp: () => controller.setMoveLeft(false),
              ),
              const SizedBox(width: 12),
              _ControlButton(
                icon: Icons.arrow_forward,
                onPressedDown: () => controller.setMoveRight(true),
                onPressedUp: () => controller.setMoveRight(false),
              ),
            ],
          ),
          Row(
            children: [
              _ControlButton(icon: Icons.ac_unit, onTap: controller.shoot),
              const SizedBox(width: 12),
              _ControlButton(icon: Icons.arrow_upward, onTap: controller.jump),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onPressedDown;
  final VoidCallback? onPressedUp;

  const _ControlButton({required this.icon, this.onTap, this.onPressedDown, this.onPressedUp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: onPressedDown == null ? null : (_) => onPressedDown!(),
      onTapUp: onPressedUp == null ? null : (_) => onPressedUp!(),
      onTapCancel: onPressedUp,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1530),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7FE0FF), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final GameController controller;

  const _GameOverOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.status == GameStatus.playing) {
          return const SizedBox.shrink();
        }
        final won = controller.status == GameStatus.won;
        return Positioned.fill(
          child: Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF120C24),
                border: Border.all(color: const Color(0xFF7FE0FF), width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    won ? 'STAGE CLEAR!' : 'GAME OVER',
                    style: const TextStyle(
                      color: Color(0xFFE0473B),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'SCORE  ${controller.score.toString().padLeft(6, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: controller.restart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6FE0),
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
