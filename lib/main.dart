import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameWidget.controlled(gameFactory: ShootingGame.new),
    ),
  );
}

class ShootingGame extends FlameGame
    with PanDetector, TapDetector, HasCollisionDetection {
  late Player player;
  late TextComponent scoreText;
  late TextComponent healthText;
  late TextComponent levelText;
  late TextComponent powerUpText;

  int score = 0;
  int health = 15;
  int level = 1;

  bool isGameOver = false;
  bool bossActive = false;

  double bulletTimer = 0;
  double powerUpActiveTimer = 0;
  double shieldActiveTimer = 0;
  double missileActiveTimer = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(SpaceBackground());

    player = Player();
    add(player);

    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(15, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    healthText = TextComponent(
      text: '❤️ 15',
      position: Vector2(15, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    levelText = TextComponent(
      text: 'LEVEL 1',
      position: Vector2(size.x / 2, 20),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    powerUpText = TextComponent(
      text: '',
      position: Vector2(size.x - 15, 20),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    add(scoreText);
    add(healthText);
    add(levelText);
    add(powerUpText);

    spawnEnemyLoop();
    spawnPowerUpLoop();
  }

  void spawnEnemyLoop() async {
    while (true) {
      if (!isGameOver && !bossActive) {
        int rand = Random().nextInt(100);
        if (level >= 4 && rand < 20 + (level * 2))
          add(TrackingEnemy());
        else if (level >= 2 && rand < 40 + level)
          add(ZombieEnemy());
        else
          add(Enemy());
      }
      int delay = max(100, 800 - (level * 70)); // લેવલ 10 સુધી સ્પીડ મેનેજ કરવા
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  void spawnPowerUpLoop() async {
    while (true) {
      await Future.delayed(const Duration(seconds: 12));
      if (!isGameOver) {
        int rand = Random().nextInt(4);
        if (rand == 0)
          add(PowerUpSpreadShot());
        else if (rand == 1)
          add(PowerUpShield());
        else if (rand == 2)
          add(PowerUpHealth());
        else
          add(PowerUpMissile());
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    bulletTimer += dt;
    double fireRate = max(0.05, 0.15 - (level * 0.01));
    if (bulletTimer > fireRate) {
      shoot();
      bulletTimer = 0;
    }

    if (powerUpActiveTimer > 0) powerUpActiveTimer -= dt;
    if (shieldActiveTimer > 0) shieldActiveTimer -= dt;
    if (missileActiveTimer > 0) missileActiveTimer -= dt;
  }

  // ✅ 1. ફ્રી મૂવમેન્ટ (Free Movement) - આખી સ્ક્રીનમાં ગમે ત્યાં
  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (isGameOver) return;
    player.position.x += info.delta.global.x;
    player.position.y += info.delta.global.y; // ✅ Y અક્ષ પર ફરવાની છૂટ

    // પ્લેયરને સ્ક્રીનની બહાર જતા અટકાવવા
    player.position.x = player.position.x.clamp(30, size.x - 30);
    player.position.y = player.position.y.clamp(50, size.y - 30);
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (isGameOver) resetGame();
  }

  // ✅ 2. 10 લેવલનું શૂટિંગ લોજિક
  void shoot() {
    if (missileActiveTimer > 0) {
      add(HomingMissile(Vector2(player.position.x - 25, player.position.y)));
      add(HomingMissile(Vector2(player.position.x + 25, player.position.y)));
    }

    if (powerUpActiveTimer > 0 || level >= 10) {
      // Level 10 કે પાવર અપ (Ultimate Spread)
      for (double a = -0.8; a <= 0.8; a += 0.15)
        add(
          Bullet(Vector2(player.position.x, player.position.y - 30), angle: a),
        );
    } else if (level >= 8) {
      for (double a = -0.6; a <= 0.6; a += 0.15)
        add(
          Bullet(Vector2(player.position.x, player.position.y - 30), angle: a),
        );
    } else if (level >= 6) {
      for (double a = -0.45; a <= 0.45; a += 0.15)
        add(
          Bullet(Vector2(player.position.x, player.position.y - 30), angle: a),
        );
    } else if (level == 5) {
      for (double a = -0.4; a <= 0.4; a += 0.2)
        add(
          Bullet(Vector2(player.position.x, player.position.y - 30), angle: a),
        );
    } else if (level == 4) {
      add(Bullet(Vector2(player.position.x, player.position.y - 30), angle: 0));
      add(
        Bullet(
          Vector2(player.position.x - 15, player.position.y - 20),
          angle: -0.15,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x + 15, player.position.y - 20),
          angle: 0.15,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x - 25, player.position.y - 10),
          angle: -0.3,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x + 25, player.position.y - 10),
          angle: 0.3,
        ),
      );
    } else if (level == 3) {
      add(
        Bullet(
          Vector2(player.position.x - 10, player.position.y - 30),
          angle: 0,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x + 10, player.position.y - 30),
          angle: 0,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x - 20, player.position.y - 20),
          angle: -0.2,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x + 20, player.position.y - 20),
          angle: 0.2,
        ),
      );
    } else if (level == 2) {
      add(Bullet(Vector2(player.position.x, player.position.y - 30), angle: 0));
      add(
        Bullet(
          Vector2(player.position.x - 15, player.position.y - 20),
          angle: -0.15,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x + 15, player.position.y - 20),
          angle: 0.15,
        ),
      );
    } else {
      add(
        Bullet(
          Vector2(player.position.x - 10, player.position.y - 30),
          angle: 0,
        ),
      );
      add(
        Bullet(
          Vector2(player.position.x + 10, player.position.y - 30),
          angle: 0,
        ),
      );
    }
  }

  void activateSpreadShot() => powerUpActiveTimer = 8.0;

  void activateShield() => shieldActiveTimer = 10.0;

  void activateMissiles() => missileActiveTimer = 10.0;

  void healPlayer() {
    health++;
    healthText.text = '❤️ $health';
    final flash = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.pinkAccent.withOpacity(0.5),
    );
    flash.add(
      OpacityEffect.to(
        0.0,
        EffectController(duration: 0.1, alternate: true, repeatCount: 2),
        onComplete: () => flash.removeFromParent(),
      ),
    );
    add(flash);
  }

  void shakeScreen() => camera.viewfinder.add(
    MoveByEffect(
      Vector2(12, 0),
      EffectController(duration: 0.05, alternate: true, repeatCount: 6),
    ),
  );

  // ✅ 10 લેવલનું અપગ્રેડ લોજિક
  void updateScore(int points) {
    score += points;
    scoreText.text = 'Score: $score';

    int previousLevel = level;
    if (score >= 600)
      level = 10;
    else if (score >= 450)
      level = 9;
    else if (score >= 320)
      level = 8;
    else if (score >= 210)
      level = 7;
    else if (score >= 120)
      level = 6;
    else if (score >= 80)
      level = 5;
    else if (score >= 50)
      level = 4;
    else if (score >= 25)
      level = 3;
    else if (score >= 10)
      level = 2;

    if (level > previousLevel) {
      levelText.text = level == 10 ? 'GOD MODE (LV 10)' : 'LEVEL $level';
      levelText.textRenderer = TextPaint(
        style: TextStyle(
          color: level == 10 ? Colors.yellowAccent : Colors.cyanAccent,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      );
      final flash = RectangleComponent(
        size: size,
        paint: Paint()..color = Colors.white,
      );
      flash.add(
        OpacityEffect.to(
          0.0,
          EffectController(duration: 0.1, alternate: true, repeatCount: 3),
          onComplete: () => flash.removeFromParent(),
        ),
      );
      add(flash);
    }

    if (score > 0 && score % 40 == 0 && !bossActive) {
      bossActive = true;
      add(BossEnemy());
    }
  }

  void damagePlayer() {
    if (isGameOver || shieldActiveTimer > 0) return;
    shakeScreen();
    health--;
    healthText.text = '❤️ $health';
    final damageFlash = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.red.withOpacity(0.4),
    );
    damageFlash.add(
      OpacityEffect.to(
        0.0,
        EffectController(duration: 0.1, alternate: true, repeatCount: 2),
        onComplete: () => damageFlash.removeFromParent(),
      ),
    );
    add(damageFlash);
    if (health <= 0) gameOver();
  }

  void gameOver() {
    isGameOver = true;
    add(
      TextComponent(
        text: 'GAME OVER\nTap to Restart',
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 35,
            color: Colors.red,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.white, blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  void resetGame() {
    children.whereType<Enemy>().forEach((e) => e.removeFromParent());
    children.whereType<ZombieEnemy>().forEach((e) => e.removeFromParent());
    children.whereType<TrackingEnemy>().forEach((e) => e.removeFromParent());
    children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    children.whereType<HomingMissile>().forEach((m) => m.removeFromParent());
    children.whereType<BossEnemy>().forEach((e) => e.removeFromParent());
    children.whereType<BossBullet>().forEach((b) => b.removeFromParent());
    children.whereType<PowerUpSpreadShot>().forEach(
          (p) => p.removeFromParent(),
    );
    children.whereType<PowerUpShield>().forEach((p) => p.removeFromParent());
    children.whereType<PowerUpHealth>().forEach((p) => p.removeFromParent());
    children.whereType<PowerUpMissile>().forEach((p) => p.removeFromParent());
    children.whereType<TextComponent>().forEach((t) {
      if (t.text.contains('GAME OVER')) t.removeFromParent();
    });

    score = 0;
    health = 15;
    level = 1;
    isGameOver = false;
    bossActive = false;
    powerUpActiveTimer = 0;
    shieldActiveTimer = 0;
    missileActiveTimer = 0;

    scoreText.text = 'Score: 0';
    healthText.text = '❤️ 15';
    levelText.text = 'LEVEL 1';
    levelText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.amberAccent,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
    player.position = Vector2(size.x / 2, size.y - 80);
  }
}

class HomingMissile extends PositionComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  Vector2 velocity = Vector2(0, -600);
  PositionComponent? target;

  HomingMissile(Vector2 pos)
      : super(size: Vector2(10, 25), position: pos, anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    double minDistance = double.infinity;
    target = null;
    final allEnemies = gameRef.children
        .where(
          (c) =>
      c is Enemy ||
          c is ZombieEnemy ||
          c is TrackingEnemy ||
          c is BossEnemy,
    )
        .cast<PositionComponent>();
    for (final enemy in allEnemies) {
      double dist = position.distanceTo(enemy.position);
      if (dist < minDistance) {
        minDistance = dist;
        target = enemy;
      }
    }
    if (target != null && !target!.isRemoving) {
      Vector2 desiredVelocity =
          (target!.position - position).normalized() * 700;
      velocity.lerp(desiredVelocity, dt * 6);
      angle = atan2(velocity.y, velocity.x) + (pi / 2);
    } else
      angle = 0;

    position += velocity * dt;
    if (position.y < -50 ||
        position.x < -50 ||
        position.x > gameRef.size.x + 50 ||
        position.y > gameRef.size.y)
      removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.x - 4, size.y - 4),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.orangeAccent,
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y + 5),
      5,
      Paint()
        ..color = Colors.yellow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      removeFromParent();
      other.explode();
      gameRef.updateScore(1);
    } else if (other is ZombieEnemy) {
      removeFromParent();
      other.takeDamage();
    } else if (other is TrackingEnemy) {
      removeFromParent();
      other.takeDamage();
    } else if (other is BossEnemy) {
      removeFromParent();
    }
  }
}

