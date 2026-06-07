import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'models.dart';

class _MoveResult {
  final Offset position;
  final Offset velocity;
  final bool onGround;

  const _MoveResult(this.position, this.velocity, this.onGround);
}

/// Holds the state of a single Snow Bros style stage and advances it frame by
/// frame. Rendering is handled separately by [GamePainter]; this class only
/// owns gameplay rules (movement, collisions, freezing enemies, scoring).
class GameController extends ChangeNotifier {
  static const double worldWidth = 400;
  static const double worldHeight = 700;

  static const double _gravity = 1700;
  static const double _moveSpeed = 150;
  static const double _jumpVelocity = -620;
  static const double _snowSpeed = 320;
  static const double _snowballSpeed = 260;
  static const int _snowChargeToFreeze = 3;
  static const Offset _spawnPoint = Offset(20, 600);

  final List<Platform> platforms = const [
    Platform(Rect.fromLTWH(0, 660, 400, 40)), // ground
    Platform(Rect.fromLTWH(0, 520, 160, 20)),
    Platform(Rect.fromLTWH(240, 520, 160, 20)),
    Platform(Rect.fromLTWH(120, 380, 160, 20)),
    Platform(Rect.fromLTWH(0, 240, 160, 20)),
    Platform(Rect.fromLTWH(240, 240, 160, 20)),
    Platform(Rect.fromLTWH(120, 100, 160, 20)),
  ];

  late Player player;
  late List<Enemy> enemies;
  late List<SnowProjectile> projectiles;

  int score = 0;
  GameStatus status = GameStatus.playing;

  /// Total time the world has been running, used to drive sprite animations.
  double elapsed = 0;

  bool _moveLeft = false;
  bool _moveRight = false;
  bool _jumpRequested = false;

  GameController() {
    _resetLevel();
  }

  void _resetLevel() {
    player = Player(position: _spawnPoint);
    enemies = [
      Enemy(position: const Offset(340, 470), velocity: const Offset(-60, 0)),
      Enemy(position: const Offset(160, 330), velocity: const Offset(60, 0), facingRight: true),
      Enemy(position: const Offset(20, 190), velocity: const Offset(70, 0), facingRight: true),
    ];
    projectiles = [];
    score = 0;
    status = GameStatus.playing;
    elapsed = 0;
  }

  void restart() {
    _resetLevel();
    notifyListeners();
  }

  void setMoveLeft(bool value) => _moveLeft = value;

  void setMoveRight(bool value) => _moveRight = value;

  void jump() => _jumpRequested = true;

  void shoot() {
    if (status != GameStatus.playing) return;
    final direction = player.facingRight ? 1.0 : -1.0;
    final spawn = Offset(
      player.facingRight ? player.rect.right : player.rect.left - 16,
      player.rect.top + player.size.height / 2 - 8,
    );
    projectiles.add(SnowProjectile(position: spawn, velocity: Offset(direction * _snowSpeed, 0)));
  }

  /// Advances the world by [dt] seconds and notifies listeners to repaint.
  void update(double dt) {
    if (status != GameStatus.playing) return;

    elapsed += dt;
    _updatePlayer(dt);
    _updateEnemies(dt);
    _updateProjectiles(dt);
    _resolveCollisions();
    _checkWinLose();

    notifyListeners();
  }

  void _updatePlayer(double dt) {
    double vx = 0;
    if (_moveLeft) {
      vx -= _moveSpeed;
      player.facingRight = false;
    }
    if (_moveRight) {
      vx += _moveSpeed;
      player.facingRight = true;
    }

    double vy = player.velocity.dy + _gravity * dt;
    if (_jumpRequested && player.onGround) {
      vy = _jumpVelocity;
      player.onGround = false;
    }
    _jumpRequested = false;

    final result = _moveBody(player.position, Offset(vx, vy), player.size, dt);
    player.position = Offset(
      result.position.dx.clamp(0.0, worldWidth - player.size.width),
      result.position.dy,
    );
    player.velocity = Offset(vx, result.velocity.dy);
    player.onGround = result.onGround;

    if (player.invulnerableSeconds > 0) {
      player.invulnerableSeconds = max(0, player.invulnerableSeconds - dt);
    }

    if (player.position.dy > worldHeight) {
      _loseLife();
    }
  }

