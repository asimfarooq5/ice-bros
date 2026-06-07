import 'dart:ui';

enum EnemyState { walking, frozen, snowball }

enum GameStatus { playing, won, lost }

class Platform {
  final Rect rect;
  const Platform(this.rect);
}

class Player {
  Offset position;
  Offset velocity;
  Size size;
  bool facingRight;
  bool onGround;
  int lives;
  double invulnerableSeconds;

  Player({
    required this.position,
    this.velocity = Offset.zero,
    this.size = const Size(34, 48),
    this.facingRight = true,
    this.onGround = false,
    this.lives = 3,
    this.invulnerableSeconds = 0,
  });

  Rect get rect => position & size;
}

class Enemy {
  Offset position;
  Offset velocity;
  Size size;
  EnemyState state;
  double snowCharge;
  bool facingRight;
  bool alive;

  Enemy({
    required this.position,
    this.velocity = const Offset(-50, 0),
    this.size = const Size(34, 34),
    this.state = EnemyState.walking,
    this.snowCharge = 0,
    this.facingRight = false,
    this.alive = true,
  });

  Rect get rect => position & size;
}

class SnowProjectile {
  Offset position;
  Offset velocity;
  Size size;
  bool alive;

  SnowProjectile({
    required this.position,
    required this.velocity,
    this.size = const Size(16, 16),
    this.alive = true,
  });

  Rect get rect => position & size;
}
