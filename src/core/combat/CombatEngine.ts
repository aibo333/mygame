import {
  DEFAULT_ARENA_HEIGHT,
  DEFAULT_ARENA_WIDTH,
  DEFAULT_GATE_MAX_HP,
  DEFAULT_GATE_X,
  DEFAULT_SQUAD,
  DEFAULT_STANCE_COOLDOWN_SEC,
  ENEMY_DEFINITIONS,
  PHASE1_WAVES,
  STANCE_MODIFIERS,
} from './presets';
import type {
  CombatConfig,
  CombatEvent,
  CombatSnapshot,
  CombatStatus,
  CombatTickResult,
  EnemyState,
  HeroDefinition,
  HeroState,
  SkillDefinition,
  SkillRuntimeState,
  SquadRole,
  StanceChangeResult,
  TacticalStance,
  Vec2,
  WaveDefinition,
  WaveSpawnEntry,
} from '../types/combat';

interface ScheduledSpawn {
  entry: WaveSpawnEntry;
  spawned: boolean;
}

function createSeededRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function distance(ax: number, ay: number, bx: number, by: number): number {
  const dx = bx - ax;
  const dy = by - ay;
  return Math.hypot(dx, dy);
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function cloneHero(hero: HeroState): HeroState {
  return {
    ...hero,
    skills: hero.skills.map((s) => ({ ...s })),
    stats: { ...hero.stats },
  };
}

function cloneEnemy(enemy: EnemyState): EnemyState {
  return { ...enemy };
}

export class CombatEngine {
  private readonly arenaWidth: number;
  private readonly arenaHeight: number;
  private readonly gateX: number;
  private readonly gateMaxHp: number;
  private readonly stanceCooldownSec: number;
  private readonly wave: WaveDefinition;
  private readonly scheduledSpawns: ScheduledSpawn[];
  private readonly skillDefsById = new Map<string, SkillDefinition>();
  private readonly nextRandom: () => number;

  private tick = 0;
  private elapsedSec = 0;
  private status: CombatStatus = 'running';
  private gateHp: number;
  private stance: TacticalStance;
  private stanceCooldownRemainingSec = 0;
  private enemySerial = 0;

  private heroes: HeroState[];
  private enemies: EnemyState[] = [];

  constructor(config: CombatConfig = {}) {
    this.arenaWidth = config.arenaWidth ?? DEFAULT_ARENA_WIDTH;
    this.arenaHeight = config.arenaHeight ?? DEFAULT_ARENA_HEIGHT;
    this.gateX = config.gateX ?? DEFAULT_GATE_X;
    this.gateMaxHp = config.gateMaxHp ?? DEFAULT_GATE_MAX_HP;
    this.gateHp = this.gateMaxHp;
    this.stanceCooldownSec = config.stanceCooldownSec ?? DEFAULT_STANCE_COOLDOWN_SEC;
    this.stance = config.initialStance ?? 'defense';
    this.wave = config.wave ?? PHASE1_WAVES[0];
    this.nextRandom = createSeededRng(config.seed ?? 1337);

    this.scheduledSpawns = this.wave.spawns
      .map((entry) => ({ entry: { ...entry }, spawned: false }))
      .sort((a, b) => a.entry.spawnTimeSec - b.entry.spawnTimeSec);

    const squadDefs = config.squad ?? DEFAULT_SQUAD;
    this.heroes = squadDefs.map((def, index) => this.createHeroState(def, index));
  }

  public getSnapshot(): CombatSnapshot {
    const spawnedEnemies = this.enemies.length;
    const aliveEnemies = this.enemies.filter((e) => e.alive).length;
    const defeatedEnemies = spawnedEnemies - aliveEnemies;
    const totalDamageDealt = this.heroes.reduce((sum, h) => sum + h.stats.damageDealt, 0);
    const totalHealingDone = this.heroes.reduce((sum, h) => sum + h.stats.healingDone, 0);

    return {
      tick: this.tick,
      elapsedSec: this.elapsedSec,
      status: this.status,
      arenaWidth: this.arenaWidth,
      arenaHeight: this.arenaHeight,
      gateX: this.gateX,
      gateHp: this.gateHp,
      gateMaxHp: this.gateMaxHp,
      stance: this.stance,
      stanceCooldownRemainingSec: this.stanceCooldownRemainingSec,
      stanceCooldownSec: this.stanceCooldownSec,
      wave: {
        id: this.wave.id,
        waveNumber: this.wave.waveNumber,
        name: this.wave.name,
        totalEnemies: this.scheduledSpawns.length,
        spawnedEnemies,
        defeatedEnemies,
        aliveEnemies,
      },
      heroes: this.heroes.map(cloneHero),
      enemies: this.enemies.map(cloneEnemy),
      totalDamageDealt,
      totalHealingDone,
    };
  }

  public setStance(nextStance: TacticalStance): StanceChangeResult {
    if (this.status !== 'running') {
      return {
        accepted: false,
        reason: 'combat_ended',
        currentStance: this.stance,
        cooldownRemainingSec: this.stanceCooldownRemainingSec,
      };
    }

    if (nextStance === this.stance) {
      return {
        accepted: false,
        reason: 'same_stance',
        currentStance: this.stance,
        cooldownRemainingSec: this.stanceCooldownRemainingSec,
      };
    }

    if (this.stanceCooldownRemainingSec > 0) {
      return {
        accepted: false,
        reason: 'cooldown',
        currentStance: this.stance,
        cooldownRemainingSec: this.stanceCooldownRemainingSec,
      };
    }

    const previousStance = this.stance;
    this.stance = nextStance;
    this.stanceCooldownRemainingSec = this.stanceCooldownSec;

    const event: Extract<CombatEvent, { type: 'stance_changed' }> = {
      type: 'stance_changed',
      timeSec: this.elapsedSec,
      previousStance,
      nextStance,
    };

    return {
      accepted: true,
      currentStance: this.stance,
      cooldownRemainingSec: this.stanceCooldownRemainingSec,
      event,
    };
  }

  public step(dtSec: number): CombatTickResult {
    if (this.status !== 'running' || dtSec <= 0) {
      return {
        snapshot: this.getSnapshot(),
        events: [],
      };
    }

    const dt = Math.min(dtSec, 0.25);
    const events: CombatEvent[] = [];

    this.tick += 1;
    this.elapsedSec = Number((this.elapsedSec + dt).toFixed(6));

    // 1. Advance global & unit timers
    this.stanceCooldownRemainingSec = Math.max(0, this.stanceCooldownRemainingSec - dt);
    this.updateTimers(dt);

    // 2. Spawn scheduled enemies
    this.processSpawns(events);

    // 3. Heroes act (target selection, movement, skills, basic attacks)
    this.updateHeroes(dt, events);

    // 4. Enemies act (interception, movement, attacks / explosions / gate hits)
    this.updateEnemies(dt, events);

    // 5. Evaluate end-of-combat conditions
    this.evaluateCombatStatus(events);

    return {
      snapshot: this.getSnapshot(),
      events,
    };
  }

  private createHeroState(def: HeroDefinition, index: number): HeroState {
    const anchor = this.getFormationAnchor(def.role, this.stance, index);
    const skills: SkillRuntimeState[] = def.skills.map((skillDef) => {
      this.skillDefsById.set(skillDef.id, skillDef);
      return {
        skillId: skillDef.id,
        name: skillDef.name,
        description: skillDef.description,
        effectType: skillDef.effectType,
        cooldownSec: skillDef.cooldownSec,
        cooldownRemainingSec: 0,
        maxChargesPerWave: skillDef.maxChargesPerWave ?? null,
        chargesRemaining: skillDef.maxChargesPerWave ?? null,
        triggerCondition: skillDef.triggerCondition,
        timesCast: 0,
      };
    });

    return {
      id: def.id,
      name: def.name,
      title: def.title,
      role: def.role,
      x: anchor.x,
      y: anchor.y,
      radius: def.radius,
      hp: def.maxHp,
      maxHp: def.maxHp,
      shield: 0,
      atk: def.atk,
      def: def.def,
      attackSpeed: def.attackSpeed,
      attackRange: def.attackRange,
      moveSpeed: def.moveSpeed,
      interceptRadius: def.interceptRadius,
      critChance: def.critChance,
      critMultiplier: def.critMultiplier,
      attackCooldownSec: 0,
      damageReductionRatio: 0,
      damageReductionRemainingSec: 0,
      alive: true,
      targetEnemyId: null,
      skills,
      stats: {
        damageDealt: 0,
        damageTaken: 0,
        healingDone: 0,
        kills: 0,
      },
    };
  }

  private getFormationAnchor(role: SquadRole, stance: TacticalStance, index = 0): Vec2 {
    const midY = this.arenaHeight * 0.5;
    if (stance === 'defense') {
      if (role === 'tank') return { x: this.gateX + 148, y: midY };
      if (role === 'dps') return { x: this.gateX + 93, y: midY - 35 };
      return { x: this.gateX + 83, y: midY + 35 };
    }
    if (stance === 'assault') {
      if (role === 'tank') return { x: this.gateX + 308, y: midY };
      if (role === 'dps') return { x: this.gateX + 228, y: midY - 45 };
      return { x: this.gateX + 213, y: midY + 45 };
    }
    // scatter
    if (role === 'tank') return { x: this.gateX + 218, y: midY };
    if (role === 'dps') return { x: this.gateX + 188, y: this.arenaHeight * 0.26 };
    if (role === 'support') return { x: this.gateX + 178, y: this.arenaHeight * 0.74 };
    return { x: this.gateX + 180, y: clamp(120 + index * 100, 80, this.arenaHeight - 80) };
  }

  private updateTimers(dt: number): void {
    for (const hero of this.heroes) {
      if (!hero.alive) continue;
      hero.attackCooldownSec = Math.max(0, hero.attackCooldownSec - dt);
      if (hero.damageReductionRemainingSec > 0) {
        hero.damageReductionRemainingSec = Math.max(0, hero.damageReductionRemainingSec - dt);
        if (hero.damageReductionRemainingSec === 0) {
          hero.damageReductionRatio = 0;
        }
      }
      for (const skill of hero.skills) {
        if (skill.cooldownRemainingSec > 0) {
          skill.cooldownRemainingSec = Math.max(0, skill.cooldownRemainingSec - dt);
        }
      }
    }

    for (const enemy of this.enemies) {
      if (!enemy.alive) continue;
      enemy.attackCooldownSec = Math.max(0, enemy.attackCooldownSec - dt);
      if (enemy.tauntRemainingSec > 0) {
        enemy.tauntRemainingSec = Math.max(0, enemy.tauntRemainingSec - dt);
        if (enemy.tauntRemainingSec === 0) {
          enemy.tauntedByHeroId = null;
        }
      }
    }
  }

  private processSpawns(events: CombatEvent[]): void {
    for (const item of this.scheduledSpawns) {
      if (item.spawned) continue;
      if (this.elapsedSec >= item.entry.spawnTimeSec) {
        item.spawned = true;
        const def = ENEMY_DEFINITIONS[item.entry.archetype];
        this.enemySerial += 1;
        const x = item.entry.spawnX ?? this.arenaWidth - 28;
        const y = clamp(item.entry.laneY, 44, this.arenaHeight - 44);
        const enemy: EnemyState = {
          id: `enemy-${this.enemySerial}-${def.archetype}`,
          archetype: def.archetype,
          name: def.name,
          isElite: def.isElite,
          x,
          y,
          radius: def.radius,
          hp: def.maxHp,
          maxHp: def.maxHp,
          atk: def.atk,
          def: def.def,
          attackSpeed: def.attackSpeed,
          attackRange: def.attackRange,
          moveSpeed: def.moveSpeed,
          gateDamage: def.gateDamage,
          threatPriority: def.threatPriority,
          aoeRadius: def.aoeRadius,
          isExplosive: def.isExplosive,
          attackCooldownSec: 0.25,
          alive: true,
          tauntedByHeroId: null,
          tauntRemainingSec: 0,
          engagedHeroId: null,
          targetKind: 'gate',
        };
        this.enemies.push(enemy);
        events.push({
          type: 'enemy_spawned',
          timeSec: this.elapsedSec,
          enemyId: enemy.id,
          archetype: enemy.archetype,
          isElite: enemy.isElite,
          x: enemy.x,
          y: enemy.y,
        });
      }
    }
  }

  private updateHeroes(dt: number, events: CombatEvent[]): void {
    const stanceMod = STANCE_MODIFIERS[this.stance];
    const aliveEnemies = this.enemies.filter((e) => e.alive);

    for (let i = 0; i < this.heroes.length; i += 1) {
      const hero = this.heroes[i];
      if (!hero.alive) continue;

      const target = this.selectHeroTarget(hero, aliveEnemies);
      hero.targetEnemyId = target ? target.id : null;

      // Movement
      const moveSpeed = hero.moveSpeed * stanceMod.moveSpeedMultiplier;
      const anchor = this.getFormationAnchor(hero.role, this.stance, i);

      if (!target) {
        this.moveToward(hero, anchor.x, anchor.y, moveSpeed, dt);
      } else {
        const distToTarget = distance(hero.x, hero.y, target.x, target.y);
        if (hero.role === 'tank') {
          const desiredX =
            this.stance === 'defense'
              ? Math.min(target.x - Math.max(24, hero.attackRange * 0.65), this.gateX + 340)
              : target.x - Math.max(24, hero.attackRange * 0.65);
          if (distToTarget > hero.attackRange * 0.9) {
            this.moveToward(
              hero,
              clamp(desiredX, this.gateX + 44, this.arenaWidth - 40),
              target.y,
              moveSpeed,
              dt,
            );
          }
        } else {
          // Ranged DPS & Support
          if (distToTarget > hero.attackRange * 0.95) {
            if (this.stance === 'scatter') {
              this.moveToward(hero, target.x, target.y, moveSpeed, dt);
            } else {
              const stepTargetX = clamp(
                target.x - hero.attackRange * 0.85,
                this.gateX + 44,
                this.arenaWidth - 60,
              );
              const stepTargetY = anchor.y * 0.65 + target.y * 0.35;
              this.moveToward(hero, stepTargetX, stepTargetY, moveSpeed, dt);
            }
          } else {
            // Gently drift toward stance formation anchor while staying in range
            const distFromAnchor = distance(hero.x, hero.y, anchor.x, anchor.y);
            if (distFromAnchor > 12) {
              const candidateDist = distance(anchor.x, anchor.y, target.x, target.y);
              if (candidateDist <= hero.attackRange) {
                this.moveToward(hero, anchor.x, anchor.y, moveSpeed * 0.7, dt);
              }
            }
          }
        }
      }

      // Skills: check conditional / limited-charge tactical skills first, then regular skills
      this.tryCastHeroSkills(hero, target, events);

      // Basic attack
      if (target && target.alive && hero.attackCooldownSec <= 0) {
        const dist = distance(hero.x, hero.y, target.x, target.y);
        if (dist <= hero.attackRange + target.radius) {
          this.performHeroAttack(hero, target, 1.0, false, undefined, events);
          const effectiveSpeed = hero.attackSpeed * stanceMod.attackSpeedMultiplier;
          hero.attackCooldownSec = 1 / Math.max(0.1, effectiveSpeed);
        }
      }
    }
  }

  private selectHeroTarget(hero: HeroState, aliveEnemies: EnemyState[]): EnemyState | null {
    if (aliveEnemies.length === 0) return null;

    if (this.stance === 'assault') {
      // Focus-fire highest threatPriority; tie-break by closest to gate, then lowest HP
      return [...aliveEnemies].sort((a, b) => {
        if (b.threatPriority !== a.threatPriority) {
          return b.threatPriority - a.threatPriority;
        }
        if (a.x !== b.x) return a.x - b.x;
        return a.hp - b.hp;
      })[0];
    }

    if (this.stance === 'scatter') {
      // Chase nearest enemy to self, favoring enemies threatening the gate
      return [...aliveEnemies].sort((a, b) => {
        const scoreA =
          distance(hero.x, hero.y, a.x, a.y) + (a.x < this.gateX + 200 ? -80 : 0);
        const scoreB =
          distance(hero.x, hero.y, b.x, b.y) + (b.x < this.gateX + 200 ? -80 : 0);
        return scoreA - scoreB;
      })[0];
    }

    // defense: prioritize enemy closest to gate
    return [...aliveEnemies].sort((a, b) => {
      if (a.x !== b.x) return a.x - b.x;
      return distance(hero.x, hero.y, a.x, a.y) - distance(hero.x, hero.y, b.x, b.y);
    })[0];
  }

  private tryCastHeroSkills(
    hero: HeroState,
    target: EnemyState | null,
    events: CombatEvent[],
  ): void {
    // Prioritize tactical/conditional skills over standard CD skills
    const orderedSkills = [...hero.skills].sort((a, b) => {
      const aPriority = a.maxChargesPerWave !== null ? 0 : 1;
      const bPriority = b.maxChargesPerWave !== null ? 0 : 1;
      return aPriority - bPriority;
    });

    for (const skillState of orderedSkills) {
      if (skillState.cooldownRemainingSec > 0) continue;
      if (skillState.chargesRemaining !== null && skillState.chargesRemaining <= 0) continue;

      const def = this.skillDefsById.get(skillState.skillId);
      if (!def) continue;

      if (!this.checkSkillTrigger(hero, def)) continue;

      const castSucceeded = this.executeSkill(hero, skillState, def, target, events);
      if (castSucceeded) {
        skillState.cooldownRemainingSec = def.cooldownSec;
        if (skillState.chargesRemaining !== null) {
          skillState.chargesRemaining -= 1;
        }
        skillState.timesCast += 1;
        // One skill cast per tick per hero for crisp pacing
        return;
      }
    }
  }

  private checkSkillTrigger(hero: HeroState, def: SkillDefinition): boolean {
    const aliveHeroes = this.heroes.filter((h) => h.alive);
    const aliveEnemies = this.enemies.filter((e) => e.alive);

    switch (def.triggerCondition) {
      case 'always':
        return true;
      case 'self_hp_below_55':
        return hero.hp / hero.maxHp < 0.55;
      case 'any_ally_hp_below_45':
        return aliveHeroes.some((h) => h.hp / h.maxHp < 0.45);
      case 'elite_or_multi_enemies':
        return aliveEnemies.some((e) => e.isElite) || aliveEnemies.length >= 2;
      default:
        return false;
    }
  }

  private executeSkill(
    hero: HeroState,
    _skillState: SkillRuntimeState,
    def: SkillDefinition,
    target: EnemyState | null,
    events: CombatEvent[],
  ): boolean {
    const stanceMod = STANCE_MODIFIERS[this.stance];
    const aliveHeroes = this.heroes.filter((h) => h.alive);
    const aliveEnemies = this.enemies.filter((e) => e.alive);

    switch (def.effectType) {
      case 'self_shield_taunt': {
        const tauntRadius = def.tauntRadius ?? 150;
        const nearbyEnemies = aliveEnemies.filter(
          (e) => distance(hero.x, hero.y, e.x, e.y) <= tauntRadius + 30,
        );
        if (nearbyEnemies.length === 0) return false;

        events.push({
          type: 'skill_cast',
          timeSec: this.elapsedSec,
          heroId: hero.id,
          heroName: hero.name,
          skillId: def.id,
          skillName: def.name,
          x: hero.x,
          y: hero.y,
          radius: tauntRadius,
        });

        const shieldAmt = def.shieldAmount ?? 100;
        hero.shield += shieldAmt;
        events.push({
          type: 'shield',
          timeSec: this.elapsedSec,
          sourceId: hero.id,
          targetId: hero.id,
          amount: shieldAmt,
          skillId: def.id,
          x: hero.x,
          y: hero.y,
        });

        const tauntDur = def.tauntDurationSec ?? 3.5;
        for (const enemy of nearbyEnemies) {
          enemy.tauntedByHeroId = hero.id;
          enemy.tauntRemainingSec = tauntDur;
        }
        return true;
      }

      case 'damage_reduction_self_heal': {
        events.push({
          type: 'skill_cast',
          timeSec: this.elapsedSec,
          heroId: hero.id,
          heroName: hero.name,
          skillId: def.id,
          skillName: def.name,
          x: hero.x,
          y: hero.y,
        });

        hero.damageReductionRatio = Math.max(
          hero.damageReductionRatio,
          def.damageReductionRatio ?? 0.4,
        );
        hero.damageReductionRemainingSec = Math.max(
          hero.damageReductionRemainingSec,
          def.buffDurationSec ?? 5,
        );

        const rawHeal = Math.round((def.healAmount ?? 100) * stanceMod.healMultiplier);
        this.applyHeal(hero, hero, rawHeal, def.id, events);
        return true;
      }

      case 'single_target_burst': {
        if (!target || !target.alive) return false;
        const dist = distance(hero.x, hero.y, target.x, target.y);
        if (dist > hero.attackRange + 35) return false;

        events.push({
          type: 'skill_cast',
          timeSec: this.elapsedSec,
          heroId: hero.id,
          heroName: hero.name,
          skillId: def.id,
          skillName: def.name,
          x: hero.x,
          y: hero.y,
          targetX: target.x,
          targetY: target.y,
        });

        this.performHeroAttack(
          hero,
          target,
          def.damageMultiplier ?? 2.0,
          false,
          def.id,
          events,
        );
        return true;
      }

      case 'aoe_volley': {
        if (!target || !target.alive) return false;
        const dist = distance(hero.x, hero.y, target.x, target.y);
        if (dist > hero.attackRange + 60) return false;

        const aoeRadius = def.aoeRadius ?? 120;
        const impacted = aliveEnemies.filter(
          (e) => distance(target.x, target.y, e.x, e.y) <= aoeRadius,
        );
        if (impacted.length === 0) return false;

        events.push({
          type: 'skill_cast',
          timeSec: this.elapsedSec,
          heroId: hero.id,
          heroName: hero.name,
          skillId: def.id,
          skillName: def.name,
          x: hero.x,
          y: hero.y,
          targetX: target.x,
          targetY: target.y,
          radius: aoeRadius,
        });

        for (const enemy of impacted) {
          this.performHeroAttack(
            hero,
            enemy,
            def.damageMultiplier ?? 1.4,
            true,
            def.id,
            events,
          );
        }
        return true;
      }

      case 'heal_lowest_ally': {
        const injured = aliveHeroes
          .filter((h) => h.hp < h.maxHp)
          .sort((a, b) => a.hp / a.maxHp - b.hp / b.maxHp);
        if (injured.length === 0) return false;

        const patient = injured[0];
        events.push({
          type: 'skill_cast',
          timeSec: this.elapsedSec,
          heroId: hero.id,
          heroName: hero.name,
          skillId: def.id,
          skillName: def.name,
          x: hero.x,
          y: hero.y,
          targetX: patient.x,
          targetY: patient.y,
        });

        const healAmount = Math.round((def.healAmount ?? 85) * stanceMod.healMultiplier);
        this.applyHeal(hero, patient, healAmount, def.id, events);
        return true;
      }

      case 'party_heal_shield': {
        if (aliveHeroes.length === 0) return false;
        events.push({
          type: 'skill_cast',
          timeSec: this.elapsedSec,
          heroId: hero.id,
          heroName: hero.name,
          skillId: def.id,
          skillName: def.name,
          x: hero.x,
          y: hero.y,
        });

        const healAmount = Math.round((def.healAmount ?? 110) * stanceMod.healMultiplier);
        const shieldAmount = def.shieldAmount ?? 70;

        for (const ally of aliveHeroes) {
          this.applyHeal(hero, ally, healAmount, def.id, events);
          ally.shield += shieldAmount;
          events.push({
            type: 'shield',
            timeSec: this.elapsedSec,
            sourceId: hero.id,
            targetId: ally.id,
            amount: shieldAmount,
            skillId: def.id,
            x: ally.x,
            y: ally.y,
          });
        }
        return true;
      }

      default:
        return false;
    }
  }

  private performHeroAttack(
    hero: HeroState,
    enemy: EnemyState,
    skillMultiplier: number,
    isAoe: boolean,
    skillId: string | undefined,
    events: CombatEvent[],
  ): void {
    if (!enemy.alive) return;

    const stanceMod = STANCE_MODIFIERS[this.stance];
    const roleMult = hero.role === 'dps' ? stanceMod.dpsDamageMultiplier : 1.0;
    const isCrit = this.nextRandom() < hero.critChance;
    const critMult = isCrit ? hero.critMultiplier : 1.0;

    const rawDamage = hero.atk * skillMultiplier * stanceMod.teamAtkMultiplier * roleMult * critMult;
    const mitigated = Math.max(1, Math.round(rawDamage * (100 / (100 + enemy.def))));

    enemy.hp = Math.max(0, enemy.hp - mitigated);
    hero.stats.damageDealt += mitigated;

    events.push({
      type: 'damage',
      timeSec: this.elapsedSec,
      sourceId: hero.id,
      sourceTeam: 'hero',
      targetId: enemy.id,
      targetTeam: 'enemy',
      amount: mitigated,
      shieldAbsorbed: 0,
      isCrit,
      isAoe,
      skillId,
      x: enemy.x,
      y: enemy.y,
    });

    if (enemy.hp <= 0 && enemy.alive) {
      enemy.alive = false;
      hero.stats.kills += 1;
      events.push({
        type: 'unit_died',
        timeSec: this.elapsedSec,
        unitId: enemy.id,
        team: 'enemy',
        killerId: hero.id,
        x: enemy.x,
        y: enemy.y,
      });
    }
  }

  private applyHeal(
    source: HeroState,
    target: HeroState,
    amount: number,
    skillId: string,
    events: CombatEvent[],
  ): void {
    const missing = target.maxHp - target.hp;
    const actualHeal = Math.max(0, Math.min(missing, amount));
    if (actualHeal <= 0) return;

    target.hp += actualHeal;
    source.stats.healingDone += actualHeal;

    events.push({
      type: 'heal',
      timeSec: this.elapsedSec,
      sourceId: source.id,
      targetId: target.id,
      amount: actualHeal,
      skillId,
      x: target.x,
      y: target.y,
    });
  }

  private updateEnemies(dt: number, events: CombatEvent[]): void {
    const stanceMod = STANCE_MODIFIERS[this.stance];
    const aliveHeroes = this.heroes.filter((h) => h.alive);
    const aliveTank = aliveHeroes.find((h) => h.role === 'tank') ?? null;

    for (const enemy of this.enemies) {
      if (!enemy.alive) continue;

      const targetHero = this.selectEnemyHeroTarget(enemy, aliveHeroes, aliveTank, stanceMod.tankInterceptRadiusMultiplier);

      if (targetHero) {
        enemy.engagedHeroId = targetHero.id;
        enemy.targetKind = 'hero';
        const dist = distance(enemy.x, enemy.y, targetHero.x, targetHero.y);

        if (dist > enemy.attackRange + targetHero.radius) {
          this.moveToward(enemy, targetHero.x, targetHero.y, enemy.moveSpeed, dt);
        } else if (enemy.attackCooldownSec <= 0) {
          if (enemy.isExplosive) {
            this.detonateBomber(enemy, aliveHeroes, events);
          } else {
            this.performEnemyAttack(enemy, targetHero, false, events);
            enemy.attackCooldownSec = 1 / Math.max(0.1, enemy.attackSpeed);
          }
        }
      } else {
        enemy.engagedHeroId = null;
        enemy.targetKind = 'gate';
        const gateStopX = this.gateX + Math.min(enemy.attackRange, 56);

        if (enemy.x > gateStopX) {
          this.moveToward(enemy, this.gateX, enemy.y, enemy.moveSpeed, dt);
        } else if (enemy.attackCooldownSec <= 0) {
          this.hitGate(enemy, events);
          if (enemy.isExplosive) {
            enemy.hp = 0;
            enemy.alive = false;
            events.push({
              type: 'unit_died',
              timeSec: this.elapsedSec,
              unitId: enemy.id,
              team: 'enemy',
              x: enemy.x,
              y: enemy.y,
            });
          } else {
            enemy.attackCooldownSec = 1 / Math.max(0.1, enemy.attackSpeed);
          }
        }
      }
    }
  }

  private selectEnemyHeroTarget(
    enemy: EnemyState,
    aliveHeroes: HeroState[],
    aliveTank: HeroState | null,
    tankInterceptMult: number,
  ): HeroState | null {
    if (aliveHeroes.length === 0) return null;

    // 1. Taunted by a living hero
    if (enemy.tauntedByHeroId && enemy.tauntRemainingSec > 0) {
      const taunter = aliveHeroes.find((h) => h.id === enemy.tauntedByHeroId);
      if (taunter) return taunter;
    }

    // 2. Intercepted by Tank within Tank's stance-modified intercept radius
    if (aliveTank) {
      const interceptRadius = aliveTank.interceptRadius * tankInterceptMult;
      if (distance(enemy.x, enemy.y, aliveTank.x, aliveTank.y) <= interceptRadius) {
        return aliveTank;
      }
    }

    // 3. Nearest alive hero within aggro range
    const aggroRange = Math.max(enemy.attackRange + 32, 92);
    let nearest: HeroState | null = null;
    let nearestDist = Infinity;

    for (const hero of aliveHeroes) {
      const d = distance(enemy.x, enemy.y, hero.x, hero.y);
      if (d <= aggroRange && d < nearestDist) {
        nearest = hero;
        nearestDist = d;
      }
    }

    return nearest;
  }

  private detonateBomber(
    bomber: EnemyState,
    aliveHeroes: HeroState[],
    events: CombatEvent[],
  ): void {
    const blastRadius = bomber.aoeRadius ?? 115;
    for (const hero of aliveHeroes) {
      if (!hero.alive) continue;
      if (distance(bomber.x, bomber.y, hero.x, hero.y) <= blastRadius + hero.radius) {
        this.performEnemyAttack(bomber, hero, true, events);
      }
    }

    bomber.hp = 0;
    bomber.alive = false;
    events.push({
      type: 'unit_died',
      timeSec: this.elapsedSec,
      unitId: bomber.id,
      team: 'enemy',
      x: bomber.x,
      y: bomber.y,
    });
  }

  private performEnemyAttack(
    enemy: EnemyState,
    hero: HeroState,
    isAoe: boolean,
    events: CombatEvent[],
  ): void {
    if (!hero.alive) return;

    const stanceMod = STANCE_MODIFIERS[this.stance];
    const defMitigation = 100 / (100 + hero.def);
    const aoeMult = isAoe ? stanceMod.aoeDamageTakenMultiplier : 1.0;
    const buffMult = 1 - hero.damageReductionRatio;

    const finalDamage = Math.max(
      1,
      Math.round(enemy.atk * defMitigation * stanceMod.damageTakenMultiplier * aoeMult * buffMult),
    );

    const shieldAbsorbed = Math.min(hero.shield, finalDamage);
    hero.shield -= shieldAbsorbed;
    const hpDamage = finalDamage - shieldAbsorbed;
    hero.hp = Math.max(0, hero.hp - hpDamage);
    hero.stats.damageTaken += finalDamage;

    events.push({
      type: 'damage',
      timeSec: this.elapsedSec,
      sourceId: enemy.id,
      sourceTeam: 'enemy',
      targetId: hero.id,
      targetTeam: 'hero',
      amount: finalDamage,
      shieldAbsorbed,
      isCrit: false,
      isAoe,
      x: hero.x,
      y: hero.y,
    });

    if (hero.hp <= 0 && hero.alive) {
      hero.alive = false;
      events.push({
        type: 'unit_died',
        timeSec: this.elapsedSec,
        unitId: hero.id,
        team: 'hero',
        killerId: enemy.id,
        x: hero.x,
        y: hero.y,
      });
    }
  }

  private hitGate(enemy: EnemyState, events: CombatEvent[]): void {
    const amount = enemy.gateDamage;
    this.gateHp = Math.max(0, this.gateHp - amount);
    events.push({
      type: 'gate_hit',
      timeSec: this.elapsedSec,
      enemyId: enemy.id,
      amount,
      gateHpRemaining: this.gateHp,
      x: this.gateX,
      y: enemy.y,
    });
  }

  private moveToward(
    unit: { x: number; y: number },
    targetX: number,
    targetY: number,
    speed: number,
    dt: number,
  ): void {
    const dx = targetX - unit.x;
    const dy = targetY - unit.y;
    const dist = Math.hypot(dx, dy);
    if (dist <= 0.001) return;

    const stepDist = Math.min(dist, speed * dt);
    unit.x = clamp(unit.x + (dx / dist) * stepDist, this.gateX, this.arenaWidth - 16);
    unit.y = clamp(unit.y + (dy / dist) * stepDist, 32, this.arenaHeight - 32);
  }

  private evaluateCombatStatus(events: CombatEvent[]): void {
    if (this.status !== 'running') return;

    const totalKills = this.enemies.filter((e) => !e.alive).length;

    if (this.gateHp <= 0) {
      this.gateHp = 0;
      this.status = 'defeat';
      events.push({
        type: 'combat_ended',
        timeSec: this.elapsedSec,
        status: 'defeat',
        gateHpRemaining: 0,
        totalKills,
      });
      return;
    }

    const allSpawned = this.scheduledSpawns.every((s) => s.spawned);
    const anyAlive = this.enemies.some((e) => e.alive);

    if (allSpawned && !anyAlive) {
      this.status = 'victory';
      events.push({
        type: 'combat_ended',
        timeSec: this.elapsedSec,
        status: 'victory',
        gateHpRemaining: this.gateHp,
        totalKills,
      });
    }
  }
}