class SpaceBackground extends Component with HasGameRef<ShootingGame> {
  final Random rnd = Random();
  late List<Vector2> stars;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    stars = List.generate(
      100,
          (index) => Vector2(
        rnd.nextDouble() * gameRef.size.x,
        rnd.nextDouble() * gameRef.size.y,
      ),
    );
  }

  @override
  void update(double dt) {
    for (var star in stars) {
      star.y += (50 * gameRef.level) * dt;
      if (star.y > gameRef.size.y) {
        star.y = 0;
        star.x = rnd.nextDouble() * gameRef.size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y),
      Paint()..color = const Color(0xFF070715),
    );
    for (var star in stars)
      canvas.drawCircle(star.toOffset(), 1.5, Paint()..color = Colors.white54);
  }
}

// ✅ 3. 10 અલગ-અલગ પ્લેન ડિઝાઇન (Ship Evolutions)
class Player extends PositionComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  Player() : super(size: Vector2(60, 60), anchor: Anchor.center) {
    add(RectangleHitbox(size: Vector2(40, 50), position: Vector2(10, 5)));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(gameRef.size.x / 2, gameRef.size.y - 80);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (gameRef.shieldActiveTimer > 0) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        45,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
      );
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        45,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    Color bodyColor = const Color(0xFFB0BEC5);
    Color wingColor = const Color(0xFF1976D2);
    Color cockpitColor = Colors.cyanAccent;
    Color fireColor = Colors.orangeAccent;

    if (gameRef.level == 2) {
      bodyColor = Colors.amber;
      wingColor = Colors.deepOrange;
    } else if (gameRef.level == 3) {
      bodyColor = const Color(0xFF212121);
      wingColor = Colors.greenAccent;
      fireColor = Colors.greenAccent;
    } else if (gameRef.level == 4) {
      bodyColor = Colors.white;
      wingColor = Colors.redAccent;
      cockpitColor = Colors.yellowAccent;
      fireColor = Colors.redAccent;
    } else if (gameRef.level == 5) {
      bodyColor = Colors.purpleAccent;
      wingColor = Colors.cyanAccent;
      cockpitColor = Colors.white;
      fireColor = Colors.purpleAccent;
    } else if (gameRef.level == 6) {
      bodyColor = Colors.pinkAccent;
      wingColor = Colors.yellow;
      cockpitColor = Colors.black;
      fireColor = Colors.pink;
    } else if (gameRef.level == 7) {
      bodyColor = Colors.red.shade900;
      wingColor = Colors.black;
      cockpitColor = Colors.red;
      fireColor = Colors.redAccent;
    } else if (gameRef.level == 8) {
      bodyColor = Colors.white;
      wingColor = Colors.blue.shade900;
      cockpitColor = Colors.blueAccent;
      fireColor = Colors.blue;
    } else if (gameRef.level == 9) {
      bodyColor = Colors.lightGreenAccent;
      wingColor = Colors.purple;
      cockpitColor = Colors.green;
      fireColor = Colors.greenAccent;
    } else if (gameRef.level >= 10) {
      bodyColor = Colors.white;
      wingColor = Colors.amberAccent;
      cockpitColor = Colors.white;
      fireColor = Colors.yellowAccent;
    } // GOD MODE

    final paintBody = Paint()..color = bodyColor;
    final paintWings = Paint()..color = wingColor;
    final paintCockpit = Paint()..color = cockpitColor;
    final paintEngine = Paint()..color = const Color(0xFF303030);
    final paintFire = Paint()
      ..color = fireColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    Path wingsPath = Path();
    if (gameRef.level >= 8)
      wingsPath
        ..moveTo(size.x / 2, -10)
        ..lineTo(size.x + 20, size.y)
        ..lineTo(-20, size.y)
        ..close(); // મોટી પાંખો
    else if (gameRef.level >= 4)
      wingsPath
        ..moveTo(size.x / 2, 0)
        ..lineTo(size.x + 10, size.y - 10)
        ..lineTo(-10, size.y - 10)
        ..close();
    else
      wingsPath
        ..moveTo(size.x / 2, 15)
        ..lineTo(size.x, size.y - 15)
        ..lineTo(0, size.y - 15)
        ..close();

    canvas.drawPath(wingsPath, paintWings);
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 12, size.y - 10, 8, 10),
      paintEngine,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 + 4, size.y - 10, 8, 10),
      paintEngine,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x / 2 - 10, 0, 20, size.y - 10),
        const Radius.circular(10),
      ),
      paintBody,
    );
    canvas.drawOval(Rect.fromLTWH(size.x / 2 - 6, 15, 12, 20), paintCockpit);
    canvas.drawCircle(Offset(size.x / 2 - 8, size.y + 2), 6, paintFire);
    canvas.drawCircle(Offset(size.x / 2 + 8, size.y + 2), 6, paintFire);
  }
}

