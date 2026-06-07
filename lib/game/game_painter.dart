import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'models.dart';

/// Renders the current state of [controller] onto a fixed virtual canvas of
/// [GameController.worldWidth] x [GameController.worldHeight], scaled to fit
/// whatever size it is painted into.
///
/// Everything is drawn as crisp, non-antialiased blocks to give the scene a
/// retro pixel-art feel reminiscent of classic 16-bit platformers, using only
/// shapes generated in code (no external art assets).
class GamePainter extends CustomPainter {
  final GameController controller;

  GamePainter(this.controller) : super(repaint: controller);

  static const _outline = Color(0xFF1B1530);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / GameController.worldWidth;
    final scaleY = size.height / GameController.worldHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    _drawBackground(canvas);
    _drawPlatforms(canvas);
    _drawProjectiles(canvas);
    _drawEnemies(canvas);
    _drawPlayer(canvas);

    canvas.restore();
  }

  // A flat-shaded rectangle with hard, non-antialiased edges — the basic
  // building block for every pixel-art sprite drawn below.
  void _block(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color..isAntiAlias = false);
  }

  void _blockXYWH(Canvas canvas, double x, double y, double w, double h, Color color) {
    _block(canvas, Rect.fromLTWH(x, y, w, h), color);
  }

  // ---------------------------------------------------------------------
  // Background: a cool brick wall with a frosty vertical gradient and a
  // gentle drift of falling snow particles.
  // ---------------------------------------------------------------------
  void _drawBackground(Canvas canvas) {
    final worldRect = Rect.fromLTWH(0, 0, GameController.worldWidth, GameController.worldHeight);
    canvas.drawRect(
      worldRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF274B7A), Color(0xFF9FD3F2)],
        ).createShader(worldRect),
    );

    // Brick courses, alternating offset like a running-bond wall.
    const brickW = 50.0;
    const brickH = 28.0;
    final brickPaint = Paint()
      ..color = const Color(0xFF3A5E8C).withValues(alpha: 0.35)
      ..isAntiAlias = false;
    final mortarPaint = Paint()
      ..color = const Color(0xFF1B1530).withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..isAntiAlias = false;

    var row = 0;
    for (double y = 0; y < GameController.worldHeight; y += brickH) {
      final offset = (row.isOdd) ? -brickW / 2 : 0.0;
      for (double x = -brickW; x < GameController.worldWidth + brickW; x += brickW) {
        final rect = Rect.fromLTWH(x + offset, y, brickW - 4, brickH - 4);
        canvas.drawRect(rect, brickPaint);
        canvas.drawRect(rect, mortarPaint..style = PaintingStyle.stroke);
      }
      row++;
    }

    // Soft falling snow, looping based on elapsed time.
    final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    final t = controller.elapsed;
    final rng = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final seedX = rng.nextDouble() * GameController.worldWidth;
      final speed = 28 + rng.nextDouble() * 40;
      final size = 1.5 + rng.nextDouble() * 2.0;
      final sway = math.sin(t * 1.3 + i) * 10;
      final y = (t * speed + i * 53) % (GameController.worldHeight + 20) - 10;
      canvas.drawCircle(Offset(seedX + sway, y), size, snowPaint);
    }
  }

  // ---------------------------------------------------------------------
  // Platforms: icy stone ledges capped with a ridge of snow and a fringe
  // of icicles, drawn entirely from blocky rectangles.
  // ---------------------------------------------------------------------
  void _drawPlatforms(Canvas canvas) {
    for (final platform in controller.platforms) {
      final r = platform.rect;
      _block(canvas, r, const Color(0xFF6FCF97));
      _block(canvas, r.deflate(2).translate(0, 0), const Color(0xFF57B583));

      // Brick texture on the platform face.
      const cell = 16.0;
      for (double x = r.left; x < r.right; x += cell) {
        final w = math.min(cell - 2, r.right - x);
        _blockXYWH(canvas, x, r.top + r.height / 2, w, r.height / 2 - 2, const Color(0xFF4F9E76));
      }

      // Snow cap along the top edge.
      const snowH = 6.0;
      _blockXYWH(canvas, r.left, r.top - snowH, r.width, snowH, Colors.white);
      _blockXYWH(canvas, r.left, r.top - snowH + 2, r.width, 2, const Color(0xFFD7ECFB));

      // Icicles hanging from the underside.
      const icicleW = 10.0;
      var ix = r.left + 6;
      var i = 0;
      while (ix < r.right - icicleW) {
        final h = (i.isEven) ? 8.0 : 5.0;
        final path = Path()
          ..moveTo(ix, r.bottom)
          ..lineTo(ix + icicleW, r.bottom)
          ..lineTo(ix + icicleW / 2, r.bottom + h)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFDCF1FB)..isAntiAlias = false);
        ix += icicleW + 10;
        i++;
      }

      // Outline.
      canvas.drawRect(r, Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = false);
    }
  }

  // ---------------------------------------------------------------------
  // Player: a chibi hero in a red cap and blue overalls, with simple
  // two-frame walk-cycle legs driven by [GameController.elapsed].
  // ---------------------------------------------------------------------
  void _drawPlayer(Canvas canvas) {
    final player = controller.player;
    final blinking = player.invulnerableSeconds > 0 && (player.invulnerableSeconds * 10).floor().isEven;
    if (blinking) return;

    final r = player.rect;
    final flip = !player.facingRight;
    final moving = player.velocity.dx.abs() > 5 && player.onGround;
    final stride = moving ? math.sin(controller.elapsed * 14) * (r.width * 0.12) : 0.0;

    canvas.save();
    if (flip) {
      canvas.translate(r.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }

    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;

    // Boots (animated stride).
    _blockXYWH(canvas, left + w * 0.12 - stride, top + h * 0.84, w * 0.32, h * 0.16, const Color(0xFF4A3322));
    _blockXYWH(canvas, left + w * 0.56 + stride, top + h * 0.84, w * 0.32, h * 0.16, const Color(0xFF4A3322));

    // Overalls (legs + torso).
    _blockXYWH(canvas, left + w * 0.16 - stride, top + h * 0.62, w * 0.28, h * 0.28, const Color(0xFF2D6FE0));
    _blockXYWH(canvas, left + w * 0.56 + stride, top + h * 0.62, w * 0.28, h * 0.28, const Color(0xFF2D6FE0));
    _blockXYWH(canvas, left + w * 0.10, top + h * 0.42, w * 0.80, h * 0.30, const Color(0xFF2D6FE0));
    _blockXYWH(canvas, left + w * 0.10, top + h * 0.42, w * 0.80, h * 0.07, const Color(0xFF1F52AE));

    // Sleeves / gloves.
    _blockXYWH(canvas, left + w * 0.02, top + h * 0.46, w * 0.14, h * 0.18, Colors.white);
    _blockXYWH(canvas, left + w * 0.84, top + h * 0.46, w * 0.14, h * 0.18, Colors.white);

    // Head (skin).
    final faceRect = Rect.fromLTWH(left + w * 0.16, top + h * 0.16, w * 0.68, h * 0.30);
    _block(canvas, faceRect, const Color(0xFFF6C9A0));

    // Cap.
    _blockXYWH(canvas, left + w * 0.10, top, w * 0.80, h * 0.14, const Color(0xFFE0473B));
    _blockXYWH(canvas, left + w * 0.10, top + h * 0.10, w * 0.86, h * 0.07, const Color(0xFFB23226));

    // Eyes.
    _blockXYWH(canvas, left + w * 0.34, top + h * 0.28, w * 0.10, h * 0.07, _outline);
    _blockXYWH(canvas, left + w * 0.58, top + h * 0.28, w * 0.10, h * 0.07, _outline);

    canvas.restore();

    // Outline for readability against busy backgrounds.
    canvas.drawRect(r, Paint()
      ..color = _outline.withValues(alpha: 0.0)
      ..style = PaintingStyle.stroke);
  }

  // ---------------------------------------------------------------------
  // Enemies: round little imps that turn icy-blue once frozen and finally
  // become rollable snowballs with a spiral pattern.
  // ---------------------------------------------------------------------
  void _drawEnemies(Canvas canvas) {
    for (final enemy in controller.enemies) {
      switch (enemy.state) {
        case EnemyState.walking:
          _drawImp(canvas, enemy, const Color(0xFFB261D6), const Color(0xFF7C3FA0));
          break;
        case EnemyState.frozen:
          _drawImp(canvas, enemy, const Color(0xFFA8DDF0), const Color(0xFF6FB8DB));
          _drawFrostOverlay(canvas, enemy.rect);
          break;
        case EnemyState.snowball:
          _drawSnowball(canvas, enemy);
          break;
      }
    }
  }

  void _drawImp(Canvas canvas, Enemy enemy, Color body, Color shade) {
    final r = enemy.rect;
    final w = r.width;
    final h = r.height;
    final left = r.left;
    final top = r.top;
    final bob = math.sin(controller.elapsed * 10 + r.left) * (h * 0.04);

    final bodyRect = Rect.fromLTWH(left + w * 0.06, top + h * 0.18 + bob, w * 0.88, h * 0.74);
    _block(canvas, bodyRect, body);
    _blockXYWH(canvas, left + w * 0.06, top + h * 0.7 + bob, w * 0.88, h * 0.22, shade);

    // Ears / horns.
    _blockXYWH(canvas, left + w * 0.04, top + h * 0.06 + bob, w * 0.18, h * 0.18, shade);
    _blockXYWH(canvas, left + w * 0.78, top + h * 0.06 + bob, w * 0.18, h * 0.18, shade);

    // Eyes — look the way the enemy is walking.
    final eyeOffset = enemy.facingRight ? w * 0.08 : -w * 0.08;
    _blockXYWH(canvas, left + w * 0.30 + eyeOffset, top + h * 0.36 + bob, w * 0.12, h * 0.14, Colors.white);
    _blockXYWH(canvas, left + w * 0.58 + eyeOffset, top + h * 0.36 + bob, w * 0.12, h * 0.14, Colors.white);
    _blockXYWH(canvas, left + w * 0.33 + eyeOffset, top + h * 0.40 + bob, w * 0.06, h * 0.07, _outline);
    _blockXYWH(canvas, left + w * 0.61 + eyeOffset, top + h * 0.40 + bob, w * 0.06, h * 0.07, _outline);

    // Mouth.
    _blockXYWH(canvas, left + w * 0.34, top + h * 0.58 + bob, w * 0.32, h * 0.08, _outline);

    canvas.drawRect(bodyRect, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = false);
  }

  void _drawFrostOverlay(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..isAntiAlias = false;
    canvas.drawLine(rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.2),
        rect.bottomRight - Offset(rect.width * 0.3, rect.height * 0.4), paint);
    canvas.drawLine(rect.topRight + Offset(-rect.width * 0.25, rect.height * 0.3),
        rect.bottomLeft + Offset(rect.width * 0.35, -rect.height * 0.25), paint);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        rect.topLeft + Offset(rect.width * (0.15 + 0.2 * i), rect.height * 0.15),
        1.6,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  void _drawSnowball(Canvas canvas, Enemy enemy) {
    final center = enemy.rect.center;
    final radius = enemy.size.width / 2;
    final spin = controller.elapsed * 6;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white..isAntiAlias = false);
    canvas.drawCircle(center, radius, Paint()
      ..color = const Color(0xFFCFE9F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = false);

    // A rotating spiral made of small dots gives the rolling ball motion.
    final dotPaint = Paint()..color = const Color(0xFFBFE0F4);
    for (var i = 0; i < 6; i++) {
      final angle = spin + i * (math.pi / 3);
      final dotRadius = radius * (0.3 + 0.5 * (i / 6));
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * dotRadius, 1.8, dotPaint);
    }

    // Eyes peeking out of the snowball.
    final eyeOffset = enemy.facingRight ? radius * 0.35 : -radius * 0.35;
    canvas.drawCircle(center + Offset(eyeOffset - 4, -2), 2.2, Paint()..color = _outline);
    canvas.drawCircle(center + Offset(eyeOffset + 4, -2), 2.2, Paint()..color = _outline);
  }

  // ---------------------------------------------------------------------
  // Snowball projectiles: small pixel snowflakes.
  // ---------------------------------------------------------------------
  void _drawProjectiles(Canvas canvas) {
    for (final projectile in controller.projectiles) {
      final r = projectile.rect;
      final c = r.center;
      final spin = controller.elapsed * 8;
      final paint = Paint()..color = Colors.white..isAntiAlias = false;
      final armLen = r.width / 2;

      _block(canvas, Rect.fromCenter(center: c, width: r.width * 0.5, height: r.height * 0.5), paint.color);
      for (var i = 0; i < 4; i++) {
        final angle = spin + i * (math.pi / 2);
        final tip = c + Offset(math.cos(angle), math.sin(angle)) * armLen;
        canvas.drawLine(c, tip, Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..isAntiAlias = false);
      }
      canvas.drawCircle(c, r.width * 0.32, Paint()..color = const Color(0xFFE3F4FC));
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
