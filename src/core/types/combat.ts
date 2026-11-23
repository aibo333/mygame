export type SquadRole = 'tank' | 'dps' | 'support';

export type EnemyArchetype = 'goblin' | 'archer' | 'bomber' | 'brute';

export type TacticalStance = 'defense' | 'assault' | 'scatter';

export type CombatStatus = 'running' | 'victory' | 'defeat';

export type SkillTriggerCondition =
  | 'always'
  | 'self_hp_below_55'
  | 'any_ally_hp_below_45'
  | 'elite_or_multi_enemies';

export type SkillEffectType =
  | 'self_shield_taunt'
  | 'damage_reduction_self_heal'
  | 'single_target_burst'
  | 'aoe_volley'
  | 'heal_lowest_ally'
  | 'party_heal_shield';

export interface Vec2 {
  x: number;
  y: number;
}

export interface SkillDefinition {
  id: string;
  name: string;
  description: string;
  effectType: SkillEffectType;
  cooldownSec: number;
  maxChargesPerWave?: number;
  triggerCondition: SkillTriggerCondition;
  damageMultiplier?: number;
  healAmount?: number;
  shieldAmount?: number;
  aoeRadius?: number;
  tauntRadius?: number;
  tauntDurationSec?: number;
  damageReductionRatio?: number;
  buffDurationSec?: number;
}

export interface SkillRuntimeState {
  skillId: string;
  name: string;
  description: string;
  effectType: SkillEffectType;
  cooldownSec: number;
  cooldownRemainingSec: number;
  maxChargesPerWave: number | null;
  chargesRemaining: number | null;
  triggerCondition: SkillTriggerCondition;
  timesCast: number;
}

export interface HeroDefinition {
  id: string;
  name: string;
  title: string;
  role: SquadRole;
  maxHp: number;
  atk: number;
  def: number;
  attackSpeed: number;
  attackRange: number;
  moveSpeed: number;
  interceptRadius: number;
  critChance: number;
  critMultiplier: number;
  radius: number;
  skills: SkillDefinition[];
}

export interface HeroStatsTelemetry {
  damageDealt: number;
  damageTaken: number;
  healingDone: number;
  kills: number;
}

export interface HeroState {
  id: string;
  name: string;
  title: string;
  role: SquadRole;
  x: number;
  y: number;
  radius: number;
  hp: number;
  maxHp: number;
  shield: number;
  atk: number;
  def: number;
  attackSpeed: number;
  attackRange: number;
  moveSpeed: number;
  interceptRadius: number;
  critChance: number;
  critMultiplier: number;
  attackCooldownSec: number;
  damageReductionRatio: number;
  damageReductionRemainingSec: number;
  alive: boolean;
  targetEnemyId: string | null;
  skills: SkillRuntimeState[];
  stats: HeroStatsTelemetry;
}

export interface EnemyDefinition {
  archetype: EnemyArchetype;
  name: string;
  description: string;
  isElite: boolean;
  maxHp: number;
  atk: number;
  def: number;
  attackSpeed: number;
  attackRange: number;
  moveSpeed: number;
  gateDamage: number;
  threatPriority: number;
  radius: number;
  aoeRadius?: number;
  isExplosive?: boolean;
}

export interface EnemyState {
  id: string;
  archetype: EnemyArchetype;
  name: string;
  isElite: boolean;
  x: number;
  y: number;
  radius: number;
  hp: number;
  maxHp: number;
  atk: number;
  def: number;
  attackSpeed: number;
  attackRange: number;
  moveSpeed: number;
  gateDamage: number;
  threatPriority: number;
  aoeRadius?: number;
  isExplosive?: boolean;
  attackCooldownSec: number;
  alive: boolean;
  tauntedByHeroId: string | null;
  tauntRemainingSec: number;
  engagedHeroId: string | null;
  targetKind: 'gate' | 'hero';
}

export interface WaveSpawnEntry {
  spawnTimeSec: number;
  archetype: EnemyArchetype;
  laneY: number;
  spawnX?: number;
}