class Bullet extends RectangleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  final double angle;

  Bullet(Vector2 pos, {this.angle = 0})
      : super(
    size: Vector2(4, 30),
    position: pos,
    anchor: Anchor.center,
    paint: Paint()
      ..color = const Color(0xFFFF1A1A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
  ) {
    add(RectangleHitbox());
    this.transform.angle = angle;
  }

  @override
  void update(double dt) {
    super.update(dt);
    double speed = 800 + (gameRef.level * 40);
    if (angle == 0)
      position.y -= speed * dt;
    else {
      position.y -= speed * dt * cos(angle).abs();
      position.x += speed * dt * sin(angle);
    }
    if (position.y < 0 || position.x < 0 || position.x > gameRef.size.x)
      removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      removeFromParent();
      other.explode();
      gameRef.updateScore(1);
    } else if (other is ZombieEnemy) {
      removeFromParent();
      other.takeDamage();
    } else if (other is TrackingEnemy) {
      removeFromParent();
      other.takeDamage();
    } else if (other is BossEnemy) {
      removeFromParent();
    }
  }
}

class Enemy extends CircleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  Enemy()
      : super(
    radius: 20,
    anchor: Anchor.center,
    paint: Paint()..color = Colors.redAccent,
  ) {
    add(CircleHitbox());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 40) + 20, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += (150 + (gameRef.level * 25)) * dt;
    if (position.y > gameRef.size.y) {
      removeFromParent();
      gameRef.damagePlayer();
    }
  }

  void explode() {
    removeFromParent();
    gameRef.add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 20,
          lifespan: 0.5,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, 50),
            speed: Vector2(
              (Random().nextDouble() - 0.5) * 400,
              (Random().nextDouble() - 0.5) * 400,
            ),
            child: CircleParticle(
              radius: 3.0,
              paint: Paint()..color = Colors.orange,
            ),
          ),
        ),
      ),
    );
  }
}

