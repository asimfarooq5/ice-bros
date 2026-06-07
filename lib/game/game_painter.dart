import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'models.dart';

/// Renders the current state of [controller] onto a fixed virtual canvas of
/// [GameController.worldWidth] x [GameController.worldHeight], scaled to fit
/// whatever size it is painted into.
class GamePainter extends CustomPainter {
  final GameController controller;

  GamePainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / GameController.worldWidth;
    final scaleY = size.height / GameController.worldHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    _drawBackground(canvas);
    _drawPlatforms(canvas);
    _drawPlayer(canvas);
    _drawEnemies(canvas);
    _drawProjectiles(canvas);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas) {
    final worldRect = Rect.fromLTWH(0, 0, GameController.worldWidth, GameController.worldHeight);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8FD3FE), Color(0xFFE6F7FF)],
      ).createShader(worldRect);
    canvas.drawRect(worldRect, paint);
  }

  void _drawPlatforms(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF6FCF97);
    for (final platform in controller.platforms) {
      canvas.drawRRect(RRect.fromRectAndRadius(platform.rect, const Radius.circular(4)), paint);
    }
  }

  void _drawPlayer(Canvas canvas) {
    final player = controller.player;
    final blinking = player.invulnerableSeconds > 0 && (player.invulnerableSeconds * 10).floor().isEven;
    if (blinking) return;

    final bodyPaint = Paint()..color = const Color(0xFFEF5350);
    canvas.drawRRect(RRect.fromRectAndRadius(player.rect, const Radius.circular(8)), bodyPaint);

    final eyePaint = Paint()..color = Colors.white;
    final eyeX = player.facingRight ? player.rect.right - 12 : player.rect.left + 4;
    canvas.drawCircle(Offset(eyeX, player.rect.top + 14), 4, eyePaint);
  }

  void _drawEnemies(Canvas canvas) {
    for (final enemy in controller.enemies) {
      final Color color;
      switch (enemy.state) {
        case EnemyState.walking:
          color = const Color(0xFF8E63CE);
          break;
        case EnemyState.frozen:
          color = const Color(0xFF64B5F6);
          break;
        case EnemyState.snowball:
          color = Colors.white;
          break;
      }
      final paint = Paint()..color = color;
      if (enemy.state == EnemyState.snowball) {
        canvas.drawCircle(enemy.rect.center, enemy.size.width / 2, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(enemy.rect, const Radius.circular(8)), paint);
      }
    }
  }

  void _drawProjectiles(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    for (final projectile in controller.projectiles) {
      canvas.drawOval(projectile.rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
