import { describe, expect, it } from 'vitest';
import { CombatEngine } from './CombatEngine';
import { PHASE1_WAVES, REGIMENT_DEFINITIONS } from './presets';
import type { CombatEvent, CombatSnapshot, PlayerInput, WaveDefinition } from '../types/combat';

function stepMany(
  engine: CombatEngine,
  steps: number,
  dtSec = 0.1,
  input?: Partial<PlayerInput> | ((stepIndex: number, snap: CombatSnapshot) => Partial<PlayerInput>),
): { snapshot: CombatSnapshot; events: CombatEvent[] } {
  const allEvents: CombatEvent[] = [];
  let snapshot = engine.getSnapshot();
  for (let i = 0; i < steps; i += 1) {
    const stepInput = typeof input === 'function' ? input(i, snapshot) : input;
    const res = engine.step(dtSec, stepInput);
    snapshot = res.snapshot;
    allEvents.push(...res.events);
  }
  return { snapshot, events: allEvents };
}

function makeCustomWave(spawns: WaveDefinition['spawns']): WaveDefinition {
  return {
    waveNumber: 99,
    name: '測試波次',
    description: '單元測試專用波次',
    spawns,
  };
}

describe('CombatEngine (GDD v0.2)', () => {
  describe('1. Initial snapshot integrity', () => {
    it('initializes arena, hero, gate, wave telemetry, and selected regiment counts accurately', () => {
      const shieldEngine = new CombatEngine({ regimentType: 'shieldmen', wave: 1, seed: 42 });
      const snap = shieldEngine.getSnapshot();

      expect(snap.status).toBe('running');
      expect(snap.tick).toBe(0);
      expect(snap.elapsedSec).toBe(0);
      expect(snap.arenaWidth).toBe(1080);
      expect(snap.arenaHeight).toBe(600);
      expect(snap.gateX).toBe(80);
      expect(snap.gateHp).toBe(500);
      expect(snap.gateMaxHp).toBe(500);

      expect(snap.waveNumber).toBe(1);
      expect(snap.waveName).toBe(PHASE1_WAVES[0].name);
      const expectedTotal = PHASE1_WAVES[0].spawns.reduce((sum, s) => sum + s.count, 0);
      expect(snap.totalEnemies).toBe(expectedTotal);
      expect(snap.defeatedEnemies).toBe(0);

      expect(snap.hero.alive).toBe(true);
      expect(snap.hero.hp).toBe(snap.hero.maxHp);
      expect(snap.hero.stamina).toBe(snap.hero.maxStamina);
      expect(snap.hero.x).toBeGreaterThan(snap.gateX);

      expect(snap.regiment.type).toBe('shieldmen');
      expect(snap.regiment.maxCount).toBe(REGIMENT_DEFINITIONS.shieldmen.count);
      expect(snap.regiment.aliveCount).toBe(10);
      expect(snap.regiment.soldiers).toHaveLength(10);
      expect(snap.regiment.order).toBe('follow');
      expect(snap.regiment.formation).toBe('compact');

      const archerEngine = new CombatEngine({ regimentType: 'archers', wave: 2 });
      const archerSnap = archerEngine.getSnapshot();
      expect(archerSnap.regiment.type).toBe('archers');
      expect(archerSnap.regiment.aliveCount).toBe(8);
      expect(archerSnap.regiment.soldiers).toHaveLength(8);
      expect(archerSnap.waveNumber).toBe(2);

      const pikeEngine = new CombatEngine({ regimentType: 'pikemen', wave: 3 });
      const pikeSnap = pikeEngine.getSnapshot();
      expect(pikeSnap.regiment.type).toBe('pikemen');
      expect(pikeSnap.regiment.aliveCount).toBe(10);
      expect(pikeSnap.waveNumber).toBe(3);
    });
  });

  describe('2. Hero movement, 3-hit directional melee combo, and dodge i-frames', () => {
    it('moves hero with WASD input and clamps within arena bounds', () => {
      const engine = new CombatEngine({
        regimentType: 'shieldmen',
        wave: makeCustomWave([]),
      });
      // Keep status running by having a late spawn
      const movingEngine = new CombatEngine({
        regimentType: 'shieldmen',
        wave: makeCustomWave([{ type: 'goblin_raider', count: 1, spawnTimeSec: 99 }]),
      });

      const start = movingEngine.getSnapshot().hero;
      const movedRight = stepMany(movingEngine, 10, 0.1, { moveX: 1, moveY: 0.5 });
      expect(movedRight.snapshot.hero.x).toBeGreaterThan(start.x + 100);
      expect(movedRight.snapshot.hero.y).toBeGreaterThan(start.y + 40);

      // Push hard left to test gateX + 16 clamp
      const clampedLeft = stepMany(movingEngine, 40, 0.1, { moveX: -1, moveY: 0 });
      expect(clampedLeft.snapshot.hero.x).toBeGreaterThanOrEqual(
        clampedLeft.snapshot.gateX + 16,
      );

      // Empty wave immediately finishes on first step
      expect(engine.step(0.1).snapshot.status).toBe('victory');
    });

    it('executes 3-hit directional melee cone combo with knockback on hit 3', () => {
      const engine = new CombatEngine({
        regimentType: 'archers',
        wave: makeCustomWave([
          { type: 'shield_orc', count: 1, spawnTimeSec: 0, spawnX: 270, spawnY: 300, hpMultiplier: 3 },
        ]),
      });

      // Keep regiment far away so only hero damages the enemy
      engine.issueRegimentCommand({ type: 'order', order: 'hold', targetX: 100, targetY: 560 });

      // Spawn the enemy
      engine.step(0.05);
      const initialEnemy = engine.getSnapshot().enemies[0];
      expect(initialEnemy).toBeDefined();

      const slashSteps: number[] = [];
      let enemyXBeforeThird = initialEnemy.x;
      let enemyXAfterThird = initialEnemy.x;

      for (let i = 0; i < 30; i += 1) {
        const snap = engine.getSnapshot();
        const enemy = snap.enemies[0];
        if (slashSteps.length === 2) {
          enemyXBeforeThird = enemy.x;
        }
        const res = engine.step(0.1, {
          aimX: enemy.x,
          aimY: enemy.y,
          attackPressed: true,
        });
        for (const ev of res.events) {
          if (ev.type === 'hero_slash') {
            slashSteps.push(ev.comboStep);
            if (ev.comboStep === 2) {
              enemyXAfterThird = res.snapshot.enemies[0].x;
            }
          }
        }
        if (slashSteps.length >= 3) break;
      }

      expect(slashSteps).toEqual([0, 1, 2]);
      expect(engine.getSnapshot().hero.damageDealt).toBeGreaterThan(0);
      expect(enemyXAfterThird).toBeGreaterThan(enemyXBeforeThird);
    });

    it('avoids enemy commander slam damage when hero dodges with i-frames', () => {
      const makeCommanderTest = () => {
        const engine = new CombatEngine({
          regimentType: 'shieldmen',
          wave: makeCustomWave([
            {
              type: 'enemy_commander',
              count: 1,
              spawnTimeSec: 0,
              spawnX: 265,
              spawnY: 300,
              customName: '碎骨隊長',
              telegraphKind: 'cleave',
              telegraphRadius: 110,
            },
          ]),
          seed: 7,
        });
        // Park regiment away so commander targets hero cleanly
        engine.issueRegimentCommand({ type: 'order', order: 'hold', targetX: 100, targetY: 560 });
        return engine;
      };

      // Run A: Hero stands still and eats the slam
      const engineNoDodge = makeCommanderTest();
      let slamSeenA = false;
      let hpBeforeSlamA = 0;
      let hpAfterSlamA = 0;

      for (let i = 0; i < 80; i += 1) {
        const before = engineNoDodge.getSnapshot();
        const res = engineNoDodge.step(0.1);
        if (res.events.some((e) => e.type === 'commander_slam')) {
          slamSeenA = true;
          hpBeforeSlamA = before.hero.hp;
          hpAfterSlamA = res.snapshot.hero.hp;
          break;
        }
      }
      expect(slamSeenA).toBe(true);
      expect(hpAfterSlamA).toBeLessThan(hpBeforeSlamA);

      // Run B: Hero triggers dodge right before slam lands -> i-frames prevent slam damage
      const engineWithDodge = makeCommanderTest();
      let slamSeenB = false;
      let hpBeforeSlamB = 0;
      let hpAfterSlamB = 0;
      let dodged = false;

      for (let i = 0; i < 80; i += 1) {
        const before = engineWithDodge.getSnapshot();
        const commander = before.enemies[0];
        const shouldDodge =
          !dodged &&
          commander?.telegraph !== undefined &&
          commander.telegraph.remainingSec <= 0.22;
        if (shouldDodge) {
          dodged = true;
        }
        const res = engineWithDodge.step(0.1, {
          dodgePressed: shouldDodge,
          moveX: 0,
          moveY: 0,
        });
        if (res.events.some((e) => e.type === 'commander_slam')) {
          slamSeenB = true;
          hpBeforeSlamB = before.hero.hp;
          hpAfterSlamB = res.snapshot.hero.hp;
          break;
        }
      }

      expect(dodged).toBe(true);
      expect(slamSeenB).toBe(true);
      expect(hpAfterSlamB).toBe(hpBeforeSlamB);
    });
  });

  describe('3. Hero skills: 破陣衝鋒 (Q/RMB) & 戰意咆哮 (E)', () => {
    it('executes 破陣衝鋒 dash with damage, knockback, and cooldown', () => {
      const engine = new CombatEngine({
        regimentType: 'shieldmen',
        wave: makeCustomWave([
          { type: 'shield_orc', count: 1, spawnTimeSec: 0, spawnX: 300, spawnY: 300, hpMultiplier: 2 },
        ]),
      });
      engine.issueRegimentCommand({ type: 'order', order: 'hold', targetX: 100, targetY: 560 });
      engine.step(0.05);

      const heroBefore = engine.getSnapshot().hero;
      const enemyBefore = engine.getSnapshot().enemies[0];

      const res = engine.step(0.1, {
        aimX: enemyBefore.x + 120,
        aimY: enemyBefore.y,
        skill1Pressed: true,
      });

      const chargeEvent = res.events.find((e) => e.type === 'hero_charge');
      expect(chargeEvent).toBeDefined();
      expect(res.snapshot.hero.x).toBeGreaterThan(heroBefore.x + 100);
      expect(res.snapshot.hero.skill1CooldownSec).toBeGreaterThan(0);
      expect(res.snapshot.enemies[0].hp).toBeLessThan(enemyBefore.hp);
      expect(res.snapshot.enemies[0].x).toBeGreaterThan(enemyBefore.x);
    });

    it('executes 戰意咆哮 setting warcry buff duration, cooldown, and event', () => {
      const engine = new CombatEngine({
        regimentType: 'shieldmen',
        wave: makeCustomWave([{ type: 'goblin_raider', count: 1, spawnTimeSec: 99 }]),
      });

      const res = engine.step(0.1, { skill2Pressed: true });
      const warcryEvent = res.events.find((e) => e.type === 'hero_warcry');
      expect(warcryEvent).toBeDefined();
      expect(res.snapshot.hero.warcryRemainingSec).toBeGreaterThan(5);
      expect(res.snapshot.hero.skill2CooldownSec).toBeGreaterThan(10);
    });
  });

  describe('4. Hero down & respawn without ending combat', () => {
    it('puts hero into 6s respawn timer when HP reaches 0 and revives at gate without defeat', () => {
      const engine = new CombatEngine({
        regimentType: 'archers',
        wave: makeCustomWave([
          { type: 'berserker', count: 6, spawnTimeSec: 0, spawnX: 250, spawnY: 300 },
          { type: 'goblin_raider', count: 1, spawnTimeSec: 99, spawnX: 900, spawnY: 300 },
        ]),
        gateMaxHp: 2000,
      });
      // Park archers away so berserkers focus hero
      engine.issueRegimentCommand({ type: 'order', order: 'hold', targetX: 100, targetY: 560 });

      let downEventSeen = false;
      let respawnEventSeen = false;

      for (let i = 0; i < 200; i += 1) {
        const res = engine.step(0.1);
        if (res.events.some((e) => e.type === 'hero_down')) {
          downEventSeen = true;
          expect(res.snapshot.hero.alive).toBe(false);
          expect(res.snapshot.hero.respawnRemainingSec).toBeGreaterThan(5);
          expect(res.snapshot.status).toBe('running');
        }
        if (res.events.some((e) => e.type === 'hero_respawn')) {
          respawnEventSeen = true;
          expect(res.snapshot.hero.alive).toBe(true);
          expect(res.snapshot.hero.hp).toBe(res.snapshot.hero.maxHp);
          expect(res.snapshot.hero.x).toBeLessThan(res.snapshot.gateX + 100);
          expect(res.snapshot.status).toBe('running');
          break;
        }
      }

      expect(downEventSeen).toBe(true);
      expect(respawnEventSeen).toBe(true);
    });
  });

  describe('5. Regiment commands: X hold, C follow, 1/2 formation, V engage', () => {
    it('moves soldiers to target anchor on X hold and tracks moving hero on C follow', () => {
      const engine = new CombatEngine({
        regimentType: 'shieldmen',
        wave: makeCustomWave([{ type: 'goblin_raider', count: 1, spawnTimeSec: 99 }]),
      });

      const okHold = engine.issueRegimentCommand({
        type: 'order',
        order: 'hold',
        targetX: 600,
        targetY: 450,
      });
      expect(okHold).toBe(true);

      const afterHold = stepMany(engine, 45, 0.1);
      const avgXHold =
        afterHold.snapshot.regiment.soldiers.reduce((s, u) => s + u.x, 0) /
        afterHold.snapshot.regiment.soldiers.length;
      const avgYHold =
        afterHold.snapshot.regiment.soldiers.reduce((s, u) => s + u.y, 0) /
        afterHold.snapshot.regiment.soldiers.length;

      expect(afterHold.snapshot.regiment.order).toBe('hold');
      expect(Math.abs(avgXHold - 600)).toBeLessThan(45);
      expect(Math.abs(avgYHold - 450)).toBeLessThan(45);

      // Now issue C follow and move hero up-left
      const okFollow = engine.issueRegimentCommand({ type: 'order', order: 'follow' });
      expect(okFollow).toBe(true);

      const afterFollow = stepMany(engine, 40, 0.1, { moveX: -0.5, moveY: -0.8 });
      const hero = afterFollow.snapshot.hero;
      const avgXFollow =
        afterFollow.snapshot.regiment.soldiers.reduce((s, u) => s + u.x, 0) /
        afterFollow.snapshot.regiment.soldiers.length;
      const avgYFollow =
        afterFollow.snapshot.regiment.soldiers.reduce((s, u) => s + u.y, 0) /
        afterFollow.snapshot.regiment.soldiers.length;

      expect(afterFollow.snapshot.regiment.order).toBe('follow');
      expect(Math.hypot(avgXFollow - hero.x, avgYFollow - hero.y)).toBeLessThan(120);
    });

    it('changes soldier formation spacing between compact (1) and spread (2)', () => {
      const engine = new CombatEngine({
        regimentType: 'pikemen',
        wave: makeCustomWave([{ type: 'goblin_raider', count: 1, spawnTimeSec: 99 }]),
      });

      engine.issueRegimentCommand({ type: 'order', order: 'hold', targetX: 400, targetY: 300 });
      engine.issueRegimentCommand({ type: 'formation', formation: 'compact' });
      const compactSnap = stepMany(engine, 25, 0.1).snapshot;
      const compactYSpan =
        Math.max(...compactSnap.regiment.soldiers.map((s) => s.slotY)) -
        Math.min(...compactSnap.regiment.soldiers.map((s) => s.slotY));

      engine.issueRegimentCommand({ type: 'formation', formation: 'spread' });
      const spreadSnap = stepMany(engine, 25, 0.1).snapshot;
      const spreadYSpan =
        Math.max(...spreadSnap.regiment.soldiers.map((s) => s.slotY)) -
        Math.min(...spreadSnap.regiment.soldiers.map((s) => s.slotY));

      expect(spreadSnap.regiment.formation).toBe('spread');
      expect(spreadYSpan).toBeGreaterThan(compactYSpan * 1.4);
    });

    it('seeks and engages enemies when ordered V engage', () => {
      const engine = new CombatEngine({
        regimentType: 'pikemen',
        wave: makeCustomWave([
          { type: 'skeleton_archer', count: 2, spawnTimeSec: 0, spawnX: 700, spawnY: 300 },
        ]),
      });
      engine.step(0.05);
      const startAvgX =
        engine.getSnapshot().regiment.soldiers.reduce((s, u) => s + u.x, 0) / 10;

      engine.issueRegimentCommand({ type: 'order', order: 'engage' });
      const afterEngage = stepMany(engine, 30, 0.1);
      const endAvgX =
        afterEngage.snapshot.regiment.soldiers.reduce((s, u) => s + u.x, 0) / 10;

      expect(afterEngage.snapshot.regiment.order).toBe('engage');
      expect(endAvgX).toBeGreaterThan(startAvgX + 120);
    });
  });

  describe('6. All 3 regiment F skills work distinctly', () => {
    it('shieldmen F (盾擊衝鋒) surges soldiers forward and knocks back enemies', () => {
      const engine = new CombatEngine({
        regimentType: 'shieldmen',
        wave: makeCustomWave([
          { type: 'shield_orc', count: 2, spawnTimeSec: 0, spawnX: 250, spawnY: 300, hpMultiplier: 2 },
        ]),
      });
      engine.step(0.05);
      const hpBefore = engine.getSnapshot().enemies.reduce((s, e) => s + e.hp, 0);

      const issued = engine.issueRegimentCommand({ type: 'skill', targetX: 400, targetY: 300 });
      expect(issued).toBe(true);
      expect(engine.getSnapshot().regiment.skillCooldownSec).toBeGreaterThan(0);
      // Cannot double-cast while on CD
      expect(engine.issueRegimentCommand({ type: 'skill', targetX: 400, targetY: 300 })).toBe(false);

      const after = stepMany(engine, 8, 0.1);
      const hpAfter = after.snapshot.enemies.reduce((s, e) => s + e.hp, 0);
      expect(hpAfter).toBeLessThan(hpBefore);
    });

    it('pikemen F (疾風突刺) deals directional piercing burst damage', () => {
      const engine = new CombatEngine({
        regimentType: 'pikemen',
        wave: makeCustomWave([
          { type: 'shield_orc', count: 2, spawnTimeSec: 0, spawnX: 235, spawnY: 300, hpMultiplier: 2 },
        ]),
      });
      engine.step(0.05);
      const hpBefore = engine.getSnapshot().enemies.reduce((s, e) => s + e.hp, 0);

      const issued = engine.issueRegimentCommand({ type: 'skill', targetX: 350, targetY: 300 });
      expect(issued).toBe(true);

      const after = engine.step(0.1);
      const hpAfter = after.snapshot.enemies.reduce((s, e) => s + e.hp, 0);
      expect(hpAfter).toBeLessThan(hpBefore);
      expect(after.events.some((e) => e.type === 'regiment_command' && e.commandType === 'skill')).toBe(
        true,
      );
    });

    it('archers F (指定箭雨) spawns a PendingVolley that resolves into volley_impact and damages enemies', () => {
      const engine = new CombatEngine({
        regimentType: 'archers',
        wave: makeCustomWave([
          { type: 'goblin_raider', count: 3, spawnTimeSec: 0, spawnX: 650, spawnY: 300 },
        ]),
      });
      engine.step(0.05);

      const issued = engine.issueRegimentCommand({ type: 'skill', targetX: 650, targetY: 300 });
      expect(issued).toBe(true);
      expect(engine.getSnapshot().pendingVolleys).toHaveLength(1);
      expect(engine.getSnapshot().pendingVolleys[0].radius).toBe(95);

      const hpBefore = engine.getSnapshot().enemies.reduce((s, e) => s + e.hp, 0);
      const after = stepMany(engine, 12, 0.1);

      expect(after.events.some((e) => e.type === 'volley_impact')).toBe(true);
      expect(after.snapshot.pendingVolleys).toHaveLength(0);
      const hpAfter = after.snapshot.enemies.reduce((s, e) => s + e.hp, 0);
      expect(hpAfter).toBeLessThan(hpBefore);
    });
  });

  describe('7. Victory and Defeat conditions', () => {
    it('ends in defeat when gate HP reaches 0', () => {
      const engine = new CombatEngine({
        regimentType: 'archers',
        wave: makeCustomWave([
          { type: 'shield_orc', count: 4, spawnTimeSec: 0, spawnX: 115, spawnY: 300 },
        ]),
        gateMaxHp: 80,
      });
      // Move hero & regiment far away so enemies breach the gate
      engine.issueRegimentCommand({ type: 'order', order: 'hold', targetX: 980, targetY: 550 });

      const result = stepMany(engine, 60, 0.1, { moveX: 1, moveY: 1 });
      expect(result.snapshot.status).toBe('defeat');
      expect(result.snapshot.gateHp).toBe(0);
      expect(result.events.some((e) => e.type === 'gate_hit')).toBe(true);
      expect(
        result.events.some((e) => e.type === 'combat_ended' && e.status === 'defeat'),
      ).toBe(true);
    });

    it('ends in victory when all wave enemies are spawned and defeated with gate intact', () => {
      const engine = new CombatEngine({
        regimentType: 'pikemen',
        wave: makeCustomWave([
          { type: 'goblin_raider', count: 3, spawnTimeSec: 0, spawnX: 280, spawnY: 300 },
        ]),
      });
      engine.issueRegimentCommand({ type: 'order', order: 'engage' });

      const result = stepMany(engine, 100, 0.1, (_i, snap) => {
        const target = snap.enemies.find((e) => e.alive);
        if (!target) return {};
        return {
          moveX: Math.sign(target.x - snap.hero.x),
          moveY: Math.sign(target.y - snap.hero.y),
          aimX: target.x,
          aimY: target.y,
          attackPressed: true,
        };
      });

      expect(result.snapshot.status).toBe('victory');
      expect(result.snapshot.gateHp).toBeGreaterThan(0);
      expect(result.snapshot.defeatedEnemies).toBe(3);
      expect(
        result.events.some((e) => e.type === 'combat_ended' && e.status === 'victory'),
      ).toBe(true);
    });
  });
});