class ZombieEnemy extends PositionComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  double time = 0;
  int hp = 2;

  ZombieEnemy() : super(size: Vector2(40, 40), anchor: Anchor.center) {
    add(CircleHitbox());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 60) + 30, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
    position.y += (120 + (gameRef.level * 20)) * dt;
    position.x += sin(time * 6) * 180 * dt;
    position.x = position.x.clamp(20, gameRef.size.x - 20);
    if (position.y > gameRef.size.y) {
      removeFromParent();
      gameRef.damagePlayer();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      const Offset(20, 20),
      20,
      Paint()..color = hp == 2 ? Colors.green : Colors.lightGreen,
    );
    canvas.drawCircle(const Offset(12, 15), 4, Paint()..color = Colors.black);
    canvas.drawCircle(const Offset(28, 15), 4, Paint()..color = Colors.black);
  }

  void takeDamage() {
    hp--;
    if (hp <= 0) {
      removeFromParent();
      gameRef.updateScore(2);
      gameRef.add(
        ParticleSystemComponent(
          position: position,
          particle: Particle.generate(
            count: 25,
            lifespan: 0.5,
            generator: (i) => AcceleratedParticle(
              speed: Vector2(
                (Random().nextDouble() - 0.5) * 400,
                (Random().nextDouble() - 0.5) * 400,
              ),
              child: CircleParticle(
                radius: 3.0,
                paint: Paint()..color = Colors.greenAccent,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.damagePlayer();
    }
  }
}

class TrackingEnemy extends PositionComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  int hp = 3;

  TrackingEnemy() : super(size: Vector2(30, 30), anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 40) + 20, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += (100 + (gameRef.level * 15)) * dt;
    if (gameRef.player.position.x > position.x)
      position.x += 80 * dt;
    else
      position.x -= 80 * dt;
    if (position.y > gameRef.size.y) {
      removeFromParent();
      gameRef.damagePlayer();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 30, 30),
      Paint()..color = Colors.orange,
    );
    canvas.drawCircle(const Offset(15, 15), 10, Paint()..color = Colors.red);
  }

  void takeDamage() {
    hp--;
    if (hp <= 0) {
      removeFromParent();
      gameRef.updateScore(3);
      gameRef.add(
        ParticleSystemComponent(
          position: position,
          particle: Particle.generate(
            count: 30,
            lifespan: 0.5,
            generator: (i) => AcceleratedParticle(
              speed: Vector2(
                (Random().nextDouble() - 0.5) * 500,
                (Random().nextDouble() - 0.5) * 500,
              ),
              child: CircleParticle(
                radius: 3.0,
                paint: Paint()..color = Colors.redAccent,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.damagePlayer();
    }
  }
}

// ✅ 4. 10 લેવલ માટે સ્માર્ટ અને હાર્ડ BOSS
class BossEnemy extends PositionComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  late int maxHp;
  late int bossHealth;
  late int bossLevel;
  double directionX = 1;
  double shootTimer = 0;

  BossEnemy() : super(size: Vector2(150, 100), anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    bossLevel = gameRef.level;
    maxHp = 50 + (bossLevel * 40); // 10 લેવલ સુધી હેલ્થ જબરદસ્ત વધશે
    bossHealth = maxHp;
    position = Vector2(gameRef.size.x / 2, -50);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (position.y < 120) {
      position.y += 50 * dt;
    } else {
      // બોસ મૂવમેન્ટ
      if (bossLevel >= 6) {
        position.x +=
            (gameRef.player.position.x > position.x ? 1 : -1) *
                120 *
                dt; // પ્લેયરને સતત ફોલો કરશે
      } else if (bossLevel >= 3) {
        position.x += 160 * directionX * dt;
        position.y = 120 + sin(position.x / 40) * 30;
      } else {
        position.x += (100 + (bossLevel * 20)) * directionX * dt;
      }
      if (position.x <= 75 || position.x >= gameRef.size.x - 75)
        directionX *= -1;

      // બોસ શૂટિંગ લોજિક
      shootTimer += dt;
      double fireRate = max(0.15, 0.8 - (bossLevel * 0.1));
      if (shootTimer > fireRate) {
        if (bossLevel >= 8) {
          for (double a = -1.0; a <= 1.0; a += 0.25)
            gameRef.add(
              BossBullet(
                Vector2(position.x, position.y + 30),
                angle: a,
                isUltimate: true,
              ),
            );
        } else if (bossLevel >= 5) {
          for (double a = -0.6; a <= 0.6; a += 0.2)
            gameRef.add(
              BossBullet(
                Vector2(position.x, position.y + 30),
                angle: a,
                isUltimate: true,
              ),
            );
        } else if (bossLevel >= 3) {
          for (double a = -0.3; a <= 0.3; a += 0.2)
            gameRef.add(
              BossBullet(Vector2(position.x, position.y + 30), angle: a),
            );
        } else {
          gameRef.add(BossBullet(Vector2(position.x - 30, position.y + 30)));
          gameRef.add(BossBullet(Vector2(position.x + 30, position.y + 30)));
        }
        shootTimer = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // ડાયનેમિક બોસ ડિઝાઇન
    if (bossLevel >= 8) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        60,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        45,
        Paint()..color = Colors.orangeAccent,
      );
    } else if (bossLevel >= 5) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        50,
        Paint()..color = Colors.cyanAccent,
      );
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        40,
        Paint()..color = Colors.purpleAccent,
      );
    } else if (bossLevel >= 3) {
      Path path = Path()
        ..moveTo(size.x / 2, 0)
        ..lineTo(size.x, size.y)
        ..lineTo(0, size.y)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.black87);
    } else {
      canvas.drawOval(
        Rect.fromLTWH(0, 30, size.x, 70),
        Paint()..color = Colors.deepPurple,
      );
      canvas.drawOval(
        Rect.fromLTWH(30, 0, size.x - 60, 60),
        Paint()..color = Colors.redAccent,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, -15, size.x, 8),
      Paint()..color = Colors.grey,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -15, (bossHealth / maxHp) * size.x, 8),
      Paint()..color = Colors.red,
    );
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet || other is HomingMissile) {
      bossHealth--;
      if (bossHealth <= 0) {
        removeFromParent();
        gameRef.bossActive = false;
        gameRef.updateScore(40);
        gameRef.shakeScreen();
        gameRef.add(
          ParticleSystemComponent(
            position: position,
            particle: Particle.generate(
              count: 80,
              lifespan: 1.5,
              generator: (i) => AcceleratedParticle(
                speed: Vector2(
                  (Random().nextDouble() - 0.5) * 600,
                  (Random().nextDouble() - 0.5) * 600,
                ),
                child: CircleParticle(
                  radius: 5.0,
                  paint: Paint()..color = Colors.purpleAccent,
                ),
              ),
            ),
          ),
        );
      }
    } else if (other is Player) {
      gameRef.health = 0;
      gameRef.damagePlayer();
    }
  }
}

