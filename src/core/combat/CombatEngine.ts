import { ENEMY_DEFINITIONS, getWaveDefinition, REGIMENT_DEFINITIONS } from './presets';
import type {
  CombatConfig,
  CombatEvent,
  CombatSnapshot,
  CombatStatus,
  CombatTickResult,
  EnemyDefinition,
  EnemyState,
  EnemyTelegraph,
  HeroState,
  PendingVolley,
  PlayerInput,
  RegimentCommand,
  RegimentDefinition,
  RegimentFormation,
  RegimentOrder,
  RegimentState,
  SoldierState,
  WaveDefinition,
  WaveSpawnEntry,
} from '../types/combat';

interface InternalSoldier extends SoldierState {
  buffRemainingSec: number;
  chargeDirX: number;
  chargeDirY: number;
  chargeHitIds: Set<string>;
}

interface InternalEnemy extends EnemyState {
  def: EnemyDefinition;
  attackCooldownSec: number;
  telegraphCooldownSec: number;
  telegraphKind: 'cleave' | 'whirlwind';
  telegraphRadius: number;
  telegraphWindupSec: number;
  telegraphDamage: number;
}

interface PendingSpawn {
  entry: WaveSpawnEntry;
  spawned: boolean;
}

const DEFAULT_ARENA_WIDTH = 1080;
const DEFAULT_ARENA_HEIGHT = 600;
const DEFAULT_GATE_X = 80;
const DEFAULT_GATE_MAX_HP = 500;

const HERO_MAX_HP = 320;
const HERO_MAX_STAMINA = 100;
const HERO_STAMINA_REGEN = 24;
const HERO_MOVE_SPEED = 195;
const HERO_RADIUS = 16;
const HERO_DODGE_COST = 30;
const HERO_DODGE_DURATION = 0.24;
const HERO_DODGE_IFRAMES = 0.28;
const HERO_DODGE_SPEED = 440;
const HERO_RESPAWN_SEC = 6;
const HERO_SKILL1_CD = 6.5;
const HERO_SKILL2_CD = 14;
const HERO_WARCRY_DURATION = 6;
const HERO_WARCRY_RADIUS = 240;

const ORDER_LABELS: Record<RegimentOrder, string> = {
  follow: '跟隨武將',
  hold: '定點列陣',
  engage: '自由進攻',
};

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function normalizeAngle(angle: number): number {
  let a = angle;
  while (a > Math.PI) a -= Math.PI * 2;
  while (a < -Math.PI) a += Math.PI * 2;
  return a;
}

function distToSegment(
  px: number,
  py: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
): number {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const lenSq = dx * dx + dy * dy;
  if (lenSq <= 0.0001) return Math.hypot(px - x1, py - y1);
  const t = clamp(((px - x1) * dx + (py - y1) * dy) / lenSq, 0, 1);
  const projX = x1 + t * dx;
  const projY = y1 + t * dy;
  return Math.hypot(px - projX, py - projY);
}

function createMulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class CombatEngine {
  private readonly rng: () => number;
  private readonly arenaWidth: number;
  private readonly arenaHeight: number;
  private readonly gateX: number;
  private readonly gateMaxHp: number;
  private readonly wave: WaveDefinition;
  private readonly regimentDef: RegimentDefinition;

  private tick = 0;
  private elapsedSec = 0;
  private status: CombatStatus = 'running';
  private gateHp: number;
  private totalEnemies: number;
  private defeatedEnemies = 0;

  private hero: HeroState;
  private heroComboResetSec = 0;
  private heroDodgeAngle = 0;

  private regimentOrder: RegimentOrder = 'follow';
  private regimentFormation: RegimentFormation = 'compact';
  private regimentAnchorX: number;
  private regimentAnchorY: number;
  private regimentSkillCooldownSec = 0;
  private soldiers: InternalSoldier[] = [];

  private pendingSpawns: PendingSpawn[];
  private enemies: InternalEnemy[] = [];
  private enemyIdCounter = 1;

  private pendingVolleys: PendingVolley[] = [];
  private volleyIdCounter = 1;

  private queuedEvents: CombatEvent[] = [];

  constructor(config: CombatConfig = {}) {
    this.rng = createMulberry32(config.seed ?? 1337);
    this.arenaWidth = config.arenaWidth ?? DEFAULT_ARENA_WIDTH;
    this.arenaHeight = config.arenaHeight ?? DEFAULT_ARENA_HEIGHT;
    this.gateX = config.gateX ?? DEFAULT_GATE_X;
    this.gateMaxHp = config.gateMaxHp ?? DEFAULT_GATE_MAX_HP;
    this.gateHp = this.gateMaxHp;

    const regType = config.regimentType ?? 'shieldmen';
    this.regimentDef = REGIMENT_DEFINITIONS[regType];

    if (typeof config.wave === 'number') {
      this.wave = getWaveDefinition(config.wave);
    } else if (config.wave) {
      this.wave = config.wave;
    } else {
      this.wave = getWaveDefinition(1);
    }

    this.pendingSpawns = this.wave.spawns.map((entry) => ({
      entry,
      spawned: false,
    }));
    this.totalEnemies = this.wave.spawns.reduce((sum, s) => sum + s.count, 0);

    const heroStartX = this.clampUnitX(this.gateX + 140);
    const heroStartY = this.arenaHeight / 2;

    this.hero = {
      name: '艾莉絲',
      x: heroStartX,
      y: heroStartY,
      radius: HERO_RADIUS,
      facingAngle: 0,
      hp: HERO_MAX_HP,
      maxHp: HERO_MAX_HP,
      stamina: HERO_MAX_STAMINA,
      maxStamina: HERO_MAX_STAMINA,
      alive: true,
      respawnRemainingSec: 0,
      comboStep: 0,
      attackCooldownSec: 0,
      dodgeRemainingSec: 0,
      invulnerableRemainingSec: 0,
      skill1CooldownSec: 0,
      skill1MaxCooldownSec: HERO_SKILL1_CD,
      skill2CooldownSec: 0,
      skill2MaxCooldownSec: HERO_SKILL2_CD,
      warcryRemainingSec: 0,
      kills: 0,
      damageDealt: 0,
    };

    this.regimentAnchorX = this.clampUnitX(heroStartX - 48);
    this.regimentAnchorY = heroStartY;

    this.soldiers = [];
    for (let i = 0; i < this.regimentDef.count; i += 1) {
      this.soldiers.push({
        id: `soldier_${i + 1}`,
        index: i,
        x: this.regimentAnchorX,
        y: this.regimentAnchorY,
        facingAngle: 0,
        hp: this.regimentDef.maxHp,
        maxHp: this.regimentDef.maxHp,
        alive: true,
        slotX: this.regimentAnchorX,
        slotY: this.regimentAnchorY,
        attackCooldownSec: 0,
        shieldBlocking: this.regimentDef.type === 'shieldmen',
        chargingRemainingSec: 0,
        buffRemainingSec: 0,
        chargeDirX: 1,
        chargeDirY: 0,
        chargeHitIds: new Set<string>(),
      });
    }

    this.recalculateFormationSlots();
    for (const soldier of this.soldiers) {
      soldier.x = soldier.slotX;
      soldier.y = soldier.slotY;
    }
  }

  public issueRegimentCommand(cmd: RegimentCommand): boolean {
    if (this.status !== 'running') return false;
    const aliveSoldiers = this.soldiers.filter((s) => s.alive);
    if (aliveSoldiers.length === 0) return false;

    if (cmd.type === 'order') {
      this.regimentOrder = cmd.order;
      if (cmd.order === 'hold') {
        this.regimentAnchorX = this.clampUnitX(cmd.targetX ?? this.hero.x);
        this.regimentAnchorY = this.clampUnitY(cmd.targetY ?? this.hero.y);
      } else if (cmd.order === 'follow') {
        this.regimentAnchorX = this.clampUnitX(this.hero.x - 45);
        this.regimentAnchorY = this.clampUnitY(this.hero.y);
      } else if (cmd.order === 'engage' && cmd.targetX !== undefined && cmd.targetY !== undefined) {
        this.regimentAnchorX = this.clampUnitX(cmd.targetX);
        this.regimentAnchorY = this.clampUnitY(cmd.targetY);
      }
      this.recalculateFormationSlots();
      this.queuedEvents.push({
        type: 'regiment_command',
        commandType: 'order',
        order: cmd.order,
        x: this.regimentAnchorX,
        y: this.regimentAnchorY,
        label: ORDER_LABELS[cmd.order],
      });
      return true;
    }

    if (cmd.type === 'formation') {
      this.regimentFormation = cmd.formation;
      this.recalculateFormationSlots();
      const label =
        cmd.formation === 'compact' ? this.regimentDef.compactLabel : this.regimentDef.spreadLabel;
      this.queuedEvents.push({
        type: 'regiment_command',
        commandType: 'formation',
        formation: cmd.formation,
        x: this.regimentAnchorX,
        y: this.regimentAnchorY,
        label,
      });
      return true;
    }

    if (cmd.type === 'skill') {
      if (this.regimentSkillCooldownSec > 0) return false;
      this.regimentSkillCooldownSec = this.regimentDef.skillCooldownSec;
      const targetX = this.clampUnitX(cmd.targetX);
      const targetY = this.clampUnitY(cmd.targetY);
      this.executeRegimentSkill(aliveSoldiers, targetX, targetY, this.queuedEvents);
      this.queuedEvents.push({
        type: 'regiment_command',
        commandType: 'skill',
        x: targetX,
        y: targetY,
        label: this.regimentDef.skillName,
      });
      return true;
    }

    return false;
  }

  public step(dtSec: number, input?: Partial<PlayerInput>): CombatTickResult {
    if (this.status !== 'running') {
      return { snapshot: this.getSnapshot(), events: [] };
    }

    const dt = clamp(dtSec, 0, 0.25);
    const events: CombatEvent[] =
      this.queuedEvents.length > 0 ? this.queuedEvents.splice(0, this.queuedEvents.length) : [];

    this.tick += 1;
    this.elapsedSec += dt;

    // 1. Spawn scheduled enemies
    this.processWaveSpawns();

    // 2. Update Hero (input, dodge, skills, melee combo, respawn)
    this.updateHero(dt, input, events);

    // 3. Update Regiment (formation slots, soldier AI, attacks, charge impacts)
    this.updateRegiment(dt, events);

    // 4. Update Pending Volleys (archers F skill)
    this.updatePendingVolleys(dt, events);

    // 5. Update Enemies (AI, commander telegraphs, attacks, gate hits)
    this.updateEnemies(dt, events);

    // 6. Soft separation so units form readable frontlines
    this.applySoftSeparation();

    // 7. Check victory / defeat
    this.checkCombatEnd(events);

    return {
      snapshot: this.getSnapshot(),
      events,
    };
  }

  public getSnapshot(): CombatSnapshot {
    const aliveCount = this.soldiers.reduce((count, s) => count + (s.alive ? 1 : 0), 0);
    const regiment: RegimentState = {
      type: this.regimentDef.type,
      name: this.regimentDef.name,
      description: this.regimentDef.description,
      order: this.regimentOrder,
      formation: this.regimentFormation,
      anchorX: this.regimentAnchorX,
      anchorY: this.regimentAnchorY,
      skillName: this.regimentDef.skillName,
      skillCooldownSec: this.regimentSkillCooldownSec,
      skillMaxCooldownSec: this.regimentDef.skillCooldownSec,
      aliveCount,
      maxCount: this.regimentDef.count,
      soldiers: this.soldiers.map((s) => ({
        id: s.id,
        index: s.index,
        x: s.x,
        y: s.y,
        facingAngle: s.facingAngle,
        hp: s.hp,
        maxHp: s.maxHp,
        alive: s.alive,
        slotX: s.slotX,
        slotY: s.slotY,
        attackCooldownSec: s.attackCooldownSec,
        shieldBlocking: s.shieldBlocking,
        chargingRemainingSec: s.chargingRemainingSec,
      })),
    };

    const enemies: EnemyState[] = this.enemies.map((e) => ({
      id: e.id,
      type: e.type,
      name: e.name,
      isCommander: e.isCommander,
      x: e.x,
      y: e.y,
      radius: e.radius,
      facingAngle: e.facingAngle,
      hp: e.hp,
      maxHp: e.maxHp,
      alive: e.alive,
      telegraph: e.telegraph ? { ...e.telegraph } : undefined,
    }));

    return {
      tick: this.tick,
      elapsedSec: this.elapsedSec,
      status: this.status,
      arenaWidth: this.arenaWidth,
      arenaHeight: this.arenaHeight,
      gateX: this.gateX,
      gateHp: this.gateHp,
      gateMaxHp: this.gateMaxHp,
      waveNumber: this.wave.waveNumber,
      waveName: this.wave.name,
      waveDescription: this.wave.description,
      totalEnemies: this.totalEnemies,
      defeatedEnemies: this.defeatedEnemies,
      hero: { ...this.hero },
      regiment,
      enemies,
      pendingVolleys: this.pendingVolleys.map((v) => ({ ...v })),
    };
  }

  private clampUnitX(x: number): number {
    return clamp(x, this.gateX + 16, this.arenaWidth - 20);
  }

  private clampUnitY(y: number): number {
    return clamp(y, 24, this.arenaHeight - 24);
  }

  private processWaveSpawns(): void {
    for (const item of this.pendingSpawns) {
      if (item.spawned) continue;
      if (this.elapsedSec >= item.entry.spawnTimeSec) {
        item.spawned = true;
        this.spawnEntry(item.entry);
      }
    }
  }

  private spawnEntry(entry: WaveSpawnEntry): void {
    const def = ENEMY_DEFINITIONS[entry.type];
    const baseY = entry.spawnY ?? this.arenaHeight / 2;
    const baseX = entry.spawnX ?? this.arenaWidth - 24;
    const hpMult = entry.hpMultiplier ?? 1;
    const maxHp = Math.round(def.maxHp * hpMult);

    for (let i = 0; i < entry.count; i += 1) {
      const rowOffset = (i - (entry.count - 1) / 2) * 32;
      const jitterX = entry.spawnX !== undefined ? 0 : (this.rng() - 0.5) * 26;
      const jitterY = entry.spawnY !== undefined && entry.count === 1 ? 0 : (this.rng() - 0.5) * 14;
      const x = clamp(baseX + jitterX, this.gateX + 20, this.arenaWidth - 16);
      const y = this.clampUnitY(baseY + rowOffset + jitterY);

      this.enemies.push({
        id: `enemy_${this.enemyIdCounter++}`,
        type: entry.type,
        name: entry.customName ?? def.name,
        isCommander: def.isCommander,
        x,
        y,
        radius: def.radius,
        facingAngle: Math.PI,
        hp: maxHp,
        maxHp,
        alive: true,
        def,
        attackCooldownSec: 0.25 + this.rng() * 0.35,
        telegraphCooldownSec: def.isCommander ? 1.8 : 999,
        telegraphKind: entry.telegraphKind ?? def.telegraphKind ?? 'cleave',
        telegraphRadius: entry.telegraphRadius ?? def.telegraphRadius ?? 88,
        telegraphWindupSec: def.telegraphWindupSec ?? 1.1,
        telegraphDamage: def.telegraphDamage ?? 60,
      });
    }
  }

  private updateHero(dt: number, input: Partial<PlayerInput> | undefined, events: CombatEvent[]): void {
    const h = this.hero;

    h.attackCooldownSec = Math.max(0, h.attackCooldownSec - dt);
    h.skill1CooldownSec = Math.max(0, h.skill1CooldownSec - dt);
    h.skill2CooldownSec = Math.max(0, h.skill2CooldownSec - dt);
    h.warcryRemainingSec = Math.max(0, h.warcryRemainingSec - dt);
    h.invulnerableRemainingSec = Math.max(0, h.invulnerableRemainingSec - dt);
    this.heroComboResetSec = Math.max(0, this.heroComboResetSec - dt);
    if (this.heroComboResetSec <= 0) {
      h.comboStep = 0;
    }

    if (!h.alive) {
      h.respawnRemainingSec = Math.max(0, h.respawnRemainingSec - dt);
      if (h.respawnRemainingSec <= 0) {
        h.alive = true;
        h.hp = h.maxHp;
        h.stamina = h.maxStamina;
        h.x = this.clampUnitX(this.gateX + 48);
        h.y = this.arenaHeight / 2;
        h.invulnerableRemainingSec = 1.5;
        events.push({ type: 'hero_respawn', x: h.x, y: h.y });
      }
      return;
    }

    // Regenerate stamina when not dodging
    if (h.dodgeRemainingSec <= 0) {
      h.stamina = Math.min(h.maxStamina, h.stamina + HERO_STAMINA_REGEN * dt);
    }

    const moveX = input?.moveX ?? 0;
    const moveY = input?.moveY ?? 0;
    if (input?.aimX !== undefined && input?.aimY !== undefined) {
      const dx = input.aimX - h.x;
      const dy = input.aimY - h.y;
      if (dx * dx + dy * dy > 1) {
        h.facingAngle = Math.atan2(dy, dx);
      }
    }

    // Dodge trigger
    if (input?.dodgePressed && h.dodgeRemainingSec <= 0 && h.stamina >= HERO_DODGE_COST) {
      h.stamina -= HERO_DODGE_COST;
      h.dodgeRemainingSec = HERO_DODGE_DURATION;
      h.invulnerableRemainingSec = Math.max(h.invulnerableRemainingSec, HERO_DODGE_IFRAMES);
      const moveLen = Math.hypot(moveX, moveY);
      this.heroDodgeAngle = moveLen > 0.05 ? Math.atan2(moveY, moveX) : h.facingAngle;
      events.push({
        type: 'hero_dodge',
        x: h.x,
        y: h.y,
        angle: this.heroDodgeAngle,
      });
    }

    // Movement
    if (h.dodgeRemainingSec > 0) {
      const stepTime = Math.min(dt, h.dodgeRemainingSec);
      h.x = this.clampUnitX(h.x + Math.cos(this.heroDodgeAngle) * HERO_DODGE_SPEED * stepTime);
      h.y = this.clampUnitY(h.y + Math.sin(this.heroDodgeAngle) * HERO_DODGE_SPEED * stepTime);
      h.dodgeRemainingSec = Math.max(0, h.dodgeRemainingSec - dt);
    } else {
      const len = Math.hypot(moveX, moveY);
      if (len > 0.01) {
        const nx = len > 1 ? moveX / len : moveX;
        const ny = len > 1 ? moveY / len : moveY;
        const speedMult = h.warcryRemainingSec > 0 ? 1.18 : 1;
        h.x = this.clampUnitX(h.x + nx * HERO_MOVE_SPEED * speedMult * dt);
        h.y = this.clampUnitY(h.y + ny * HERO_MOVE_SPEED * speedMult * dt);
      }
    }

    // Skill 2: 戰意咆哮 (E)
    if (input?.skill2Pressed && h.skill2CooldownSec <= 0) {
      h.skill2CooldownSec = h.skill2MaxCooldownSec;
      h.warcryRemainingSec = HERO_WARCRY_DURATION;
      for (const soldier of this.soldiers) {
        if (!soldier.alive) continue;
        if (Math.hypot(soldier.x - h.x, soldier.y - h.y) <= HERO_WARCRY_RADIUS) {
          soldier.buffRemainingSec = Math.max(soldier.buffRemainingSec, HERO_WARCRY_DURATION);
        }
      }
      events.push({
        type: 'hero_warcry',
        x: h.x,
        y: h.y,
        radius: HERO_WARCRY_RADIUS,
      });
    }

    // Skill 1: 破陣衝鋒 (Q / RMB)
    if (input?.skill1Pressed && h.skill1CooldownSec <= 0 && h.dodgeRemainingSec <= 0) {
      h.skill1CooldownSec = h.skill1MaxCooldownSec;
      h.invulnerableRemainingSec = Math.max(h.invulnerableRemainingSec, 0.22);
      const fromX = h.x;
      const fromY = h.y;
      const dashDist = 175;
      const dirX = Math.cos(h.facingAngle);
      const dirY = Math.sin(h.facingAngle);
      const toX = this.clampUnitX(fromX + dirX * dashDist);
      const toY = this.clampUnitY(fromY + dirY * dashDist);
      h.x = toX;
      h.y = toY;

      events.push({ type: 'hero_charge', fromX, fromY, toX, toY });

      const warcryMult = h.warcryRemainingSec > 0 ? 1.35 : 1;
      for (const enemy of this.enemies) {
        if (!enemy.alive) continue;
        const dist = distToSegment(enemy.x, enemy.y, fromX, fromY, toX, toY);
        if (dist <= enemy.radius + 36) {
          const rawDmg = 58 * warcryMult;
          this.damageEnemy(enemy, rawDmg, 0.4, true, true, events);
          enemy.x = this.clampUnitX(enemy.x + dirX * 64);
          enemy.y = this.clampUnitY(enemy.y + dirY * 64);
        }
      }
    }

    // Basic 3-hit directional melee cone
    if (input?.attackPressed && h.attackCooldownSec <= 0 && h.dodgeRemainingSec <= 0) {
      const stepIdx = h.comboStep;
      const warcryMult = h.warcryRemainingSec > 0 ? 1.35 : 1;

      const configs: Record<
        0 | 1 | 2,
        { damage: number; radius: number; arcRad: number; cd: number; knockback: number; armorPen: number }
      > = {
        0: { damage: 34, radius: 74, arcRad: 1.65, cd: 0.36, knockback: 10, armorPen: 0 },
        1: { damage: 40, radius: 78, arcRad: 1.75, cd: 0.38, knockback: 14, armorPen: 0.1 },
        2: { damage: 56, radius: 88, arcRad: 2.05, cd: 0.52, knockback: 48, armorPen: 0.5 },
      };

      const cfg = configs[stepIdx];
      h.attackCooldownSec = cfg.cd;
      this.heroComboResetSec = 1.35;
      h.comboStep = ((stepIdx + 1) % 3) as 0 | 1 | 2;

      events.push({
        type: 'hero_slash',
        x: h.x,
        y: h.y,
        angle: h.facingAngle,
        radius: cfg.radius,
        arcRad: cfg.arcRad,
        comboStep: stepIdx,
      });

      const halfArc = cfg.arcRad / 2;
      for (const enemy of this.enemies) {
        if (!enemy.alive) continue;
        const dx = enemy.x - h.x;
        const dy = enemy.y - h.y;
        const dist = Math.hypot(dx, dy);
        if (dist > cfg.radius + enemy.radius) continue;
        const angleToEnemy = Math.atan2(dy, dx);
        const angleDiff = Math.abs(normalizeAngle(angleToEnemy - h.facingAngle));
        if (angleDiff <= halfArc || dist <= h.radius + enemy.radius + 6) {
          this.damageEnemy(
            enemy,
            cfg.damage * warcryMult,
            cfg.armorPen,
            stepIdx === 2,
            true,
            events,
          );
          if (cfg.knockback > 0 && dist > 0.001) {
            enemy.x = this.clampUnitX(enemy.x + (dx / dist) * cfg.knockback);
            enemy.y = this.clampUnitY(enemy.y + (dy / dist) * cfg.knockback);
          }
        }
      }
    }
  }

  private recalculateFormationSlots(): void {
    const count = this.soldiers.length;
    const isCompact = this.regimentFormation === 'compact';

    if (isCompact) {
      const cols = 2;
      const rows = Math.ceil(count / cols);
      const colSpacing = 24;
      const rowSpacing = 26;

      for (let i = 0; i < count; i += 1) {
        const col = i % cols;
        const row = Math.floor(i / cols);
        const offsetX = (cols - 1) * 0.5 * colSpacing - col * colSpacing;
        const offsetY = (row - (rows - 1) / 2) * rowSpacing;
        this.soldiers[i].slotX = this.clampUnitX(this.regimentAnchorX + offsetX);
        this.soldiers[i].slotY = this.clampUnitY(this.regimentAnchorY + offsetY);
      }
    } else {
      // Spread: wide 1-column line (or staggered wide line) to cover flank & avoid AOE
      const rowSpacing = 46;
      for (let i = 0; i < count; i += 1) {
        const staggerX = i % 2 === 0 ? 12 : -12;
        const offsetY = (i - (count - 1) / 2) * rowSpacing;
        this.soldiers[i].slotX = this.clampUnitX(this.regimentAnchorX + staggerX);
        this.soldiers[i].slotY = this.clampUnitY(this.regimentAnchorY + offsetY);
      }
    }
  }

  private executeRegimentSkill(
    aliveSoldiers: InternalSoldier[],
    targetX: number,
    targetY: number,
    events: CombatEvent[],
  ): void {
    const type = this.regimentDef.type;

    if (type === 'shieldmen') {
      const cx = aliveSoldiers.reduce((s, u) => s + u.x, 0) / aliveSoldiers.length;
      const cy = aliveSoldiers.reduce((s, u) => s + u.y, 0) / aliveSoldiers.length;
      const dx = targetX - cx;
      const dy = targetY - cy;
      const len = Math.hypot(dx, dy) || 1;
      const dirX = dx / len;
      const dirY = dy / len;

      for (const s of aliveSoldiers) {
        s.chargingRemainingSec = 0.65;
        s.chargeDirX = dirX;
        s.chargeDirY = dirY;
        s.facingAngle = Math.atan2(dirY, dirX);
        s.shieldBlocking = true;
        s.chargeHitIds.clear();
      }
      if (this.regimentOrder === 'hold') {
        this.regimentAnchorX = this.clampUnitX(this.regimentAnchorX + dirX * 90);
        this.regimentAnchorY = this.clampUnitY(this.regimentAnchorY + dirY * 90);
        this.recalculateFormationSlots();
      }
      return;
    }

    if (type === 'pikemen') {
      for (const s of aliveSoldiers) {
        const dx = targetX - s.x;
        const dy = targetY - s.y;
        const len = Math.hypot(dx, dy) || 1;
        const dirX = dx / len;
        const dirY = dy / len;
        s.facingAngle = Math.atan2(dirY, dirX);
        s.chargingRemainingSec = 0.45;

        const buffMult = s.buffRemainingSec > 0 ? 1.35 : 1;
        for (const enemy of this.enemies) {
          if (!enemy.alive) continue;
          const ex = enemy.x - s.x;
          const ey = enemy.y - s.y;
          const along = ex * dirX + ey * dirY;
          if (along < -8 || along > 96 + enemy.radius) continue;
          const perp = Math.abs(-ex * dirY + ey * dirX);
          if (perp <= enemy.radius + 26) {
            this.damageEnemy(enemy, 44 * buffMult, 0.4, true, false, events);
            enemy.x = this.clampUnitX(enemy.x + dirX * 24);
            enemy.y = this.clampUnitY(enemy.y + dirY * 24);
          }
        }
      }
      return;
    }

    // Archers: 指定箭雨
    const volleyDamage = 24 + aliveSoldiers.length * 5;
    this.pendingVolleys.push({
      id: `volley_${this.volleyIdCounter++}`,
      x: targetX,
      y: targetY,
      radius: 95,
      remainingSec: 0.75,
      totalSec: 0.75,
      damage: volleyDamage,
    });
    for (const s of aliveSoldiers) {
      s.facingAngle = Math.atan2(targetY - s.y, targetX - s.x);
      events.push({
        type: 'arrow_shot',
        fromX: s.x,
        fromY: s.y,
        toX: targetX,
        toY: targetY,
        isPlayerSide: true,
      });
    }
  }

  private updateRegiment(dt: number, events: CombatEvent[]): void {
    this.regimentSkillCooldownSec = Math.max(0, this.regimentSkillCooldownSec - dt);

    if (this.regimentOrder === 'follow') {
      if (this.hero.alive) {
        this.regimentAnchorX = this.clampUnitX(this.hero.x - 45);
        this.regimentAnchorY = this.clampUnitY(this.hero.y);
      } else {
        this.regimentAnchorX = this.clampUnitX(this.gateX + 75);
        this.regimentAnchorY = this.arenaHeight / 2;
      }
      this.recalculateFormationSlots();
    }

    const def = this.regimentDef;
    const isShieldWall = def.type === 'shieldmen' && this.regimentFormation === 'compact';

    for (const soldier of this.soldiers) {
      if (!soldier.alive) continue;

      soldier.attackCooldownSec = Math.max(0, soldier.attackCooldownSec - dt);
      soldier.buffRemainingSec = Math.max(0, soldier.buffRemainingSec - dt);
      soldier.shieldBlocking = isShieldWall || (def.type === 'shieldmen' && soldier.chargingRemainingSec > 0);

      const speedMult = soldier.buffRemainingSec > 0 ? 1.18 : 1;
      const dmgMult = soldier.buffRemainingSec > 0 ? 1.35 : 1;
      const moraleMult = this.hero.alive ? 1 : 0.85;

      // Active charge surge (shieldmen F skill)
      if (soldier.chargingRemainingSec > 0) {
        soldier.chargingRemainingSec = Math.max(0, soldier.chargingRemainingSec - dt);
        if (def.type === 'shieldmen') {
          const chargeSpeed = def.moveSpeed * 2.15 * speedMult;
          soldier.x = this.clampUnitX(soldier.x + soldier.chargeDirX * chargeSpeed * dt);
          soldier.y = this.clampUnitY(soldier.y + soldier.chargeDirY * chargeSpeed * dt);

          for (const enemy of this.enemies) {
            if (!enemy.alive || soldier.chargeHitIds.has(enemy.id)) continue;
            const dist = Math.hypot(enemy.x - soldier.x, enemy.y - soldier.y);
            if (dist <= def.radius + enemy.radius + 14) {
              soldier.chargeHitIds.add(enemy.id);
              this.damageEnemy(enemy, 38 * dmgMult, 0.25, true, false, events);
              enemy.x = this.clampUnitX(enemy.x + soldier.chargeDirX * 55);
              enemy.y = this.clampUnitY(enemy.y + soldier.chargeDirY * 55);
            }
          }
          continue;
        }
      }

      const nearestEnemy = this.findNearestEnemy(soldier.x, soldier.y);
      const distToEnemy = nearestEnemy
        ? Math.hypot(nearestEnemy.x - soldier.x, nearestEnemy.y - soldier.y)
        : Infinity;

      // Determine movement target
      let moveTargetX = soldier.slotX;
      let moveTargetY = soldier.slotY;

      if (this.regimentOrder === 'engage' && nearestEnemy) {
        if (distToEnemy > def.attackRange + nearestEnemy.radius - 4) {
          moveTargetX = nearestEnemy.x;
          moveTargetY = nearestEnemy.y;
        } else {
          moveTargetX = soldier.x;
          moveTargetY = soldier.y;
        }
      } else if (this.regimentOrder === 'follow' && !def.isRanged && nearestEnemy && distToEnemy < 85) {
        if (distToEnemy > def.attackRange + nearestEnemy.radius - 4) {
          moveTargetX = nearestEnemy.x;
          moveTargetY = nearestEnemy.y;
        } else {
          moveTargetX = soldier.x;
          moveTargetY = soldier.y;
        }
      } else if (this.regimentOrder === 'hold' && !def.isRanged && nearestEnemy) {
        // Hold position: small 26px leash from slot
        const distFromSlot = Math.hypot(nearestEnemy.x - soldier.slotX, nearestEnemy.y - soldier.slotY);
        if (distFromSlot <= def.attackRange + 26 && distToEnemy > def.attackRange + nearestEnemy.radius - 4) {
          moveTargetX = nearestEnemy.x;
          moveTargetY = nearestEnemy.y;
        }
      }

      const mdx = moveTargetX - soldier.x;
      const mdy = moveTargetY - soldier.y;
      const mdist = Math.hypot(mdx, mdy);
      if (mdist > 3) {
        const catchupMult =
          (this.regimentOrder === 'follow' || this.regimentOrder === 'hold') && mdist > 160
            ? 1.25
            : 1;
        const stepDist = Math.min(mdist, def.moveSpeed * speedMult * catchupMult * dt);
        soldier.x = this.clampUnitX(soldier.x + (mdx / mdist) * stepDist);
        soldier.y = this.clampUnitY(soldier.y + (mdy / mdist) * stepDist);
        soldier.facingAngle = Math.atan2(mdy, mdx);
      } else if (nearestEnemy && distToEnemy <= def.attackRange + 80) {
        soldier.facingAngle = Math.atan2(nearestEnemy.y - soldier.y, nearestEnemy.x - soldier.x);
      } else {
        soldier.facingAngle = 0;
      }

      // Attack if enemy in range
      if (
        nearestEnemy &&
        soldier.attackCooldownSec <= 0 &&
        distToEnemy <= def.attackRange + nearestEnemy.radius
      ) {
        const attackInterval =
          def.type === 'archers' && this.regimentFormation === 'compact'
            ? def.attackIntervalSec / 1.15
            : def.attackIntervalSec;
        soldier.attackCooldownSec = attackInterval;
        soldier.facingAngle = Math.atan2(nearestEnemy.y - soldier.y, nearestEnemy.x - soldier.x);

        let bonusMult = 1;
        if (def.type === 'pikemen' && this.regimentFormation === 'compact') {
          // Extra damage vs approaching/fast enemies
          bonusMult = nearestEnemy.type === 'berserker' ? 1.45 : 1.25;
        }

        if (def.isRanged) {
          events.push({
            type: 'arrow_shot',
            fromX: soldier.x,
            fromY: soldier.y,
            toX: nearestEnemy.x,
            toY: nearestEnemy.y,
            isPlayerSide: true,
          });
        }

        const rawDmg = def.attack * dmgMult * moraleMult * bonusMult;
        this.damageEnemy(nearestEnemy, rawDmg, 0, bonusMult > 1.3, false, events);
      }
    }
  }

  private updatePendingVolleys(dt: number, events: CombatEvent[]): void {
    const remaining: PendingVolley[] = [];
    for (const volley of this.pendingVolleys) {
      volley.remainingSec -= dt;
      if (volley.remainingSec <= 0) {
        events.push({
          type: 'volley_impact',
          x: volley.x,
          y: volley.y,
          radius: volley.radius,
        });
        for (const enemy of this.enemies) {
          if (!enemy.alive) continue;
          const dist = Math.hypot(enemy.x - volley.x, enemy.y - volley.y);
          if (dist <= volley.radius + enemy.radius) {
            this.damageEnemy(enemy, volley.damage, 0.25, true, false, events);
          }
        }
      } else {
        remaining.push(volley);
      }
    }
    this.pendingVolleys = remaining;
  }

  private updateEnemies(dt: number, events: CombatEvent[]): void {
    for (const enemy of this.enemies) {
      if (!enemy.alive) continue;

      enemy.attackCooldownSec = Math.max(0, enemy.attackCooldownSec - dt);
      if (enemy.isCommander) {
        enemy.telegraphCooldownSec = Math.max(0, enemy.telegraphCooldownSec - dt);
      }

      // Active commander telegraph countdown
      if (enemy.telegraph) {
        enemy.telegraph.remainingSec -= dt;
        if (enemy.telegraph.remainingSec <= 0) {
          this.resolveCommanderSlam(enemy, enemy.telegraph, events);
          enemy.telegraph = undefined;
          enemy.telegraphCooldownSec = enemy.def.telegraphCooldownSec ?? 6.5;
        }
        continue;
      }

      const target = this.findNearestPlayerTarget(enemy);
      const distToTarget = target ? Math.hypot(target.x - enemy.x, target.y - enemy.y) : Infinity;

      // Commander telegraph trigger
      if (
        enemy.isCommander &&
        enemy.telegraphCooldownSec <= 0 &&
        target &&
        distToTarget <= enemy.telegraphRadius + 30
      ) {
        const angle = Math.atan2(target.y - enemy.y, target.x - enemy.x);
        enemy.facingAngle = angle;
        const centerX =
          enemy.telegraphKind === 'cleave'
            ? this.clampUnitX(enemy.x + Math.cos(angle) * 28)
            : enemy.x;
        const centerY =
          enemy.telegraphKind === 'cleave'
            ? this.clampUnitY(enemy.y + Math.sin(angle) * 28)
            : enemy.y;

        enemy.telegraph = {
          kind: enemy.telegraphKind,
          x: centerX,
          y: centerY,
          radius: enemy.telegraphRadius,
          remainingSec: enemy.telegraphWindupSec,
          totalSec: enemy.telegraphWindupSec,
        };
        continue;
      }

      const aggroRange = enemy.def.isRanged ? enemy.def.attackRange + 40 : 175;
      if (target && distToTarget <= aggroRange) {
        const reach = enemy.def.attackRange + target.radius;
        if (distToTarget <= reach) {
          enemy.facingAngle = Math.atan2(target.y - enemy.y, target.x - enemy.x);
          if (enemy.attackCooldownSec <= 0) {
            enemy.attackCooldownSec = enemy.def.attackIntervalSec;
            if (enemy.def.isRanged) {
              events.push({
                type: 'arrow_shot',
                fromX: enemy.x,
                fromY: enemy.y,
                toX: target.x,
                toY: target.y,
                isPlayerSide: false,
              });
            }
            if (target.kind === 'hero') {
              this.damageHero(enemy.def.attack, false, events);
            } else {
              this.damageSoldier(target.soldier, enemy.def.attack, enemy.def.isRanged, false, events);
            }
          }
        } else {
          const dx = target.x - enemy.x;
          const dy = target.y - enemy.y;
          const len = Math.hypot(dx, dy) || 1;
          enemy.x = this.clampUnitX(enemy.x + (dx / len) * enemy.def.moveSpeed * dt);
          enemy.y = this.clampUnitY(enemy.y + (dy / len) * enemy.def.moveSpeed * dt);
          enemy.facingAngle = Math.atan2(dy, dx);
        }
        continue;
      }

      // March toward gate
      const gateTargetX = this.gateX + enemy.radius + 4;
      const gateTargetY = clamp(enemy.y, this.arenaHeight * 0.25, this.arenaHeight * 0.75);
      if (enemy.x <= gateTargetX + 8) {
        enemy.facingAngle = Math.PI;
        if (enemy.attackCooldownSec <= 0) {
          enemy.attackCooldownSec = enemy.def.attackIntervalSec;
          this.gateHp = Math.max(0, this.gateHp - enemy.def.gateDamage);
          events.push({
            type: 'gate_hit',
            x: this.gateX,
            y: enemy.y,
            amount: enemy.def.gateDamage,
            gateHpRemaining: this.gateHp,
          });
        }
      } else {
        const dx = gateTargetX - enemy.x;
        const dy = gateTargetY - enemy.y;
        const len = Math.hypot(dx, dy) || 1;
        enemy.x = clamp(enemy.x + (dx / len) * enemy.def.moveSpeed * dt, this.gateX + enemy.radius, this.arenaWidth - 16);
        enemy.y = this.clampUnitY(enemy.y + (dy / len) * enemy.def.moveSpeed * dt);
        enemy.facingAngle = Math.atan2(dy, dx);
      }
    }
  }

  private resolveCommanderSlam(
    enemy: InternalEnemy,
    telegraph: EnemyTelegraph,
    events: CombatEvent[],
  ): void {
    events.push({
      type: 'commander_slam',
      x: telegraph.x,
      y: telegraph.y,
      radius: telegraph.radius,
    });

    // Check hero hit (i-frames avoid damage!)
    if (this.hero.alive) {
      const dist = Math.hypot(this.hero.x - telegraph.x, this.hero.y - telegraph.y);
      if (dist <= telegraph.radius + this.hero.radius) {
        this.damageHero(enemy.telegraphDamage, true, events);
      }
    }

    // Check soldiers hit
    for (const soldier of this.soldiers) {
      if (!soldier.alive) continue;
      const dist = Math.hypot(soldier.x - telegraph.x, soldier.y - telegraph.y);
      if (dist <= telegraph.radius + this.regimentDef.radius) {
        this.damageSoldier(soldier, enemy.telegraphDamage, false, true, events);
      }
    }
  }

  private damageHero(rawAmount: number, isAoe: boolean, events: CombatEvent[]): void {
    const h = this.hero;
    if (!h.alive) return;
    if (h.invulnerableRemainingSec > 0) return;

    const dr = h.warcryRemainingSec > 0 ? 0.8 : 1;
    const finalDmg = Math.max(1, Math.round(rawAmount * dr));
    h.hp = Math.max(0, h.hp - finalDmg);

    events.push({
      type: 'damage',
      x: h.x,
      y: h.y,
      amount: finalDmg,
      isCrit: isAoe,
      targetTeam: 'player',
    });

    if (h.hp <= 0) {
      h.alive = false;
      h.respawnRemainingSec = HERO_RESPAWN_SEC;
      h.warcryRemainingSec = 0;
      events.push({ type: 'unit_died', x: h.x, y: h.y, team: 'hero' });
      events.push({ type: 'hero_down', x: h.x, y: h.y, respawnSec: HERO_RESPAWN_SEC });
    }
  }

  private damageSoldier(
    soldier: InternalSoldier,
    rawAmount: number,
    isRanged: boolean,
    isAoe: boolean,
    events: CombatEvent[],
  ): void {
    if (!soldier.alive) return;

    let mult = 1;
    let blocked = false;
    if (soldier.shieldBlocking) {
      mult *= isRanged ? 0.4 : 0.55;
      blocked = true;
    }
    if (this.regimentDef.type === 'archers' && this.regimentFormation === 'spread' && isAoe) {
      mult *= 0.65;
    }
    if (soldier.buffRemainingSec > 0) {
      mult *= 0.8;
    }

    const mitigated = rawAmount * mult - this.regimentDef.defense * 0.45;
    const finalDmg = Math.max(1, Math.round(mitigated));
    soldier.hp = Math.max(0, soldier.hp - finalDmg);

    events.push({
      type: 'damage',
      x: soldier.x,
      y: soldier.y,
      amount: finalDmg,
      isCrit: isAoe,
      targetTeam: 'player',
      blocked,
    });

    if (soldier.hp <= 0) {
      soldier.alive = false;
      events.push({ type: 'unit_died', x: soldier.x, y: soldier.y, team: 'regiment' });
    }
  }

  private damageEnemy(
    enemy: InternalEnemy,
    rawAmount: number,
    armorPen: number,
    isCrit: boolean,
    fromHero: boolean,
    events: CombatEvent[],
  ): void {
    if (!enemy.alive) return;
    const effectiveDef = enemy.def.defense * (1 - armorPen);
    const finalDmg = Math.max(1, Math.round(rawAmount - effectiveDef * 0.5));
    enemy.hp = Math.max(0, enemy.hp - finalDmg);

    if (fromHero) {
      this.hero.damageDealt += finalDmg;
    }

    events.push({
      type: 'damage',
      x: enemy.x,
      y: enemy.y,
      amount: finalDmg,
      isCrit,
      targetTeam: 'enemy',
    });

    if (enemy.hp <= 0) {
      enemy.alive = false;
      enemy.telegraph = undefined;
      this.defeatedEnemies += 1;
      if (fromHero) {
        this.hero.kills += 1;
      }
      events.push({
        type: 'unit_died',
        x: enemy.x,
        y: enemy.y,
        team: 'enemy',
        isCommander: enemy.isCommander,
      });
    }
  }

  private findNearestEnemy(x: number, y: number): InternalEnemy | undefined {
    let best: InternalEnemy | undefined;
    let bestDistSq = Infinity;
    for (const enemy of this.enemies) {
      if (!enemy.alive) continue;
      const dx = enemy.x - x;
      const dy = enemy.y - y;
      const dSq = dx * dx + dy * dy;
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        best = enemy;
      }
    }
    return best;
  }

  private findNearestPlayerTarget(
    enemy: InternalEnemy,
  ):
    | { kind: 'hero'; x: number; y: number; radius: number }
    | { kind: 'soldier'; soldier: InternalSoldier; x: number; y: number; radius: number }
    | undefined {
    let best:
      | { kind: 'hero'; x: number; y: number; radius: number }
      | { kind: 'soldier'; soldier: InternalSoldier; x: number; y: number; radius: number }
      | undefined;
    let bestDistSq = Infinity;

    if (this.hero.alive) {
      const dx = this.hero.x - enemy.x;
      const dy = this.hero.y - enemy.y;
      bestDistSq = dx * dx + dy * dy;
      best = { kind: 'hero', x: this.hero.x, y: this.hero.y, radius: this.hero.radius };
    }

    for (const soldier of this.soldiers) {
      if (!soldier.alive) continue;
      const dx = soldier.x - enemy.x;
      const dy = soldier.y - enemy.y;
      const dSq = dx * dx + dy * dy;
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        best = {
          kind: 'soldier',
          soldier,
          x: soldier.x,
          y: soldier.y,
          radius: this.regimentDef.radius,
        };
      }
    }

    return best;
  }

  private applySoftSeparation(): void {
    const soldierMinDist = this.regimentDef.radius * 1.9;
    for (let i = 0; i < this.soldiers.length; i += 1) {
      const a = this.soldiers[i];
      if (!a.alive) continue;
      for (let j = i + 1; j < this.soldiers.length; j += 1) {
        const b = this.soldiers[j];
        if (!b.alive) continue;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist = Math.hypot(dx, dy);
        if (dist > 0.01 && dist < soldierMinDist) {
          const push = (soldierMinDist - dist) * 0.25;
          const nx = dx / dist;
          const ny = dy / dist;
          a.x = this.clampUnitX(a.x - nx * push);
          a.y = this.clampUnitY(a.y - ny * push);
          b.x = this.clampUnitX(b.x + nx * push);
          b.y = this.clampUnitY(b.y + ny * push);
        }
      }
    }

    for (let i = 0; i < this.enemies.length; i += 1) {
      const a = this.enemies[i];
      if (!a.alive) continue;
      for (let j = i + 1; j < this.enemies.length; j += 1) {
        const b = this.enemies[j];
        if (!b.alive) continue;
        const minDist = (a.radius + b.radius) * 0.9;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist = Math.hypot(dx, dy);
        if (dist > 0.01 && dist < minDist) {
          const push = (minDist - dist) * 0.25;
          const nx = dx / dist;
          const ny = dy / dist;
          a.x = clamp(a.x - nx * push, this.gateX + a.radius, this.arenaWidth - 16);
          a.y = this.clampUnitY(a.y - ny * push);
          b.x = clamp(b.x + nx * push, this.gateX + b.radius, this.arenaWidth - 16);
          b.y = this.clampUnitY(b.y + ny * push);
        }
      }
    }
  }

  private checkCombatEnd(events: CombatEvent[]): void {
    if (this.gateHp <= 0) {
      this.gateHp = 0;
      this.status = 'defeat';
      events.push({ type: 'combat_ended', status: 'defeat' });
      return;
    }

    const allSpawned = this.pendingSpawns.every((p) => p.spawned);
    if (allSpawned && this.defeatedEnemies >= this.totalEnemies) {
      this.status = 'victory';
      events.push({ type: 'combat_ended', status: 'victory' });
    }
  }
}
