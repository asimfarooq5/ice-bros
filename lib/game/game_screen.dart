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

  static const _style = TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Score: ${controller.score}', style: _style),
            Row(
              children: List.generate(
                controller.player.lives,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          color: Colors.white24,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  won ? 'Stage Clear!' : 'Game Over',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Score: ${controller.score}', style: const TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: controller.restart, child: const Text('Play Again')),
              ],
            ),
          ),
        );
      },
    );
  }
}