class BossBullet extends CircleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  final double angle;
  final bool isUltimate;

  BossBullet(Vector2 pos, {this.angle = 0, this.isUltimate = false})
      : super(
    radius: isUltimate ? 8 : 6,
    position: pos,
    anchor: Anchor.center,
    paint: Paint()
      ..color = isUltimate ? Colors.cyanAccent : Colors.orangeAccent,
  ) {
    add(CircleHitbox());
    this.transform.angle = angle;
  }

  @override
  void update(double dt) {
    super.update(dt);
    double speed = (300 + (gameRef.level * 30));
    if (isUltimate) speed += 100;
    if (angle == 0)
      position.y += speed * dt;
    else {
      position.y += speed * dt * cos(angle).abs();
      position.x += speed * dt * sin(angle);
    }
    if (position.y > gameRef.size.y ||
        position.x < 0 ||
        position.x > gameRef.size.x)
      removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.damagePlayer();
    }
  }
}

class PowerUpSpreadShot extends CircleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  PowerUpSpreadShot()
      : super(
    radius: 15,
    anchor: Anchor.center,
    paint: Paint()..color = Colors.greenAccent,
  ) {
    add(CircleHitbox());
    add(
      OpacityEffect.to(
        0.3,
        EffectController(duration: 0.5, reverseDuration: 0.5, infinite: true),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 40) + 20, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 100 * dt;
    if (position.y > gameRef.size.y + 20) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.activateSpreadShot();
    }
  }
}

