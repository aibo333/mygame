import { describe, expect, it } from 'vitest';
import { CombatEngine } from './CombatEngine';
import { DEFAULT_SQUAD, PHASE1_WAVES, STANCE_MODIFIERS } from './presets';
import type { CombatEvent, HeroDefinition, WaveDefinition } from '../types/combat';

function stepForSeconds(
  engine: CombatEngine,
  seconds: number,
  dt = 0.05,
): CombatEvent[] {
  const allEvents: CombatEvent[] = [];
  const steps = Math.round(seconds / dt);
  for (let i = 0; i < steps; i += 1) {
    const { events } = engine.step(dt);
    allEvents.push(...events);
    if (engine.getSnapshot().status !== 'running') {
      break;
    }
  }
  return allEvents;
}

describe('CombatEngine', () => {
  describe('1. Initial snapshot integrity', () => {
    it('initializes 3-hero squad, gate HP, stance, skills, and wave telemetry', () => {
      const engine = new CombatEngine({ wave: PHASE1_WAVES[0], seed: 42 });
      const snap = engine.getSnapshot();

      expect(snap.status).toBe('running');
      expect(snap.arenaWidth).toBe(960);
      expect(snap.arenaHeight).toBe(540);
      expect(snap.gateX).toBe(72);
      expect(snap.gateHp).toBe(300);
      expect(snap.gateMaxHp).toBe(300);
      expect(snap.stance).toBe('defense');
      expect(snap.stanceCooldownRemainingSec).toBe(0);
      expect(snap.stanceCooldownSec).toBe(4);

      expect(snap.wave.id).toBe('wave-1');
      expect(snap.wave.totalEnemies).toBe(PHASE1_WAVES[0].spawns.length);
      expect(snap.wave.spawnedEnemies).toBe(0);
      expect(snap.wave.defeatedEnemies).toBe(0);
      expect(snap.wave.aliveEnemies).toBe(0);

      expect(snap.heroes).toHaveLength(3);
      const roles = snap.heroes.map((h) => h.role);
      expect(roles).toEqual(['tank', 'dps', 'support']);

      const tank = snap.heroes[0];
      const dps = snap.heroes[1];
      const support = snap.heroes[2];

      expect(tank.name).toBe('艾莉絲');
      expect(tank.skills[0].chargesRemaining).toBeNull();
      expect(tank.skills[1].chargesRemaining).toBe(2);

      expect(dps.name).toBe('莉娜');
      expect(dps.skills[0].chargesRemaining).toBeNull();
      expect(dps.skills[1].chargesRemaining).toBe(2);

      expect(support.name).toBe('米婭');
      expect(support.skills[0].chargesRemaining).toBeNull();
      expect(support.skills[1].chargesRemaining).toBe(1);
    });

    it('returns an immutable snapshot copy so external mutation does not corrupt engine state', () => {
      const engine = new CombatEngine({ wave: PHASE1_WAVES[0], seed: 42 });
      const snap = engine.getSnapshot();
      snap.gateHp = 1;
      snap.heroes[0].hp = 1;

      const fresh = engine.getSnapshot();
      expect(fresh.gateHp).toBe(300);
      expect(fresh.heroes[0].hp).toBe(DEFAULT_SQUAD[0].maxHp);
    });
  });

  describe('2. Stance switching & cooldown enforcement', () => {
    it('accepts valid stance switch, enforces cooldown, rejects same stance, and re-enables after cooldown', () => {
      const engine = new CombatEngine({
        wave: PHASE1_WAVES[0],
        stanceCooldownSec: 4,
        seed: 7,
      });

      const sameRes = engine.setStance('defense');
      expect(sameRes.accepted).toBe(false);
      expect(sameRes.reason).toBe('same_stance');

      const switchRes = engine.setStance('assault');
      expect(switchRes.accepted).toBe(true);
      expect(switchRes.currentStance).toBe('assault');
      expect(switchRes.cooldownRemainingSec).toBe(4);
      expect(switchRes.event).toMatchObject({
        type: 'stance_changed',
        previousStance: 'defense',
        nextStance: 'assault',
      });

      stepForSeconds(engine, 2.0);
      const blockedRes = engine.setStance('scatter');
      expect(blockedRes.accepted).toBe(false);
      expect(blockedRes.reason).toBe('cooldown');
      expect(blockedRes.currentStance).toBe('assault');
      expect(blockedRes.cooldownRemainingSec).toBeGreaterThan(1.5);

      stepForSeconds(engine, 2.1);
      const allowedRes = engine.setStance('scatter');
      expect(allowedRes.accepted).toBe(true);
      expect(allowedRes.currentStance).toBe('scatter');
      expect(allowedRes.cooldownRemainingSec).toBe(4);
    });
  });

  describe('3. Skill CD, per-wave charge limits, and trigger conditions', () => {
    it('fires Support Miracle Prayer only when an ally drops below 45% HP and never exceeds its 1 charge per wave', () => {
      const gentleWave: WaveDefinition = {
        id: 'test-gentle',
        waveNumber: 1,
        name: '微弱試探',
        description: '單隻哥布林測試',
        recommendedStanceHint: '',
        spawns: [{ spawnTimeSec: 0, archetype: 'goblin', laneY: 270, spawnX: 310 }],
      };

      const gentleEngine = new CombatEngine({ wave: gentleWave, seed: 101 });
      const gentleEvents = stepForSeconds(gentleEngine, 4);
      const gentleMiracles = gentleEvents.filter(
        (e) => e.type === 'skill_cast' && e.skillId === 'skill-miracle-prayer',
      );
      expect(gentleMiracles).toHaveLength(0);
      expect(gentleEngine.getSnapshot().heroes[2].skills[1].chargesRemaining).toBe(1);

      // Now face a sustained high-damage wave where Tank drops below 45% HP multiple times
      const testSquad: HeroDefinition[] = [
        { ...DEFAULT_SQUAD[0], skills: [] }, // isolate Support's Miracle Prayer trigger
        { ...DEFAULT_SQUAD[1], atk: 10, skills: [] },
        { ...DEFAULT_SQUAD[2] },
      ];
      const brutalWave: WaveDefinition = {
        id: 'test-brutal',
        waveNumber: 1,
        name: '高壓測試',
        description: '狂戰士持續高壓測試',
        recommendedStanceHint: '',
        spawns: [
          { spawnTimeSec: 0, archetype: 'brute', laneY: 255, spawnX: 430 },
          { spawnTimeSec: 0, archetype: 'brute', laneY: 285, spawnX: 430 },
          { spawnTimeSec: 0.2, archetype: 'brute', laneY: 270, spawnX: 450 },
        ],
      };

      const brutalEngine = new CombatEngine({
        wave: brutalWave,
        squad: testSquad,
        initialStance: 'assault',
        seed: 202,
      });

      const events = stepForSeconds(brutalEngine, 25);
      const miracleCasts = events.filter(
        (e) => e.type === 'skill_cast' && e.skillId === 'skill-miracle-prayer',
      );
      expect(miracleCasts).toHaveLength(1);

      const support = brutalEngine.getSnapshot().heroes[2];
      expect(support.skills[1].chargesRemaining).toBe(0);
      expect(support.skills[1].timesCast).toBe(1);
    });

    it('fires DPS Starfall Volley only on elite or multiple enemies and respects its 2-charge limit', () => {
      const singleGoblinWave: WaveDefinition = {
        id: 'test-single-goblin',
        waveNumber: 1,
        name: '單隻哥布林',
        description: '',
        recommendedStanceHint: '',
        spawns: [{ spawnTimeSec: 0, archetype: 'goblin', laneY: 270, spawnX: 360 }],
      };

      const singleEngine = new CombatEngine({ wave: singleGoblinWave, seed: 11 });
      const singleEvents = stepForSeconds(singleEngine, 6);
      const singleVolleys = singleEvents.filter(
        (e) => e.type === 'skill_cast' && e.skillId === 'skill-starfall-volley',
      );
      expect(singleVolleys).toHaveLength(0);

      const eliteWave: WaveDefinition = {
        id: 'test-elite',
        waveNumber: 1,
        name: '菁英測試',
        description: '',
        recommendedStanceHint: '',
        spawns: [
          { spawnTimeSec: 0, archetype: 'brute', laneY: 270, spawnX: 380 },
          { spawnTimeSec: 8, archetype: 'brute', laneY: 270, spawnX: 380 },
          { spawnTimeSec: 16, archetype: 'brute', laneY: 270, spawnX: 380 },
        ],
      };

      const eliteEngine = new CombatEngine({ wave: eliteWave, seed: 11 });
      const eliteEvents = stepForSeconds(eliteEngine, 35);
      const eliteVolleys = eliteEvents.filter(
        (e) => e.type === 'skill_cast' && e.skillId === 'skill-starfall-volley',
      );
      expect(eliteVolleys.length).toBeGreaterThanOrEqual(1);
      expect(eliteVolleys.length).toBeLessThanOrEqual(2);
      expect(eliteEngine.getSnapshot().heroes[1].skills[1].chargesRemaining).toBe(
        2 - eliteVolleys.length,
      );
    });
  });

  describe('4. Stance tactical differences', () => {
    it('assault increases DPS damage output and focus-fires the highest threatPriority enemy', () => {
      const mixedThreatWave: WaveDefinition = {
        id: 'test-threat',
        waveNumber: 1,
        name: '威脅度測試',
        description: '',
        recommendedStanceHint: '',
        spawns: [
          { spawnTimeSec: 0, archetype: 'goblin', laneY: 270, spawnX: 430 },
          { spawnTimeSec: 0, archetype: 'archer', laneY: 270, spawnX: 480 },
        ],
      };

      const threatEngine = new CombatEngine({
        wave: mixedThreatWave,
        initialStance: 'assault',
        seed: 55,
      });

      const threatEvents = stepForSeconds(threatEngine, 2.0);
      const dpsAssaultHits = threatEvents.filter(
        (e): e is Extract<CombatEvent, { type: 'damage' }> =>
          e.type === 'damage' && e.sourceId === 'hero-dps-lina' && !e.isAoe,
      );
      expect(dpsAssaultHits.length).toBeGreaterThan(0);

      const archerEnemy = threatEngine
        .getSnapshot()
        .enemies.find((e) => e.archetype === 'archer');
      expect(archerEnemy).toBeDefined();
      expect(dpsAssaultHits[0].targetId).toBe(archerEnemy!.id);

      // Compare sustained DPS damage against high-HP brutes (zero crit to isolate stance multipliers)
      const noCritSquad: HeroDefinition[] = DEFAULT_SQUAD.map((h) => ({
        ...h,
        critChance: 0,
      }));
      const sustainedWave: WaveDefinition = {
        id: 'test-dps-output',
        waveNumber: 1,
        name: '輸出對比',
        description: '',
        recommendedStanceHint: '',
        spawns: [
          { spawnTimeSec: 0, archetype: 'brute', laneY: 270, spawnX: 420 },
          { spawnTimeSec: 0, archetype: 'brute', laneY: 290, spawnX: 440 },
        ],
      };

      const assaultEngine = new CombatEngine({
        wave: sustainedWave,
        squad: noCritSquad,
        initialStance: 'assault',
        seed: 55,
      });
      const defenseEngine = new CombatEngine({
        wave: sustainedWave,
        squad: noCritSquad,
        initialStance: 'defense',
        seed: 55,
      });

      stepForSeconds(assaultEngine, 3.5);
      stepForSeconds(defenseEngine, 3.5);

      // assault (+28% ATK, +20% attackSpeed) vs defense (-12% DPS damage)
      const assaultDpsDamage = assaultEngine.getSnapshot().heroes[1].stats.damageDealt;
      const defenseDpsDamage = defenseEngine.getSnapshot().heroes[1].stats.damageDealt;
      expect(assaultDpsDamage).toBeGreaterThan(defenseDpsDamage * 1.4);
    });

    it('defense reduces incoming damage taken and boosts Support healing by +25%', () => {
      // Disable Tank's shield skill here so Tank takes direct HP damage and Support heals immediately
      const noShieldSquad: HeroDefinition[] = [
        { ...DEFAULT_SQUAD[0], skills: [] },
        { ...DEFAULT_SQUAD[1], atk: 1, skills: [] },
        { ...DEFAULT_SQUAD[2] },
      ];

      const pressureWave: WaveDefinition = {
        id: 'test-pressure',
        waveNumber: 1,
        name: '防禦與治療測試',
        description: '',
        recommendedStanceHint: '',
        spawns: [
          { spawnTimeSec: 0, archetype: 'brute', laneY: 260, spawnX: 430 },
          { spawnTimeSec: 0, archetype: 'brute', laneY: 280, spawnX: 430 },
        ],
      };

      const defenseEngine = new CombatEngine({
        wave: pressureWave,
        squad: noShieldSquad,
        initialStance: 'defense',
        seed: 77,
      });
      const assaultEngine = new CombatEngine({
        wave: pressureWave,
        squad: noShieldSquad,
        initialStance: 'assault',
        seed: 77,
      });

      const defEvents = stepForSeconds(defenseEngine, 10.0);
      const atkEvents = stepForSeconds(assaultEngine, 10.0);

      const defEnemyHits = defEvents.filter(
        (e): e is Extract<CombatEvent, { type: 'damage' }> =>
          e.type === 'damage' && e.sourceTeam === 'enemy',
      );
      const atkEnemyHits = atkEvents.filter(
        (e): e is Extract<CombatEvent, { type: 'damage' }> =>
          e.type === 'damage' && e.sourceTeam === 'enemy',
      );

      expect(defEnemyHits.length).toBeGreaterThan(0);
      expect(atkEnemyHits.length).toBeGreaterThan(0);
      expect(defEnemyHits[0].amount).toBeLessThan(atkEnemyHits[0].amount);

      // Compare single-target Healing Light amount between defense (+25%) and assault (100%)
      const defHeals = defEvents.filter(
        (e): e is Extract<CombatEvent, { type: 'heal' }> =>
          e.type === 'heal' && e.skillId === 'skill-healing-light',
      );
      const atkHeals = atkEvents.filter(
        (e): e is Extract<CombatEvent, { type: 'heal' }> =>
          e.type === 'heal' && e.skillId === 'skill-healing-light',
      );

      expect(defHeals.length).toBeGreaterThan(0);
      expect(atkHeals.length).toBeGreaterThan(0);
      // Base heal is 88 -> defense = 110, assault = 88 (when target has enough missing HP)
      const maxDefHeal = Math.max(...defHeals.map((h) => h.amount));
      const maxAtkHeal = Math.max(...atkHeals.map((h) => h.amount));
      expect(maxDefHeal).toBeGreaterThan(maxAtkHeal);
      expect(STANCE_MODIFIERS.defense.healMultiplier).toBe(1.25);
    });

    it('scatter reduces incoming AOE damage from bombers compared to defense and assault', () => {
      // Single Tank hero right next to an explosive bomber to isolate AOE damage formula
      const soloTank: HeroDefinition[] = [
        {
          ...DEFAULT_SQUAD[0],
          atk: 1, // ensure bomber reaches and explodes
          skills: [],
        },
      ];

      const bomberWave: WaveDefinition = {
        id: 'test-bomber',
        waveNumber: 1,
        name: '自爆測試',
        description: '',
        recommendedStanceHint: '',
        spawns: [{ spawnTimeSec: 0, archetype: 'bomber', laneY: 270, spawnX: 300 }],
      };

      const scatterEngine = new CombatEngine({
        wave: bomberWave,
        squad: soloTank,
        initialStance: 'scatter',
        seed: 99,
      });
      const defenseEngine = new CombatEngine({
        wave: bomberWave,
        squad: soloTank,
        initialStance: 'defense',
        seed: 99,
      });

      const scatterEvents = stepForSeconds(scatterEngine, 4.0);
      const defenseEvents = stepForSeconds(defenseEngine, 4.0);

      const scatterAoe = scatterEvents.find(
        (e): e is Extract<CombatEvent, { type: 'damage' }> =>
          e.type === 'damage' && e.sourceTeam === 'enemy' && e.isAoe,
      );
      const defenseAoe = defenseEvents.find(
        (e): e is Extract<CombatEvent, { type: 'damage' }> =>
          e.type === 'damage' && e.sourceTeam === 'enemy' && e.isAoe,
      );

      expect(scatterAoe).toBeDefined();
      expect(defenseAoe).toBeDefined();
      // Scatter takes 0.60x AOE damage vs defense 0.75x
      expect(scatterAoe!.amount).toBeLessThan(defenseAoe!.amount);
    });
  });

  describe('5. Gate breach & defeat condition', () => {
    it('transitions to defeat and emits combat_ended when gate HP reaches 0', () => {
      const breachWave: WaveDefinition = {
        id: 'test-breach',
        waveNumber: 1,
        name: '破門測試',
        description: '',
        recommendedStanceHint: '',
        spawns: [
          { spawnTimeSec: 0, archetype: 'goblin', laneY: 100, spawnX: 140 },
          { spawnTimeSec: 0, archetype: 'goblin', laneY: 440, spawnX: 140 },
        ],
      };

      const engine = new CombatEngine({
        wave: breachWave,
        squad: [],
        gateMaxHp: 40,
        seed: 33,
      });

      const events = stepForSeconds(engine, 10);
      const snap = engine.getSnapshot();

      expect(snap.status).toBe('defeat');
      expect(snap.gateHp).toBe(0);

      const gateHits = events.filter((e) => e.type === 'gate_hit');
      expect(gateHits.length).toBeGreaterThan(0);

      const endEvent = events.find((e) => e.type === 'combat_ended');
      expect(endEvent).toMatchObject({
        type: 'combat_ended',
        status: 'defeat',
        gateHpRemaining: 0,
      });

      // Subsequent steps and stance changes are no-ops
      const postStep = engine.step(0.05);
      expect(postStep.events).toHaveLength(0);
      expect(engine.setStance('assault')).toMatchObject({
        accepted: false,
        reason: 'combat_ended',
      });
    });
  });

  describe('6. Full wave clear, victory condition, and determinism', () => {
    it('clears Wave 1 with gate intact, emits victory, and is 100% deterministic with same seed', () => {
      const runWave1 = () => {
        const engine = new CombatEngine({
          wave: PHASE1_WAVES[0],
          initialStance: 'defense',
          seed: 1337,
        });
        const events = stepForSeconds(engine, 45);
        return { snapshot: engine.getSnapshot(), events };
      };

      const runA = runWave1();
      const runB = runWave1();

      expect(runA.snapshot.status).toBe('victory');
      expect(runA.snapshot.gateHp).toBeGreaterThan(0);
      expect(runA.snapshot.wave.spawnedEnemies).toBe(runA.snapshot.wave.totalEnemies);
      expect(runA.snapshot.wave.defeatedEnemies).toBe(runA.snapshot.wave.totalEnemies);
      expect(runA.snapshot.wave.aliveEnemies).toBe(0);

      const endEvent = runA.events.find((e) => e.type === 'combat_ended');
      expect(endEvent).toMatchObject({
        type: 'combat_ended',
        status: 'victory',
        totalKills: PHASE1_WAVES[0].spawns.length,
      });

      // Deterministic check
      expect(runA.snapshot).toEqual(runB.snapshot);
      expect(runA.events).toEqual(runB.events);
    });
  });
});