export interface WaveDefinition {
  id: string;
  waveNumber: number;
  name: string;
  description: string;
  recommendedStanceHint: string;
  spawns: WaveSpawnEntry[];
}

export interface StanceModifier {
  stance: TacticalStance;
  label: string;
  shortLabel: string;
  description: string;
  teamAtkMultiplier: number;
  dpsDamageMultiplier: number;
  attackSpeedMultiplier: number;
  damageTakenMultiplier: number;
  aoeDamageTakenMultiplier: number;
  healMultiplier: number;
  moveSpeedMultiplier: number;
  tankInterceptRadiusMultiplier: number;
}

export type CombatEvent =
  | {
      type: 'damage';
      timeSec: number;
      sourceId: string;
      sourceTeam: 'hero' | 'enemy';
      targetId: string;
      targetTeam: 'hero' | 'enemy';
      amount: number;
      shieldAbsorbed: number;
      isCrit: boolean;
      isAoe: boolean;
      skillId?: string;
      x: number;
      y: number;
    }
  | {
      type: 'heal';
      timeSec: number;
      sourceId: string;
      targetId: string;
      amount: number;
      skillId?: string;
      x: number;
      y: number;
    }
  | {
      type: 'shield';
      timeSec: number;
      sourceId: string;
      targetId: string;
      amount: number;
      skillId?: string;
      x: number;
      y: number;
    }
  | {
      type: 'skill_cast';
      timeSec: number;
      heroId: string;
      heroName: string;
      skillId: string;
      skillName: string;
      x: number;
      y: number;
      targetX?: number;
      targetY?: number;
      radius?: number;
    }
  | {
      type: 'stance_changed';
      timeSec: number;
      previousStance: TacticalStance;
      nextStance: TacticalStance;
    }
  | {
      type: 'gate_hit';
      timeSec: number;
      enemyId: string;
      amount: number;
      gateHpRemaining: number;
      x: number;
      y: number;
    }
  | {
      type: 'enemy_spawned';
      timeSec: number;
      enemyId: string;
      archetype: EnemyArchetype;
      isElite: boolean;
      x: number;
      y: number;
    }
  | {
      type: 'unit_died';
      timeSec: number;
      unitId: string;
      team: 'hero' | 'enemy';
      killerId?: string;
      x: number;
      y: number;
    }
  | {
      type: 'combat_ended';
      timeSec: number;
      status: 'victory' | 'defeat';
      gateHpRemaining: number;
      totalKills: number;
    };

export interface StanceChangeResult {
  accepted: boolean;
  reason?: 'cooldown' | 'same_stance' | 'combat_ended';
  currentStance: TacticalStance;
  cooldownRemainingSec: number;
  event?: Extract<CombatEvent, { type: 'stance_changed' }>;
}

export interface WaveProgressSnapshot {
  id: string;
  waveNumber: number;
  name: string;
  totalEnemies: number;
  spawnedEnemies: number;
  defeatedEnemies: number;
  aliveEnemies: number;
}

export interface CombatSnapshot {
  tick: number;
  elapsedSec: number;
  status: CombatStatus;
  arenaWidth: number;
  arenaHeight: number;
  gateX: number;
  gateHp: number;
  gateMaxHp: number;
  stance: TacticalStance;
  stanceCooldownRemainingSec: number;
  stanceCooldownSec: number;
  wave: WaveProgressSnapshot;
  heroes: HeroState[];
  enemies: EnemyState[];
  totalDamageDealt: number;
  totalHealingDone: number;
}

export interface CombatTickResult {
  snapshot: CombatSnapshot;
  events: CombatEvent[];
}

export interface CombatConfig {
  wave?: WaveDefinition;
  squad?: HeroDefinition[];
  initialStance?: TacticalStance;
  arenaWidth?: number;
  arenaHeight?: number;
  gateX?: number;
  gateMaxHp?: number;
  stanceCooldownSec?: number;
  seed?: number;
}