class PowerUpShield extends CircleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  PowerUpShield()
      : super(
    radius: 15,
    anchor: Anchor.center,
    paint: Paint()..color = Colors.cyanAccent,
  ) {
    add(CircleHitbox());
    add(
      OpacityEffect.to(
        0.3,
        EffectController(duration: 0.5, reverseDuration: 0.5, infinite: true),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 40) + 20, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 100 * dt;
    if (position.y > gameRef.size.y + 20) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.activateShield();
    }
  }
}

class PowerUpHealth extends CircleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  PowerUpHealth()
      : super(
    radius: 15,
    anchor: Anchor.center,
    paint: Paint()..color = Colors.pinkAccent,
  ) {
    add(CircleHitbox());
    add(
      OpacityEffect.to(
        0.3,
        EffectController(duration: 0.5, reverseDuration: 0.5, infinite: true),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 40) + 20, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 100 * dt;
    if (position.y > gameRef.size.y + 20) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.healPlayer();
    }
  }
}

class PowerUpMissile extends CircleComponent
    with CollisionCallbacks, HasGameRef<ShootingGame> {
  PowerUpMissile()
      : super(
    radius: 15,
    anchor: Anchor.center,
    paint: Paint()..color = Colors.orangeAccent,
  ) {
    add(CircleHitbox());
    add(
      OpacityEffect.to(
        0.3,
        EffectController(duration: 0.5, reverseDuration: 0.5, infinite: true),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(Random().nextDouble() * (gameRef.size.x - 40) + 20, -30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 100 * dt;
    if (position.y > gameRef.size.y + 20) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      removeFromParent();
      gameRef.activateMissiles();
    }
  }
}