  void _updateEnemies(double dt) {
    for (final enemy in enemies) {
      switch (enemy.state) {
        case EnemyState.walking:
          final vx = enemy.facingRight ? _moveSpeed * 0.5 : -_moveSpeed * 0.5;
          final vy = enemy.velocity.dy + _gravity * dt;
          final result = _moveBody(enemy.position, Offset(vx, vy), enemy.size, dt);
          enemy.position = result.position;
          enemy.velocity = Offset(vx, result.velocity.dy);

          if (enemy.position.dx <= 0) {
            enemy.facingRight = true;
          } else if (enemy.position.dx + enemy.size.width >= worldWidth) {
            enemy.facingRight = false;
          }
          break;

        case EnemyState.frozen:
          final vy = enemy.velocity.dy + _gravity * dt;
          final result = _moveBody(enemy.position, Offset(0, vy), enemy.size, dt);
          enemy.position = result.position;
          enemy.velocity = Offset(0, result.velocity.dy);
          break;

        case EnemyState.snowball:
          final vy = enemy.velocity.dy + _gravity * dt;
          final result = _moveBody(enemy.position, Offset(enemy.velocity.dx, vy), enemy.size, dt);
          enemy.position = result.position;
          enemy.velocity = Offset(enemy.velocity.dx, result.velocity.dy);

          if (enemy.position.dx <= 0 || enemy.position.dx + enemy.size.width >= worldWidth) {
            enemy.velocity = Offset(-enemy.velocity.dx, enemy.velocity.dy);
          }
          break;
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (final projectile in projectiles) {
      projectile.position = projectile.position + projectile.velocity * dt;
      if (projectile.position.dx < -32 || projectile.position.dx > worldWidth + 32) {
        projectile.alive = false;
      }
    }
    projectiles.removeWhere((p) => !p.alive);
  }

  void _resolveCollisions() {
    // Snow projectiles freeze walking enemies; enough hits turn them into a
    // rollable snowball.
    for (final projectile in projectiles) {
      if (!projectile.alive) continue;
      for (final enemy in enemies) {
        if (!enemy.alive || enemy.state == EnemyState.snowball) continue;
        if (projectile.rect.overlaps(enemy.rect)) {
          projectile.alive = false;
          enemy.snowCharge += 1;
          if (enemy.snowCharge >= _snowChargeToFreeze) {
            enemy.state = EnemyState.snowball;
            enemy.velocity = Offset.zero;
          } else {
            enemy.state = EnemyState.frozen;
          }
          break;
        }
      }
    }
    projectiles.removeWhere((p) => !p.alive);

    // Touching a walking/frozen enemy costs a life; touching a still snowball
    // kicks it rolling in the direction the player is facing.
    for (final enemy in enemies) {
      if (!enemy.alive || !player.rect.overlaps(enemy.rect)) continue;

      if (enemy.state == EnemyState.snowball) {
        if (enemy.velocity.dx == 0) {
          enemy.velocity = Offset(player.facingRight ? _snowballSpeed : -_snowballSpeed, enemy.velocity.dy);
        }
      } else if (player.invulnerableSeconds <= 0) {
        _loseLife();
      }
    }

    // A rolling snowball destroys any other enemy it touches.
    for (final ball in enemies) {
      if (!ball.alive || ball.state != EnemyState.snowball || ball.velocity.dx == 0) continue;
      for (final target in enemies) {
        if (identical(target, ball) || !target.alive) continue;
        if (ball.rect.overlaps(target.rect)) {
          target.alive = false;
          ball.alive = false;
          score += 100;
        }
      }
    }
    enemies.removeWhere((e) => !e.alive);
  }

  void _loseLife() {
    player.lives -= 1;
    if (player.lives <= 0) {
      status = GameStatus.lost;
      return;
    }
    player.position = _spawnPoint;
    player.velocity = Offset.zero;
    player.invulnerableSeconds = 2;
  }

  void _checkWinLose() {
    if (status == GameStatus.playing && enemies.every((e) => !e.alive)) {
      status = GameStatus.won;
    }
  }

  /// Moves a rectangular body by `velocity * dt`, resolving axis-aligned
  /// collisions against [platforms] one axis at a time.
  _MoveResult _moveBody(Offset position, Offset velocity, Size size, double dt) {
    bool onGround = false;

    double newX = position.dx + velocity.dx * dt;
    Rect rect = Offset(newX, position.dy) & size;
    for (final platform in platforms) {
      if (!rect.overlaps(platform.rect)) continue;
      if (velocity.dx > 0) {
        newX = platform.rect.left - size.width;
      } else if (velocity.dx < 0) {
        newX = platform.rect.right;
      }
      rect = Offset(newX, position.dy) & size;
    }

    double newY = position.dy + velocity.dy * dt;
    double newVy = velocity.dy;
    rect = Offset(newX, newY) & size;
    for (final platform in platforms) {
      if (!rect.overlaps(platform.rect)) continue;
      if (velocity.dy > 0) {
        newY = platform.rect.top - size.height;
        newVy = 0;
        onGround = true;
      } else if (velocity.dy < 0) {
        newY = platform.rect.bottom;
        newVy = 0;
      }
      rect = Offset(newX, newY) & size;
    }

    return _MoveResult(Offset(newX, newY), Offset(velocity.dx, newVy), onGround);
  }
}
