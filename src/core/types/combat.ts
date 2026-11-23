export type RegimentType = 'shieldmen' | 'pikemen' | 'archers';

export type RegimentOrder = 'follow' | 'hold' | 'engage';

export type RegimentFormation = 'compact' | 'spread';

export type EnemyUnitType =
  | 'goblin_raider'
  | 'shield_orc'
  | 'skeleton_archer'
  | 'berserker'
  | 'enemy_commander';

export type CombatStatus = 'running' | 'victory' | 'defeat';

export interface PlayerInput {
  moveX: number; // -1..1
  moveY: number; // -1..1
  aimX: number; // world X
  aimY: number; // world Y
  attackPressed: boolean;
  dodgePressed: boolean;
  skill1Pressed: boolean; // 破陣衝鋒 (Q / RMB)
  skill2Pressed: boolean; // 戰意咆哮 (E)
}

export type RegimentCommand =
  | { type: 'order'; order: RegimentOrder; targetX?: number; targetY?: number }
  | { type: 'formation'; formation: RegimentFormation }
  | { type: 'skill'; targetX: number; targetY: number };

export interface HeroState {
  name: string;
  x: number;
  y: number;
  radius: number;
  facingAngle: number;
  hp: number;
  maxHp: number;
  stamina: number;
  maxStamina: number;
  alive: boolean;
  respawnRemainingSec: number;
  comboStep: 0 | 1 | 2;
  attackCooldownSec: number;
  dodgeRemainingSec: number;
  invulnerableRemainingSec: number;
  skill1CooldownSec: number;
  skill1MaxCooldownSec: number;
  skill2CooldownSec: number;
  skill2MaxCooldownSec: number;
  warcryRemainingSec: number;
  kills: number;
  damageDealt: number;
}

export interface SoldierState {
  id: string;
  index: number;
  x: number;
  y: number;
  facingAngle: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  slotX: number;
  slotY: number;
  attackCooldownSec: number;
  shieldBlocking: boolean;
  chargingRemainingSec: number;
}

export interface RegimentState {
  type: RegimentType;
  name: string;
  description: string;
  order: RegimentOrder;
  formation: RegimentFormation;
  anchorX: number;
  anchorY: number;
  skillName: string;
  skillCooldownSec: number;
  skillMaxCooldownSec: number;
  aliveCount: number;
  maxCount: number;
  soldiers: SoldierState[];
}

export interface EnemyTelegraph {
  kind: 'cleave' | 'whirlwind';
  x: number;
  y: number;
  radius: number;
  remainingSec: number;
  totalSec: number;
}

export interface EnemyState {
  id: string;
  type: EnemyUnitType;
  name: string;
  isCommander: boolean;
  x: number;
  y: number;
  radius: number;
  facingAngle: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  telegraph?: EnemyTelegraph;
}

export interface PendingVolley {
  id: string;
  x: number;
  y: number;
  radius: number;
  remainingSec: number;
  totalSec: number;
  damage: number;
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
  waveNumber: number;
  waveName: string;
  waveDescription: string;
  totalEnemies: number;
  defeatedEnemies: number;
  hero: HeroState;
  regiment: RegimentState;
  enemies: EnemyState[];
  pendingVolleys: PendingVolley[];
}

export type CombatEvent =
  | {
      type: 'hero_slash';
      x: number;
      y: number;
      angle: number;
      radius: number;
      arcRad: number;
      comboStep: 0 | 1 | 2;
    }
  | {
      type: 'hero_charge';
      fromX: number;
      fromY: number;
      toX: number;
      toY: number;
    }
  | {
      type: 'hero_warcry';
      x: number;
      y: number;
      radius: number;
    }
  | {
      type: 'hero_dodge';
      x: number;
      y: number;
      angle: number;
    }
  | {
      type: 'hero_down';
      x: number;
      y: number;
      respawnSec: number;
    }
  | {
      type: 'hero_respawn';
      x: number;
      y: number;
    }
  | {
      type: 'regiment_command';
      commandType: 'order' | 'formation' | 'skill';
      order?: RegimentOrder;
      formation?: RegimentFormation;
      x: number;
      y: number;
      label: string;
    }
  | {
      type: 'arrow_shot';
      fromX: number;
      fromY: number;
      toX: number;
      toY: number;
      isPlayerSide: boolean;
    }
  | {
      type: 'volley_impact';
      x: number;
      y: number;
      radius: number;
    }
  | {
      type: 'commander_slam';
      x: number;
      y: number;
      radius: number;
    }
  | {
      type: 'damage';
      x: number;
      y: number;
      amount: number;
      isCrit: boolean;
      targetTeam: 'player' | 'enemy';
      blocked?: boolean;
    }
  | {
      type: 'gate_hit';
      x: number;
      y: number;
      amount: number;
      gateHpRemaining: number;
    }
  | {
      type: 'unit_died';
      x: number;
      y: number;
      team: 'hero' | 'regiment' | 'enemy';
      isCommander?: boolean;
    }
  | {
      type: 'combat_ended';
      status: 'victory' | 'defeat';
    };

export interface CombatTickResult {
  snapshot: CombatSnapshot;
  events: CombatEvent[];
}

export interface RegimentDefinition {
  type: RegimentType;
  name: string;
  description: string;
  count: number;
  maxHp: number;
  attack: number;
  defense: number;
  attackRange: number;
  attackIntervalSec: number;
  moveSpeed: number;
  radius: number;
  isRanged: boolean;
  skillName: string;
  skillCooldownSec: number;
  compactLabel: string;
  spreadLabel: string;
}

export interface EnemyDefinition {
  type: EnemyUnitType;
  name: string;
  isCommander: boolean;
  maxHp: number;
  attack: number;
  defense: number;
  attackRange: number;
  attackIntervalSec: number;
  moveSpeed: number;
  radius: number;
  isRanged: boolean;
  gateDamage: number;
  telegraphKind?: 'cleave' | 'whirlwind';
  telegraphRadius?: number;
  telegraphWindupSec?: number;
  telegraphCooldownSec?: number;
  telegraphDamage?: number;
}

export interface WaveSpawnEntry {
  type: EnemyUnitType;
  count: number;
  spawnTimeSec: number;
  spawnY?: number;
  spawnX?: number;
  customName?: string;
  hpMultiplier?: number;
  telegraphKind?: 'cleave' | 'whirlwind';
  telegraphRadius?: number;
}

export interface WaveDefinition {
  waveNumber: number;
  name: string;
  description: string;
  spawns: WaveSpawnEntry[];
}

export interface CombatConfig {
  regimentType?: RegimentType;
  wave?: WaveDefinition | number;
  seed?: number;
  arenaWidth?: number;
  arenaHeight?: number;
  gateX?: number;
  gateMaxHp?: number;
}
