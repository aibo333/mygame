import Phaser from 'phaser';
import type {
  CombatEvent,
  CombatSnapshot,
  EnemyState,
  EnemyUnitType,
  HeroState,
  RegimentOrder,
  RegimentType,
  SoldierState,
} from '../core/types/combat';
import type { PointerWorldState } from './BattlefieldController';
import {
  HERO_TEXTURE_KEY,
  generateBattleTextures,
  getEnemyTextureKey,
  getSoldierTextureKey,
} from './pixelSprites';

export const DEFAULT_ARENA_WIDTH = 1080;
export const DEFAULT_ARENA_HEIGHT = 600;
export const DEFAULT_GATE_X = 80;

const ENEMY_BURST_COLOR: Record<EnemyUnitType, number> = {
  goblin_raider: 0x4ade80,
  shield_orc: 0xef4444,
  skeleton_archer: 0xc084fc,
  berserker: 0xf97316,
  enemy_commander: 0xfacc15,
};

const ORDER_PING_COLOR: Record<RegimentOrder, number> = {
  follow: 0x34d399,
  hold: 0x38bdf8,
  engage: 0xf59e0b,
};

interface HeroVisual {
  container: Phaser.GameObjects.Container;
  shadow: Phaser.GameObjects.Ellipse;
  warcryRing: Phaser.GameObjects.Arc;
  sprite: Phaser.GameObjects.Image;
  barGraphics: Phaser.GameObjects.Graphics;
  currentX: number;
  currentY: number;
  targetX: number;
  targetY: number;
  facingAngle: number;
  alive: boolean;
  hitFlashUntil: number;
  nextGhostAt: number;
  bobPhase: number;
}

interface SoldierVisual {
  id: string;
  regimentType: RegimentType;
  container: Phaser.GameObjects.Container;
  shadow: Phaser.GameObjects.Ellipse;
  shieldGraphics: Phaser.GameObjects.Graphics;
  sprite: Phaser.GameObjects.Image;
  barGraphics: Phaser.GameObjects.Graphics;
  currentX: number;
  currentY: number;
  targetX: number;
  targetY: number;
  facingAngle: number;
  shieldBlocking: boolean;
  charging: boolean;
  alive: boolean;
  hitFlashUntil: number;
  nextChargeTrailAt: number;
  bobPhase: number;
}

interface EnemyVisual {
  id: string;
  type: EnemyUnitType;
  isCommander: boolean;
  container: Phaser.GameObjects.Container;
  shadow: Phaser.GameObjects.Ellipse;
  sprite: Phaser.GameObjects.Image;
  barGraphics: Phaser.GameObjects.Graphics;
  bossTag: Phaser.GameObjects.Text | null;
  currentX: number;
  currentY: number;
  targetX: number;
  targetY: number;
  facingAngle: number;
  alive: boolean;
  hitFlashUntil: number;
  bobPhase: number;
}

interface TorchFlicker {
  glow: Phaser.GameObjects.Arc;
  flame: Phaser.GameObjects.Rectangle;
  phase: number;
}

export class BattleScene extends Phaser.Scene {
  private isReady = false;
  private pendingSnapshot: CombatSnapshot | null = null;
  private pendingEvents: CombatEvent[] = [];
  private latestSnapshot: CombatSnapshot | null = null;
  private lastTick = -1;

  private arenaWidth = DEFAULT_ARENA_WIDTH;
  private arenaHeight = DEFAULT_ARENA_HEIGHT;
  private gateX = DEFAULT_GATE_X;

  private pointerState: PointerWorldState = {
    x: DEFAULT_ARENA_WIDTH / 2,
    y: DEFAULT_ARENA_HEIGHT / 2,
    leftDown: false,
    rightDown: false,
  };
  private pointerInsideCanvas = false;

  // Entity visuals
  private heroVisual: HeroVisual | null = null;
  private soldierVisuals = new Map<string, SoldierVisual>();
  private enemyVisuals = new Map<string, EnemyVisual>();

  // Environment & overlays
  private torches: TorchFlicker[] = [];
  private gateDamageFlash!: Phaser.GameObjects.Rectangle;
  private gateHpGraphics!: Phaser.GameObjects.Graphics;
  private gateHpText!: Phaser.GameObjects.Text;
  private heroRespawnText!: Phaser.GameObjects.Text;

  private formationOverlayGraphics!: Phaser.GameObjects.Graphics;
  private bannerContainer!: Phaser.GameObjects.Container;
  private bannerClothGraphics!: Phaser.GameObjects.Graphics;

  private telegraphGraphics!: Phaser.GameObjects.Graphics;
  private heroGroundGraphics!: Phaser.GameObjects.Graphics;
  private edgePulseGraphics!: Phaser.GameObjects.Graphics;
  private edgePulseAlpha = 0;
  private edgePulseColor = 0xfacc15;
  private crosshairGraphics!: Phaser.GameObjects.Graphics;

  private blurHandler: (() => void) | null = null;

  constructor() {
    super({ key: 'BattleScene' });
  }

  public getPointerState(): PointerWorldState {
    return {
      x: this.pointerState.x,
      y: this.pointerState.y,
      leftDown: this.pointerState.leftDown,
      rightDown: this.pointerState.rightDown,
    };
  }

  public create(): void {
    generateBattleTextures(this);

    this.cameras.main.setBackgroundColor('#0b1120');

    // Disable browser context menu on right-click
    this.input.mouse?.disableContextMenu();
    this.setupPointerListeners();

    if (this.pendingSnapshot) {
      this.arenaWidth = this.pendingSnapshot.arenaWidth || DEFAULT_ARENA_WIDTH;
      this.arenaHeight = this.pendingSnapshot.arenaHeight || DEFAULT_ARENA_HEIGHT;
      this.gateX = this.pendingSnapshot.gateX || DEFAULT_GATE_X;
    }

    this.buildBattleground();
    this.buildCastleWall();
    this.buildOverlays();

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.handleShutdown, this);
    this.events.once(Phaser.Scenes.Events.DESTROY, this.handleShutdown, this);

    this.isReady = true;

    if (this.pendingSnapshot) {
      const snap = this.pendingSnapshot;
      const evts = this.pendingEvents;
      this.pendingSnapshot = null;
      this.pendingEvents = [];
      this.applyState(snap, evts);
    }
  }

  public syncState(snapshot: CombatSnapshot, events: CombatEvent[]): void {
    if (!this.isReady) {
      this.pendingSnapshot = snapshot;
      if (events.length > 0) {
        this.pendingEvents.push(...events);
        if (this.pendingEvents.length > 100) {
          this.pendingEvents = this.pendingEvents.slice(-100);
        }
      }
      return;
    }
    this.applyState(snapshot, events);
  }

  private setupPointerListeners(): void {
    const updateFromPointer = (pointer: Phaser.Input.Pointer): void => {
      this.pointerInsideCanvas = true;
      this.pointerState.x = Phaser.Math.Clamp(pointer.worldX, 0, this.arenaWidth);
      this.pointerState.y = Phaser.Math.Clamp(pointer.worldY, 0, this.arenaHeight);
      this.pointerState.leftDown = pointer.leftButtonDown();
      this.pointerState.rightDown = pointer.rightButtonDown();
    };

    this.input.on('pointermove', updateFromPointer);
    this.input.on('pointerdown', updateFromPointer);
    this.input.on('pointerup', updateFromPointer);
    this.input.on('pointerupoutside', () => {
      this.pointerState.leftDown = false;
      this.pointerState.rightDown = false;
    });
    this.input.on('gameout', () => {
      this.pointerInsideCanvas = false;
      this.pointerState.leftDown = false;
      this.pointerState.rightDown = false;
    });
    this.input.on('gameover', () => {
      this.pointerInsideCanvas = true;
    });

    this.blurHandler = () => {
      this.pointerState.leftDown = false;
      this.pointerState.rightDown = false;
    };
    window.addEventListener('blur', this.blurHandler);
  }

  private handleShutdown(): void {
    this.isReady = false;
    if (this.blurHandler) {
      window.removeEventListener('blur', this.blurHandler);
      this.blurHandler = null;
    }
    this.clearAllUnits();
    this.torches = [];
    this.pendingSnapshot = null;
    this.pendingEvents = [];
    this.latestSnapshot = null;
  }

  private applyState(snapshot: CombatSnapshot, events: CombatEvent[]): void {
    const isReset =
      this.lastTick !== -1 &&
      (snapshot.tick < this.lastTick ||
        (this.latestSnapshot !== null &&
          (snapshot.waveNumber !== this.latestSnapshot.waveNumber ||
            snapshot.regiment.type !== this.latestSnapshot.regiment.type)));

    if (isReset) {
      this.clearAllUnits();
    }

    this.lastTick = snapshot.tick;
    this.latestSnapshot = snapshot;
    this.gateX = snapshot.gateX || DEFAULT_GATE_X;

    this.syncHero(snapshot.hero);
    this.syncRegiment(snapshot);
    this.syncEnemies(snapshot.enemies);
    this.updateGateHpBar(snapshot.gateHp, snapshot.gateMaxHp);

    for (const evt of events) {
      this.handleCombatEvent(evt);
    }

    this.pruneDeadUnits(snapshot);
  }

  public update(time: number, delta: number): void {
    if (!this.isReady) return;

    const dtSec = Math.min(delta / 1000, 0.1);
    const lerpAlpha = 1 - Math.exp(-16 * dtSec);
    const tSec = time / 1000;

    // 1. Animate castle wall torches
    for (const torch of this.torches) {
      const flicker = 0.78 + 0.22 * Math.sin(tSec * 9.5 + torch.phase);
      torch.glow.setAlpha(0.16 * flicker);
      torch.glow.setScale(0.92 + 0.14 * flicker);
      torch.flame.setScale(1, 0.85 + 0.3 * Math.sin(tSec * 14 + torch.phase));
    }

    // 2. Animate hero
    this.updateHeroVisual(time, tSec, lerpAlpha);

    // 3. Animate soldiers
    this.updateSoldierVisuals(time, tSec, lerpAlpha);

    // 4. Animate enemies
    this.updateEnemyVisuals(time, tSec, lerpAlpha);

    // 5. Redraw dynamic ground overlays (formation banner + slots, telegraphs, volleys)
    this.drawFormationOverlay(tSec);
    this.drawTelegraphsAndVolleys(tSec);

    // 6. Decay screen-edge pulse
    if (this.edgePulseAlpha > 0.005) {
      this.edgePulseAlpha = Math.max(0, this.edgePulseAlpha - dtSec * 1.4);
      this.drawEdgePulse();
    } else if (this.edgePulseAlpha > 0) {
      this.edgePulseAlpha = 0;
      this.edgePulseGraphics.clear();
    }

    // 7. Draw tactical mouse crosshair
    this.drawCrosshair(tSec);
  }

  // ---------------------------------------------------------------------------
  // Environment Construction
  // ---------------------------------------------------------------------------

  private buildBattleground(): void {
    const g = this.add.graphics().setDepth(0);
    const tile = 24;
    const roadTop = Math.round(this.arenaHeight * 0.27); // ~162
    const roadBottom = Math.round(this.arenaHeight * 0.73); // ~438

    // Pixel grid checkerboard: dark mossy grass on flanks, packed dirt/cobble on central siege road
    for (let y = 0; y < this.arenaHeight; y += tile) {
      const inRoad = y >= roadTop && y < roadBottom;
      for (let x = this.gateX; x < this.arenaWidth; x += tile) {
        const isAlt = ((Math.floor(x / tile) + Math.floor(y / tile)) & 1) === 0;
        let baseColor: number;
        if (inRoad) {
          baseColor = isAlt ? 0x1b2232 : 0x1f283b;
        } else {
          baseColor = isAlt ? 0x0e1929 : 0x112031;
        }
        g.fillStyle(baseColor, 1);
        g.fillRect(x, y, tile, tile);

        // Subtle pixel grid outline for crisp movement & range readability
        g.lineStyle(1, inRoad ? 0x2a364d : 0x16293d, 0.32);
        g.strokeRect(x, y, tile, tile);

        // Deterministic terrain texture details
        const hash = ((x * 73 + y * 151) ^ (x * 19)) & 0xff;
        if (inRoad) {
          if (hash < 36) {
            // Cobblestone flecks
            g.fillStyle(0x334155, 0.55);
            g.fillRect(x + (hash % 14) + 2, y + ((hash * 5) % 14) + 2, 6, 4);
          } else if (hash > 228) {
            g.fillStyle(0x111827, 0.5);
            g.fillRect(x + (hash % 16) + 2, y + ((hash * 3) % 16) + 2, 4, 2);
          }
        } else {
          if (hash < 44) {
            // Grass tufts
            g.fillStyle(0x164e3f, 0.55);
            g.fillRect(x + (hash % 14) + 2, y + ((hash * 3) % 14) + 2, 4, 2);
            g.fillRect(x + (hash % 14) + 4, y + ((hash * 3) % 14), 2, 2);
          } else if (hash > 236) {
            // Small pebbles
            g.fillStyle(0x334155, 0.45);
            g.fillRect(x + (hash % 16), y + ((hash * 7) % 16), 4, 2);
          }
        }
      }
    }

    // Cobblestone road border curbs
    g.fillStyle(0x334155, 0.8);
    g.fillRect(this.gateX, roadTop - 4, this.arenaWidth - this.gateX, 4);
    g.fillRect(this.gateX, roadBottom, this.arenaWidth - this.gateX, 4);
    g.fillStyle(0x0b1120, 0.7);
    g.fillRect(this.gateX, roadTop - 6, this.arenaWidth - this.gateX, 2);
    g.fillRect(this.gateX, roadBottom + 4, this.arenaWidth - this.gateX, 2);

    // Subtle wheel ruts along central siege road
    const midY = Math.round(this.arenaHeight / 2);
    g.fillStyle(0x0f172a, 0.25);
    g.fillRect(this.gateX, midY - 42, this.arenaWidth - this.gateX, 6);
    g.fillRect(this.gateX, midY + 36, this.arenaWidth - this.gateX, 6);

    // Subtle top & bottom dark perimeter framing
    g.fillStyle(0x070b14, 0.65);
    g.fillRect(this.gateX, 0, this.arenaWidth - this.gateX, 22);
    g.fillRect(this.gateX, this.arenaHeight - 22, this.arenaWidth - this.gateX, 22);

    // Tactical defense line markers near the gate & enemy approach chevrons on right flank
    const guide = this.add.graphics().setDepth(5);
    guide.fillStyle(0x38bdf8, 0.22);
    for (let y = 32; y < this.arenaHeight - 32; y += 16) {
      guide.fillRect(this.gateX + 10, y, 2, 8);
    }

    const approachYs = [130, 300, 470];
    for (const ay of approachYs) {
      guide.lineStyle(2, 0xef4444, 0.2);
      guide.beginPath();
      guide.moveTo(this.arenaWidth - 38, ay - 10);
      guide.lineTo(this.arenaWidth - 50, ay);
      guide.lineTo(this.arenaWidth - 38, ay + 10);
      guide.strokePath();
    }
  }

  private buildCastleWall(): void {
    const g = this.add.graphics().setDepth(8);
    const w = this.gateX;
    const h = this.arenaHeight;

    // Inner stone backdrop
    g.fillStyle(0x0f172a, 1);
    g.fillRect(0, 0, w, h);

    // Stone wall body
    g.fillStyle(0x334155, 1);
    g.fillRect(8, 0, w - 16, h);

    // Pixel mortar / brick grid
    g.fillStyle(0x1e293b, 1);
    for (let y = 0; y < h; y += 16) {
      g.fillRect(8, y, w - 16, 2);
      const offset = (y / 16) % 2 === 0 ? 18 : 30;
      g.fillRect(offset, y, 2, 16);
      g.fillRect(offset + 24, y, 2, 16);
    }

    // Eastern battlements / crenellations facing the battlefield
    for (let y = 8; y < h - 8; y += 28) {
      g.fillStyle(0x475569, 1);
      g.fillRect(w - 10, y, 10, 18);
      g.fillStyle(0x64748b, 1);
      g.fillRect(w - 10, y, 10, 3);
      g.fillStyle(0x0f172a, 1);
      g.fillRect(w - 2, y, 2, 18);
    }

    // Reinforced wooden gatehouse (centered vertically)
    const gateH = 160;
    const gateTop = Math.round((h - gateH) / 2);
    g.fillStyle(0x451a03, 1);
    g.fillRect(12, gateTop, w - 16, gateH);

    // Wood planks
    g.fillStyle(0x78350f, 1);
    for (let y = gateTop + 6; y < gateTop + gateH - 6; y += 14) {
      g.fillRect(14, y, w - 22, 10);
    }

    // Iron reinforcement bands & golden lock emblem
    g.fillStyle(0x94a3b8, 1);
    g.fillRect(12, gateTop + 20, w - 16, 6);
    g.fillRect(12, gateTop + gateH - 26, w - 16, 6);
    g.fillStyle(0xfacc15, 0.9);
    g.fillRect(w - 16, Math.round(h / 2) - 5, 6, 10);

    // Bastion torches
    const torchPositions = [
      { x: w - 6, y: gateTop - 18 },
      { x: w - 6, y: gateTop + gateH + 18 },
      { x: w - 6, y: 84 },
      { x: w - 6, y: h - 84 },
    ];

    for (let i = 0; i < torchPositions.length; i += 1) {
      const tp = torchPositions[i];
      g.fillStyle(0x1e293b, 1);
      g.fillRect(tp.x - 4, tp.y + 2, 8, 6);

      const glow = this.add.circle(tp.x, tp.y - 2, 26, 0xf59e0b, 0.16).setDepth(13);
      const flame = this.add.rectangle(tp.x, tp.y - 2, 6, 8, 0xfbbf24, 1).setDepth(13);
      this.add.rectangle(tp.x, tp.y - 1, 3, 4, 0xfef08a, 1).setDepth(14);

      this.torches.push({ glow, flame, phase: i * 1.7 });
    }

    // Gate damage flash overlay
    this.gateDamageFlash = this.add
      .rectangle(w / 2, h / 2, w + 4, h, 0xef4444, 0)
      .setDepth(35);

    // Gate HP bar & label
    this.gateHpGraphics = this.add.graphics().setDepth(36);
    this.gateHpText = this.add
      .text(8, 10, '城門 500/500', {
        fontFamily: 'monospace, "Microsoft JhengHei", sans-serif',
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#f8fafc',
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setDepth(37);

    // Hero respawn countdown near gate
    this.heroRespawnText = this.add
      .text(w + 14, Math.round(h / 2), '', {
        fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
        fontSize: '13px',
        fontStyle: 'bold',
        color: '#fde047',
        backgroundColor: '#020617cc',
        padding: { x: 8, y: 4 },
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setOrigin(0, 0.5)
      .setDepth(38)
      .setVisible(false);

    this.updateGateHpBar(500, 500);
  }

  private buildOverlays(): void {
    this.formationOverlayGraphics = this.add.graphics().setDepth(10);
    this.telegraphGraphics = this.add.graphics().setDepth(12);
    this.heroGroundGraphics = this.add.graphics().setDepth(15);
    this.edgePulseGraphics = this.add.graphics().setDepth(60);
    this.crosshairGraphics = this.add.graphics().setDepth(90);

    // Regiment Hold Banner / Flag Marker
    this.bannerContainer = this.add.container(0, 0).setDepth(21).setVisible(false);
    const poleShadow = this.add.ellipse(0, 3, 16, 6, 0x020617, 0.55);
    const pole = this.add.rectangle(0, -14, 3, 32, 0xe2e8f0, 1);
    const finial = this.add.rectangle(0, -31, 5, 5, 0xfacc15, 1);
    this.bannerClothGraphics = this.add.graphics();
    this.bannerContainer.add([poleShadow, pole, finial, this.bannerClothGraphics]);
  }

  private updateGateHpBar(hp: number, maxHp: number): void {
    const ratio = maxHp > 0 ? Phaser.Math.Clamp(hp / maxHp, 0, 1) : 0;
    const barX = 8;
    const barY = 26;
    const barW = 128;
    const barH = 8;

    this.gateHpGraphics.clear();
    this.gateHpGraphics.fillStyle(0x020617, 0.88);
    this.gateHpGraphics.fillRect(barX - 2, barY - 2, barW + 4, barH + 4);
    this.gateHpGraphics.fillStyle(0x1e293b, 1);
    this.gateHpGraphics.fillRect(barX, barY, barW, barH);

    const fillColor = ratio > 0.5 ? 0x38bdf8 : ratio > 0.25 ? 0xf59e0b : 0xef4444;
    this.gateHpGraphics.fillStyle(fillColor, 1);
    this.gateHpGraphics.fillRect(barX, barY, Math.round(barW * ratio), barH);

    this.gateHpText.setText(`城門 ${Math.ceil(hp)}/${maxHp}`);
  }

  // ---------------------------------------------------------------------------
  // Entity Syncing
  // ---------------------------------------------------------------------------

  private syncHero(hero: HeroState): void {
    if (!this.heroVisual) {
      const container = this.add.container(hero.x, hero.y).setDepth(20);
      const shadow = this.add.ellipse(0, 15, 26, 9, 0x020617, 0.6);
      const warcryRing = this.add
        .circle(0, 12, 24, 0xfacc15, 0.14)
        .setStrokeStyle(2, 0xfacc15, 0.9)
        .setScale(1, 0.52)
        .setVisible(false);
      const sprite = this.add.image(0, 0, HERO_TEXTURE_KEY).setOrigin(0.5, 0.5);
      const barGraphics = this.add.graphics();

      container.add([shadow, warcryRing, sprite, barGraphics]);

      this.heroVisual = {
        container,
        shadow,
        warcryRing,
        sprite,
        barGraphics,
        currentX: hero.x,
        currentY: hero.y,
        targetX: hero.x,
        targetY: hero.y,
        facingAngle: hero.facingAngle,
        alive: hero.alive,
        hitFlashUntil: 0,
        nextGhostAt: 0,
        bobPhase: 0,
      };
    }

    const hv = this.heroVisual;
    if (Math.hypot(hero.x - hv.currentX, hero.y - hv.currentY) > 180) {
      hv.currentX = hero.x;
      hv.currentY = hero.y;
    }

    hv.targetX = hero.x;
    hv.targetY = hero.y;
    hv.facingAngle = hero.facingAngle;
    hv.alive = hero.alive;
    hv.container.setAlpha(hero.alive ? 1 : 0.25);
    hv.warcryRing.setVisible(hero.alive && hero.warcryRemainingSec > 0);

    // Overhead HP + stamina mini-bar
    this.redrawHeroBars(hv.barGraphics, hero);

    // Respawn countdown at gate when downed
    if (!hero.alive) {
      const secs = Math.max(0, hero.respawnRemainingSec).toFixed(1);
      this.heroRespawnText.setText(`主將復活中 ${secs}s`).setVisible(true);
    } else {
      this.heroRespawnText.setVisible(false);
    }
  }

  private redrawHeroBars(g: Phaser.GameObjects.Graphics, hero: HeroState): void {
    g.clear();
    if (!hero.alive) return;

    const w = 40;
    const hpH = 5;
    const stamH = 3;
    const x = -w / 2;
    const y = -31;

    const hpRatio = hero.maxHp > 0 ? Phaser.Math.Clamp(hero.hp / hero.maxHp, 0, 1) : 0;
    const stamRatio =
      hero.maxStamina > 0 ? Phaser.Math.Clamp(hero.stamina / hero.maxStamina, 0, 1) : 0;

    // Frame
    g.fillStyle(0x020617, 0.9);
    g.fillRect(x - 1, y - 1, w + 2, hpH + stamH + 3);

    // HP bar
    g.fillStyle(0x1e293b, 1);
    g.fillRect(x, y, w, hpH);
    const hpColor = hpRatio > 0.45 ? 0x22c55e : hpRatio > 0.2 ? 0xf59e0b : 0xef4444;
    g.fillStyle(hpColor, 1);
    g.fillRect(x, y, Math.round(w * hpRatio), hpH);

    // Stamina mini-bar
    const sy = y + hpH + 1;
    g.fillStyle(0x0f172a, 1);
    g.fillRect(x, sy, w, stamH);
    g.fillStyle(0x38bdf8, 1);
    g.fillRect(x, sy, Math.round(w * stamRatio), stamH);
  }

  private syncRegiment(snapshot: CombatSnapshot): void {
    const regType = snapshot.regiment.type;

    for (const soldier of snapshot.regiment.soldiers) {
      if (!soldier.alive) continue;

      let sv = this.soldierVisuals.get(soldier.id);
      if (!sv || sv.regimentType !== regType) {
        if (sv) {
          sv.container.destroy();
        }
        sv = this.createSoldierVisual(soldier, regType);
        this.soldierVisuals.set(soldier.id, sv);
      }

      if (Math.hypot(soldier.x - sv.currentX, soldier.y - sv.currentY) > 180) {
        sv.currentX = soldier.x;
        sv.currentY = soldier.y;
      }

      sv.targetX = soldier.x;
      sv.targetY = soldier.y;
      sv.facingAngle = soldier.facingAngle;
      sv.shieldBlocking = soldier.shieldBlocking;
      sv.charging = soldier.chargingRemainingSec > 0;
      sv.alive = soldier.alive;

      this.redrawSoldierBar(sv.barGraphics, soldier.hp, soldier.maxHp);
    }
  }

  private createSoldierVisual(soldier: SoldierState, regType: RegimentType): SoldierVisual {
    const container = this.add.container(soldier.x, soldier.y).setDepth(20);
    const shadow = this.add.ellipse(0, 10, 16, 6, 0x020617, 0.52);
    const shieldGraphics = this.add.graphics();
    const sprite = this.add.image(0, 0, getSoldierTextureKey(regType)).setOrigin(0.5, 0.5);
    const barGraphics = this.add.graphics();

    container.add([shadow, sprite, shieldGraphics, barGraphics]);

    return {
      id: soldier.id,
      regimentType: regType,
      container,
      shadow,
      shieldGraphics,
      sprite,
      barGraphics,
      currentX: soldier.x,
      currentY: soldier.y,
      targetX: soldier.x,
      targetY: soldier.y,
      facingAngle: soldier.facingAngle,
      shieldBlocking: soldier.shieldBlocking,
      charging: soldier.chargingRemainingSec > 0,
      alive: soldier.alive,
      hitFlashUntil: 0,
      nextChargeTrailAt: 0,
      bobPhase: soldier.index * 0.75 + Math.random() * 0.5,
    };
  }

  private redrawSoldierBar(g: Phaser.GameObjects.Graphics, hp: number, maxHp: number): void {
    g.clear();
    if (hp >= maxHp || maxHp <= 0) return;

    const w = 18;
    const h = 3;
    const x = -w / 2;
    const y = -17;
    const ratio = Phaser.Math.Clamp(hp / maxHp, 0, 1);

    g.fillStyle(0x020617, 0.85);
    g.fillRect(x - 1, y - 1, w + 2, h + 2);
    g.fillStyle(0x1e293b, 1);
    g.fillRect(x, y, w, h);
    g.fillStyle(ratio > 0.4 ? 0x38bdf8 : 0xf59e0b, 1);
    g.fillRect(x, y, Math.max(1, Math.round(w * ratio)), h);
  }

  private syncEnemies(enemies: EnemyState[]): void {
    for (const enemy of enemies) {
      if (!enemy.alive) continue;

      let ev = this.enemyVisuals.get(enemy.id);
      if (!ev) {
        ev = this.createEnemyVisual(enemy);
        this.enemyVisuals.set(enemy.id, ev);
      }

      if (Math.hypot(enemy.x - ev.currentX, enemy.y - ev.currentY) > 180) {
        ev.currentX = enemy.x;
        ev.currentY = enemy.y;
      }

      ev.targetX = enemy.x;
      ev.targetY = enemy.y;
      ev.facingAngle = enemy.facingAngle;
      ev.alive = enemy.alive;

      const barW = enemy.isCommander ? 48 : 26;
      const barY = enemy.isCommander ? -32 : -20;
      this.redrawEnemyBar(ev.barGraphics, enemy.hp, enemy.maxHp, barW, barY, enemy.isCommander);
    }
  }

  private createEnemyVisual(enemy: EnemyState): EnemyVisual {
    const container = this.add.container(enemy.x, enemy.y).setDepth(20);
    const shadowW = enemy.isCommander ? 34 : enemy.radius > 13 ? 22 : 17;
    const shadowY = enemy.isCommander ? 18 : 11;
    const shadow = this.add.ellipse(0, shadowY, shadowW, 7, 0x020617, 0.56);

    const sprite = this.add.image(0, 0, getEnemyTextureKey(enemy.type)).setOrigin(0.5, 0.5);
    const barGraphics = this.add.graphics();

    let bossTag: Phaser.GameObjects.Text | null = null;
    if (enemy.isCommander) {
      bossTag = this.add
        .text(0, 24, `★ ${enemy.name}`, {
          fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
          fontSize: '11px',
          fontStyle: 'bold',
          color: '#facc15',
          stroke: '#020617',
          strokeThickness: 3,
        })
        .setOrigin(0.5, 0);
    }

    const children: Phaser.GameObjects.GameObject[] = [shadow, sprite, barGraphics];
    if (bossTag) children.push(bossTag);
    container.add(children);

    return {
      id: enemy.id,
      type: enemy.type,
      isCommander: enemy.isCommander,
      container,
      shadow,
      sprite,
      barGraphics,
      bossTag,
      currentX: enemy.x,
      currentY: enemy.y,
      targetX: enemy.x,
      targetY: enemy.y,
      facingAngle: enemy.facingAngle,
      alive: enemy.alive,
      hitFlashUntil: 0,
      bobPhase: Math.random() * Math.PI * 2,
    };
  }

  private redrawEnemyBar(
    g: Phaser.GameObjects.Graphics,
    hp: number,
    maxHp: number,
    w: number,
    y: number,
    isCommander: boolean,
  ): void {
    g.clear();
    if (!isCommander && hp >= maxHp) return;

    const h = isCommander ? 6 : 4;
    const x = -w / 2;
    const ratio = maxHp > 0 ? Phaser.Math.Clamp(hp / maxHp, 0, 1) : 0;

    g.fillStyle(0x020617, 0.9);
    g.fillRect(x - 1, y - 1, w + 2, h + 2);
    if (isCommander) {
      g.lineStyle(1, 0xfacc15, 0.9);
      g.strokeRect(x - 1.5, y - 1.5, w + 3, h + 3);
    }

    g.fillStyle(0x1e293b, 1);
    g.fillRect(x, y, w, h);
    g.fillStyle(isCommander ? 0xf59e0b : 0xef4444, 1);
    g.fillRect(x, y, Math.max(1, Math.round(w * ratio)), h);
  }

  private pruneDeadUnits(snapshot: CombatSnapshot): void {
    const aliveSoldiers = new Set<string>();
    for (const s of snapshot.regiment.soldiers) {
      if (s.alive) aliveSoldiers.add(s.id);
    }
    for (const [id, sv] of this.soldierVisuals.entries()) {
      if (!aliveSoldiers.has(id)) {
        sv.container.destroy();
        this.soldierVisuals.delete(id);
      }
    }

    const aliveEnemies = new Set<string>();
    for (const e of snapshot.enemies) {
      if (e.alive) aliveEnemies.add(e.id);
    }
    for (const [id, ev] of this.enemyVisuals.entries()) {
      if (!aliveEnemies.has(id)) {
        ev.container.destroy();
        this.enemyVisuals.delete(id);
      }
    }
  }

  private clearAllUnits(): void {
    if (this.heroVisual) {
      this.heroVisual.container.destroy();
      this.heroVisual = null;
    }
    for (const sv of this.soldierVisuals.values()) {
      sv.container.destroy();
    }
    this.soldierVisuals.clear();

    for (const ev of this.enemyVisuals.values()) {
      ev.container.destroy();
    }
    this.enemyVisuals.clear();
  }

  // ---------------------------------------------------------------------------
  // Frame Updates & Overlays
  // ---------------------------------------------------------------------------

  private updateHeroVisual(time: number, tSec: number, lerpAlpha: number): void {
    this.heroGroundGraphics.clear();
    const hv = this.heroVisual;
    const hero = this.latestSnapshot?.hero;
    if (!hv || !hero) return;

    const prevX = hv.currentX;
    const prevY = hv.currentY;
    hv.currentX = Phaser.Math.Linear(hv.currentX, hv.targetX, lerpAlpha);
    hv.currentY = Phaser.Math.Linear(hv.currentY, hv.targetY, lerpAlpha);

    const moveDist = Math.hypot(hv.currentX - prevX, hv.currentY - prevY);
    const bobSpeed = moveDist > 0.35 ? 12 : 4.5;
    const bobAmp = moveDist > 0.35 ? 2.5 : 1.2;
    const bobY = hv.alive ? Math.round(Math.sin(tSec * bobSpeed + hv.bobPhase) * bobAmp) : 0;

    hv.container.setPosition(Math.round(hv.currentX), Math.round(hv.currentY));
    hv.container.setDepth(20 + hv.currentY * 0.01);
    hv.sprite.setY(bobY);
    hv.sprite.setFlipX(Math.cos(hv.facingAngle) < 0);

    // Golden pulsing warcry aura
    if (hv.alive && hero.warcryRemainingSec > 0) {
      const pulse = 0.75 + 0.25 * Math.sin(tSec * 8);
      hv.warcryRing.setScale(0.95 + 0.14 * pulse, 0.5 + 0.07 * pulse);
      hv.warcryRing.setStrokeStyle(2.5, 0xfacc15, 0.65 + 0.3 * pulse);
      hv.warcryRing.setFillStyle(0xfacc15, 0.1 + 0.08 * pulse);
    }

    // Dodge / invulnerability translucent ghost afterimages
    const isDodgingOrInvuln =
      hv.alive && (hero.dodgeRemainingSec > 0 || hero.invulnerableRemainingSec > 0);
    if (isDodgingOrInvuln) {
      hv.sprite.setAlpha(0.72);
      if (time >= hv.nextGhostAt) {
        hv.nextGhostAt = time + 42;
        this.spawnHeroGhost(hv.currentX, hv.currentY + bobY, hv.sprite.flipX);
      }
    } else if (hv.alive) {
      hv.sprite.setAlpha(1);
    }

    if (hv.hitFlashUntil > 0 && time >= hv.hitFlashUntil) {
      hv.hitFlashUntil = 0;
      hv.sprite.clearTint();
    }

    // Directional facing arc + pointer chevron under feet
    if (hv.alive) {
      const gx = hv.currentX;
      const gy = hv.currentY + 11;
      const ang = hv.facingAngle;
      const r = 20;

      // Subtle base ring
      this.heroGroundGraphics.lineStyle(1.5, 0x38bdf8, 0.38);
      this.heroGroundGraphics.strokeCircle(gx, gy, r);

      // Highlighted facing arc
      this.heroGroundGraphics.lineStyle(2.5, 0x7dd3fc, 0.88);
      this.heroGroundGraphics.beginPath();
      this.heroGroundGraphics.arc(gx, gy, r, ang - 0.52, ang + 0.52, false);
      this.heroGroundGraphics.strokePath();

      // Small directional arrow tip at front of arc
      const tipX = gx + Math.cos(ang) * (r + 7);
      const tipY = gy + Math.sin(ang) * (r + 7);
      const leftX = gx + Math.cos(ang - 0.25) * (r + 1);
      const leftY = gy + Math.sin(ang - 0.25) * (r + 1);
      const rightX = gx + Math.cos(ang + 0.25) * (r + 1);
      const rightY = gy + Math.sin(ang + 0.25) * (r + 1);
      this.heroGroundGraphics.fillStyle(0xfacc15, 0.92);
      this.heroGroundGraphics.fillTriangle(tipX, tipY, leftX, leftY, rightX, rightY);
    }
  }

  private spawnHeroGhost(x: number, y: number, flipX: boolean): void {
    const ghost = this.add
      .image(Math.round(x), Math.round(y), HERO_TEXTURE_KEY)
      .setOrigin(0.5, 0.5)
      .setFlipX(flipX)
      .setTint(0x38bdf8)
      .setAlpha(0.55)
      .setDepth(19);

    this.tweens.add({
      targets: ghost,
      alpha: 0,
      scaleX: 1.08,
      scaleY: 1.08,
      duration: 180,
      ease: 'Quad.easeOut',
      onComplete: () => ghost.destroy(),
    });
  }

  private updateSoldierVisuals(time: number, tSec: number, lerpAlpha: number): void {
    for (const sv of this.soldierVisuals.values()) {
      const prevX = sv.currentX;
      const prevY = sv.currentY;
      sv.currentX = Phaser.Math.Linear(sv.currentX, sv.targetX, lerpAlpha);
      sv.currentY = Phaser.Math.Linear(sv.currentY, sv.targetY, lerpAlpha);

      const moveDist = Math.hypot(sv.currentX - prevX, sv.currentY - prevY);
      const bobSpeed = sv.charging ? 16 : moveDist > 0.3 ? 11 : 4.2;
      const bobAmp = sv.charging ? 2.8 : moveDist > 0.3 ? 2.0 : 0.9;
      const bobY = Math.round(Math.sin(tSec * bobSpeed + sv.bobPhase) * bobAmp);

      sv.container.setPosition(Math.round(sv.currentX), Math.round(sv.currentY));
      sv.container.setDepth(20 + sv.currentY * 0.01);
      sv.sprite.setY(bobY);
      sv.sprite.setFlipX(Math.cos(sv.facingAngle) < 0);

      // Shield-glow rim when shieldBlocking
      sv.shieldGraphics.clear();
      if (sv.shieldBlocking) {
        const pulse = 0.7 + 0.3 * Math.sin(tSec * 6 + sv.bobPhase);
        sv.shieldGraphics.lineStyle(2.5, 0x38bdf8, 0.85 * pulse);
        sv.shieldGraphics.beginPath();
        sv.shieldGraphics.arc(0, 1, 13, sv.facingAngle - 0.85, sv.facingAngle + 0.85, false);
        sv.shieldGraphics.strokePath();
      }

      // Charge streak trail when chargingRemainingSec > 0
      if (sv.charging && time >= sv.nextChargeTrailAt) {
        sv.nextChargeTrailAt = time + 55;
        this.spawnChargeStreak(sv.currentX, sv.currentY, sv.facingAngle);
      }

      if (sv.hitFlashUntil > 0 && time >= sv.hitFlashUntil) {
        sv.hitFlashUntil = 0;
        sv.sprite.clearTint();
      }
    }
  }

  private spawnChargeStreak(x: number, y: number, angle: number): void {
    const g = this.add.graphics().setDepth(18);
    const backX = x - Math.cos(angle) * 20;
    const backY = y - Math.sin(angle) * 20;
    g.lineStyle(3, 0x7dd3fc, 0.8);
    g.beginPath();
    g.moveTo(backX, backY);
    g.lineTo(x, y);
    g.strokePath();

    this.tweens.add({
      targets: g,
      alpha: 0,
      duration: 180,
      onComplete: () => g.destroy(),
    });
  }

  private updateEnemyVisuals(time: number, tSec: number, lerpAlpha: number): void {
    for (const ev of this.enemyVisuals.values()) {
      const prevX = ev.currentX;
      const prevY = ev.currentY;
      ev.currentX = Phaser.Math.Linear(ev.currentX, ev.targetX, lerpAlpha);
      ev.currentY = Phaser.Math.Linear(ev.currentY, ev.targetY, lerpAlpha);

      const moveDist = Math.hypot(ev.currentX - prevX, ev.currentY - prevY);
      const bobSpeed =
        ev.type === 'goblin_raider' ? 13 : ev.isCommander ? 6 : 8.5;
      const bobAmp = moveDist > 0.25 ? 2.2 : 1.0;
      const bobY = Math.round(Math.sin(tSec * bobSpeed + ev.bobPhase) * bobAmp);

      ev.container.setPosition(Math.round(ev.currentX), Math.round(ev.currentY));
      ev.container.setDepth(20 + ev.currentY * 0.01);
      ev.sprite.setY(bobY);
      // Enemy pixel art faces left by default
      ev.sprite.setFlipX(Math.cos(ev.facingAngle) > 0);

      if (ev.hitFlashUntil > 0 && time >= ev.hitFlashUntil) {
        ev.hitFlashUntil = 0;
        ev.sprite.clearTint();
      }
    }
  }

  private drawFormationOverlay(tSec: number): void {
    this.formationOverlayGraphics.clear();
    const reg = this.latestSnapshot?.regiment;
    if (!reg || reg.order !== 'hold') {
      this.bannerContainer.setVisible(false);
      return;
    }

    const ax = reg.anchorX;
    const ay = reg.anchorY;
    const pulse = 0.65 + 0.35 * Math.sin(tSec * 4.5);

    // Pulsing anchor ground ring
    this.formationOverlayGraphics.lineStyle(2, 0x38bdf8, 0.55 * pulse);
    this.formationOverlayGraphics.strokeCircle(ax, ay, 18 + 3 * pulse);
    this.formationOverlayGraphics.fillStyle(0x38bdf8, 0.12);
    this.formationOverlayGraphics.fillCircle(ax, ay, 14);

    // Subtle translucent formation slot dots for each alive soldier
    for (const s of reg.soldiers) {
      if (!s.alive) continue;
      this.formationOverlayGraphics.fillStyle(0x38bdf8, 0.22);
      this.formationOverlayGraphics.fillCircle(s.slotX, s.slotY + 8, 5);
      this.formationOverlayGraphics.lineStyle(1, 0x7dd3fc, 0.5);
      this.formationOverlayGraphics.strokeCircle(s.slotX, s.slotY + 8, 5);
    }

    // Position and wave the regiment flag marker
    this.bannerContainer.setVisible(true);
    this.bannerContainer.setPosition(Math.round(ax), Math.round(ay));
    this.bannerContainer.setDepth(20 + ay * 0.01);

    const wave = Math.sin(tSec * 7) * 2;
    this.bannerClothGraphics.clear();
    this.bannerClothGraphics.fillStyle(0x0284c7, 0.95);
    this.bannerClothGraphics.fillTriangle(
      1,
      -29,
      19,
      -24 + wave,
      1,
      -17,
    );
    this.bannerClothGraphics.lineStyle(1.5, 0xfacc15, 0.95);
    this.bannerClothGraphics.strokeTriangle(
      1,
      -29,
      19,
      -24 + wave,
      1,
      -17,
    );
  }

  private drawTelegraphsAndVolleys(tSec: number): void {
    this.telegraphGraphics.clear();
    const snap = this.latestSnapshot;
    if (!snap) return;

    // 1. Enemy Commander Red-Circle Telegraphs
    for (const enemy of snap.enemies) {
      if (!enemy.alive || !enemy.telegraph) continue;
      const t = enemy.telegraph;
      const progress = Phaser.Math.Clamp(
        1 - t.remainingSec / Math.max(0.01, t.totalSec),
        0,
        1,
      );

      // Outer danger zone
      this.telegraphGraphics.fillStyle(0xef4444, 0.14);
      this.telegraphGraphics.fillCircle(t.x, t.y, t.radius);
      this.telegraphGraphics.lineStyle(2.5, 0xef4444, 0.92);
      this.telegraphGraphics.strokeCircle(t.x, t.y, t.radius);

      // Inner expanding fill circle proportional to (1 - remainingSec / totalSec)
      const innerR = Math.max(2, t.radius * progress);
      this.telegraphGraphics.fillStyle(0xdc2626, 0.2 + 0.28 * progress);
      this.telegraphGraphics.fillCircle(t.x, t.y, innerR);
      this.telegraphGraphics.lineStyle(2, 0xfca5a5, 0.75 + 0.25 * progress);
      this.telegraphGraphics.strokeCircle(t.x, t.y, innerR);

      // Perimeter visual cues for whirlwind vs cleave
      if (t.kind === 'whirlwind') {
        this.telegraphGraphics.lineStyle(2, 0xfef08a, 0.7);
        for (let i = 0; i < 4; i += 1) {
          const a = tSec * 4 + (i * Math.PI) / 2;
          this.telegraphGraphics.beginPath();
          this.telegraphGraphics.arc(t.x, t.y, t.radius - 4, a, a + 0.45, false);
          this.telegraphGraphics.strokePath();
        }
      } else {
        // Subtle pulsing warning cross inside cleave circle
        const cross = Math.min(14, t.radius * 0.22);
        this.telegraphGraphics.lineStyle(2, 0xfef08a, 0.55 + 0.35 * progress);
        this.telegraphGraphics.beginPath();
        this.telegraphGraphics.moveTo(t.x - cross, t.y);
        this.telegraphGraphics.lineTo(t.x + cross, t.y);
        this.telegraphGraphics.moveTo(t.x, t.y - cross);
        this.telegraphGraphics.lineTo(t.x, t.y + cross);
        this.telegraphGraphics.strokePath();
      }
    }

    // 2. Archer Pending Volleys
    for (const v of snap.pendingVolleys) {
      const progress = Phaser.Math.Clamp(
        1 - v.remainingSec / Math.max(0.01, v.totalSec),
        0,
        1,
      );

      // Outer emerald reticle
      this.telegraphGraphics.fillStyle(0x10b981, 0.1);
      this.telegraphGraphics.fillCircle(v.x, v.y, v.radius);
      this.telegraphGraphics.lineStyle(2, 0x34d399, 0.88);
      this.telegraphGraphics.strokeCircle(v.x, v.y, v.radius);

      // Inner filling amber-emerald circle
      const innerR = Math.max(2, v.radius * progress);
      this.telegraphGraphics.fillStyle(0xfbbf24, 0.14 + 0.16 * progress);
      this.telegraphGraphics.fillCircle(v.x, v.y, innerR);
      this.telegraphGraphics.lineStyle(1.5, 0xfde68a, 0.85);
      this.telegraphGraphics.strokeCircle(v.x, v.y, innerR);

      // Reticle crosshair ticks
      const tick = 10;
      this.telegraphGraphics.lineStyle(2, 0x6ee7b7, 0.85);
      this.telegraphGraphics.beginPath();
      this.telegraphGraphics.moveTo(v.x - v.radius - 4, v.y);
      this.telegraphGraphics.lineTo(v.x - v.radius + tick, v.y);
      this.telegraphGraphics.moveTo(v.x + v.radius - tick, v.y);
      this.telegraphGraphics.lineTo(v.x + v.radius + 4, v.y);
      this.telegraphGraphics.moveTo(v.x, v.y - v.radius - 4);
      this.telegraphGraphics.lineTo(v.x, v.y - v.radius + tick);
      this.telegraphGraphics.moveTo(v.x, v.y + v.radius - tick);
      this.telegraphGraphics.lineTo(v.x, v.y + v.radius + 4);
      this.telegraphGraphics.strokePath();
    }
  }

  private drawEdgePulse(): void {
    this.edgePulseGraphics.clear();
    if (this.edgePulseAlpha <= 0) return;

    const w = this.arenaWidth;
    const h = this.arenaHeight;
    const thickness = 16;

    this.edgePulseGraphics.fillStyle(this.edgePulseColor, this.edgePulseAlpha * 0.35);
    this.edgePulseGraphics.fillRect(0, 0, w, thickness);
    this.edgePulseGraphics.fillRect(0, h - thickness, w, thickness);
    this.edgePulseGraphics.fillRect(0, thickness, thickness, h - thickness * 2);
    this.edgePulseGraphics.fillRect(w - thickness, thickness, thickness, h - thickness * 2);

    this.edgePulseGraphics.lineStyle(3, this.edgePulseColor, this.edgePulseAlpha * 0.85);
    this.edgePulseGraphics.strokeRect(2, 2, w - 4, h - 4);
  }

  private drawCrosshair(tSec: number): void {
    this.crosshairGraphics.clear();
    if (!this.pointerInsideCanvas) return;

    const x = Math.round(this.pointerState.x);
    const y = Math.round(this.pointerState.y);
    const active = this.pointerState.leftDown || this.pointerState.rightDown;
    const color = this.pointerState.rightDown
      ? 0xfacc15
      : this.pointerState.leftDown
        ? 0x38bdf8
        : 0xe2e8f0;
    const r = active ? 8 : 10 + Math.sin(tSec * 4) * 0.6;
    const gap = 4;

    this.crosshairGraphics.lineStyle(1.5, color, active ? 0.95 : 0.65);
    this.crosshairGraphics.strokeCircle(x, y, r);

    this.crosshairGraphics.beginPath();
    this.crosshairGraphics.moveTo(x - r - 4, y);
    this.crosshairGraphics.lineTo(x - gap, y);
    this.crosshairGraphics.moveTo(x + gap, y);
    this.crosshairGraphics.lineTo(x + r + 4, y);
    this.crosshairGraphics.moveTo(x, y - r - 4);
    this.crosshairGraphics.lineTo(x, y - gap);
    this.crosshairGraphics.moveTo(x, y + gap);
    this.crosshairGraphics.lineTo(x, y + r + 4);
    this.crosshairGraphics.strokePath();

    this.crosshairGraphics.fillStyle(color, 0.9);
    this.crosshairGraphics.fillRect(x - 1, y - 1, 2, 2);
  }

  // ---------------------------------------------------------------------------
  // CombatEvent VFX
  // ---------------------------------------------------------------------------

  private handleCombatEvent(evt: CombatEvent): void {
    switch (evt.type) {
      case 'hero_slash':
        this.playHeroSlash(evt.x, evt.y, evt.angle, evt.radius, evt.arcRad, evt.comboStep);
        break;
      case 'hero_charge':
        this.playHeroCharge(evt.fromX, evt.fromY, evt.toX, evt.toY);
        break;
      case 'hero_warcry':
        this.playHeroWarcry(evt.x, evt.y, evt.radius);
        break;
      case 'hero_dodge':
        this.playHeroDodge(evt.x, evt.y, evt.angle);
        break;
      case 'hero_down':
        this.playExpandingRing(evt.x, evt.y, 44, 0xef4444, 380);
        this.spawnFloatingText(evt.x, evt.y - 26, '主將重傷!', '#f87171', 15);
        this.cameras.main.shake(180, 0.005);
        break;
      case 'hero_respawn':
        this.playExpandingRing(evt.x, evt.y, 52, 0xfacc15, 420);
        this.spawnFloatingText(evt.x, evt.y - 28, '主將歸陣!', '#fde047', 15);
        break;
      case 'regiment_command':
        this.playRegimentCommand(evt.x, evt.y, evt.label, evt.commandType, evt.order);
        break;
      case 'arrow_shot':
        this.playArrowShot(evt.fromX, evt.fromY, evt.toX, evt.toY, evt.isPlayerSide);
        break;
      case 'volley_impact':
        this.playVolleyImpact(evt.x, evt.y, evt.radius);
        break;
      case 'commander_slam':
        this.playCommanderSlam(evt.x, evt.y, evt.radius);
        break;
      case 'damage':
        this.playDamageFeedback(
          evt.x,
          evt.y,
          evt.amount,
          evt.isCrit,
          evt.targetTeam,
          evt.blocked,
        );
        break;
      case 'gate_hit':
        this.playGateHit(evt.x, evt.y, evt.amount);
        break;
      case 'unit_died':
        this.playUnitDied(evt.x, evt.y, evt.team, evt.isCommander);
        break;
      case 'combat_ended':
        this.triggerEdgePulse(evt.status === 'victory' ? 0xfacc15 : 0xef4444, 0.75);
        break;
    }
  }

  private playHeroSlash(
    x: number,
    y: number,
    angle: number,
    radius: number,
    arcRad: number,
    comboStep: 0 | 1 | 2,
  ): void {
    const isFinisher = comboStep === 2;
    const outerColor = isFinisher ? 0xfacc15 : 0x38bdf8;
    const innerColor = isFinisher ? 0xfef08a : 0xe0f2fe;
    const halfArc = arcRad / 2;

    const g = this.add.graphics().setDepth(45);
    g.setPosition(x, y);

    // Outer glowing crescent
    g.lineStyle(isFinisher ? 11 : 7, outerColor, 0.82);
    g.beginPath();
    g.arc(0, 0, radius * 0.84, angle - halfArc, angle + halfArc, false);
    g.strokePath();

    // Crisp bright inner edge
    g.lineStyle(isFinisher ? 4 : 3, innerColor, 0.98);
    g.beginPath();
    g.arc(0, 0, radius * 0.92, angle - halfArc * 0.9, angle + halfArc * 0.9, false);
    g.strokePath();

    // Subtle translucent sweep fill
    g.fillStyle(outerColor, isFinisher ? 0.22 : 0.14);
    g.beginPath();
    g.moveTo(0, 0);
    g.arc(0, 0, radius * 0.9, angle - halfArc, angle + halfArc, false);
    g.closePath();
    g.fillPath();

    this.tweens.add({
      targets: g,
      alpha: 0,
      scaleX: isFinisher ? 1.15 : 1.07,
      scaleY: isFinisher ? 1.15 : 1.07,
      duration: isFinisher ? 220 : 165,
      ease: 'Cubic.easeOut',
      onComplete: () => g.destroy(),
    });

    if (isFinisher) {
      this.spawnPixelBurst(
        x + Math.cos(angle) * radius * 0.75,
        y + Math.sin(angle) * radius * 0.75,
        0xfacc15,
        8,
        80,
      );
    }
  }

  private playHeroCharge(fromX: number, fromY: number, toX: number, toY: number): void {
    const g = this.add.graphics().setDepth(44);
    const angle = Math.atan2(toY - fromY, toX - fromX);
    const perpX = -Math.sin(angle) * 10;
    const perpY = Math.cos(angle) * 10;

    // Bold golden-cyan central dash beam
    g.lineStyle(12, 0x38bdf8, 0.55);
    g.beginPath();
    g.moveTo(fromX, fromY);
    g.lineTo(toX, toY);
    g.strokePath();

    g.lineStyle(5, 0xfacc15, 0.92);
    g.beginPath();
    g.moveTo(fromX, fromY);
    g.lineTo(toX, toY);
    g.strokePath();

    // Flanking speed lines
    g.lineStyle(2, 0xe0f2fe, 0.7);
    g.beginPath();
    g.moveTo(fromX + perpX, fromY + perpY);
    g.lineTo(toX + perpX * 0.6, toY + perpY * 0.6);
    g.moveTo(fromX - perpX, fromY - perpY);
    g.lineTo(toX - perpX * 0.6, toY - perpY * 0.6);
    g.strokePath();

    this.tweens.add({
      targets: g,
      alpha: 0,
      duration: 280,
      ease: 'Quad.easeOut',
      onComplete: () => g.destroy(),
    });

    this.playExpandingRing(toX, toY, 44, 0xfacc15, 260);
    this.spawnPixelBurst(toX, toY, 0x38bdf8, 10, 95);
    this.cameras.main.shake(100, 0.0025);
  }

  private playHeroWarcry(x: number, y: number, radius: number): void {
    this.playExpandingRing(x, y, radius, 0xfacc15, 440, 4);
    this.playExpandingRing(x, y, radius * 0.68, 0xfef08a, 340, 2.5);
    this.spawnPixelBurst(x, y, 0xfacc15, 14, 120);
    this.triggerEdgePulse(0xfacc15, 0.55);
  }

  private playHeroDodge(x: number, y: number, angle: number): void {
    this.playExpandingRing(x, y, 26, 0x38bdf8, 200, 2.5);
    this.spawnPixelBurst(
      x - Math.cos(angle) * 8,
      y - Math.sin(angle) * 8,
      0x7dd3fc,
      6,
      55,
    );
  }

  private playRegimentCommand(
    x: number,
    y: number,
    label: string,
    commandType: 'order' | 'formation' | 'skill',
    order?: RegimentOrder,
  ): void {
    const color =
      commandType === 'skill'
        ? 0xfacc15
        : order
          ? ORDER_PING_COLOR[order]
          : 0x38bdf8;
    const hexStr = `#${color.toString(16).padStart(6, '0')}`;

    this.playExpandingRing(x, y, commandType === 'skill' ? 54 : 38, color, 380, 2.5);
    this.spawnFloatingText(x, y - 16, label, hexStr, commandType === 'skill' ? 14 : 12);
  }

  private playArrowShot(
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    isPlayerSide: boolean,
  ): void {
    const color = isPlayerSide ? 0x34d399 : 0xc084fc;
    const tipColor = isPlayerSide ? 0xfef08a : 0xf5d0fe;

    const line = this.add.graphics().setDepth(42);
    line.lineStyle(2, color, 0.78);
    line.beginPath();
    line.moveTo(fromX, fromY);
    line.lineTo(toX, toY);
    line.strokePath();

    this.tweens.add({
      targets: line,
      alpha: 0,
      duration: 140,
      onComplete: () => line.destroy(),
    });

    const arrowTip = this.add.rectangle(fromX, fromY, 8, 2, tipColor, 1).setDepth(43);
    arrowTip.setRotation(Math.atan2(toY - fromY, toX - fromX));

    this.tweens.add({
      targets: arrowTip,
      x: toX,
      y: toY,
      duration: 110,
      ease: 'Linear',
      onComplete: () => arrowTip.destroy(),
    });
  }

  private playVolleyImpact(x: number, y: number, radius: number): void {
    // Burst of falling arrows converging into target zone
    const arrowCount = 10;
    for (let i = 0; i < arrowCount; i += 1) {
      const a = (i / arrowCount) * Math.PI * 2 + Math.random() * 0.5;
      const dist = Math.random() * radius * 0.85;
      const tx = x + Math.cos(a) * dist;
      const ty = y + Math.sin(a) * dist;
      const sx = tx - 28;
      const sy = ty - 68;

      const streak = this.add.graphics().setDepth(44);
      streak.lineStyle(2, 0x34d399, 0.9);
      streak.beginPath();
      streak.moveTo(sx, sy);
      streak.lineTo(tx, ty);
      streak.strokePath();

      this.tweens.add({
        targets: streak,
        alpha: 0,
        duration: 210 + Math.random() * 80,
        onComplete: () => streak.destroy(),
      });
    }

    // Impact dust & emerald-amber ring
    this.playExpandingRing(x, y, radius, 0xfbbf24, 320, 3);
    this.playExpandingRing(x, y, radius * 0.65, 0x34d399, 260, 2);
    this.spawnPixelBurst(x, y, 0xfde68a, 12, 90);
  }

  private playCommanderSlam(x: number, y: number, radius: number): void {
    // Dramatic crimson shockwave + inner flash
    const flash = this.add.circle(x, y, radius * 0.85, 0xef4444, 0.38).setDepth(43);
    this.tweens.add({
      targets: flash,
      alpha: 0,
      scaleX: 1.15,
      scaleY: 1.15,
      duration: 280,
      ease: 'Quad.easeOut',
      onComplete: () => flash.destroy(),
    });

    this.playExpandingRing(x, y, radius, 0xef4444, 380, 4.5);
    this.playExpandingRing(x, y, radius * 0.72, 0xf97316, 300, 3);
    this.spawnPixelBurst(x, y, 0xef4444, 18, 130);
    this.triggerEdgePulse(0xef4444, 0.55);
    this.cameras.main.shake(220, 0.007);
  }

  private playDamageFeedback(
    x: number,
    y: number,
    amount: number,
    isCrit: boolean,
    targetTeam: 'player' | 'enemy',
    blocked?: boolean,
  ): void {
    const rounded = Math.max(0, Math.round(amount));
    const jitterX = (Math.random() - 0.5) * 14;
    let text: string;
    let color: string;
    let size: number;

    if (blocked) {
      text = rounded > 0 ? `格擋 ${rounded}` : '格擋';
      color = '#38bdf8';
      size = 11;
    } else if (isCrit) {
      text = `${rounded}!`;
      color = '#facc15';
      size = 16;
    } else if (targetTeam === 'player') {
      text = `-${rounded}`;
      color = '#f87171';
      size = 12;
    } else {
      text = `${rounded}`;
      color = '#f8fafc';
      size = 12;
    }

    this.spawnFloatingText(x + jitterX, y - 18, text, color, size, isCrit);

    // Subtle hit flash on nearby unit
    this.flashUnitNear(x, y, targetTeam);
  }

  private flashUnitNear(x: number, y: number, targetTeam: 'player' | 'enemy'): void {
    const now = this.time.now;
    const flashUntil = now + 95;

    if (targetTeam === 'player') {
      if (this.heroVisual && Math.hypot(this.heroVisual.currentX - x, this.heroVisual.currentY - y) < 26) {
        this.heroVisual.sprite.setTint(0xfca5a5);
        this.heroVisual.hitFlashUntil = flashUntil;
        return;
      }
      for (const sv of this.soldierVisuals.values()) {
        if (Math.hypot(sv.currentX - x, sv.currentY - y) < 20) {
          sv.sprite.setTint(0xfca5a5);
          sv.hitFlashUntil = flashUntil;
          return;
        }
      }
    } else {
      for (const ev of this.enemyVisuals.values()) {
        const hitR = ev.isCommander ? 36 : 22;
        if (Math.hypot(ev.currentX - x, ev.currentY - y) < hitR) {
          ev.sprite.setTintFill(0xffffff);
          ev.hitFlashUntil = flashUntil;
          return;
        }
      }
    }
  }

  private playGateHit(x: number, y: number, amount: number): void {
    this.gateDamageFlash.setAlpha(0.5);
    this.tweens.killTweensOf(this.gateDamageFlash);
    this.tweens.add({
      targets: this.gateDamageFlash,
      alpha: 0,
      duration: 240,
      ease: 'Quad.easeOut',
    });

    this.cameras.main.shake(110, 0.0035);
    this.spawnFloatingText(
      Math.max(this.gateX + 12, x),
      y - 12,
      `-${Math.round(amount)}`,
      '#ef4444',
      14,
    );
    this.spawnPixelBurst(this.gateX, y, 0xf97316, 7, 70);
  }

  private playUnitDied(
    x: number,
    y: number,
    team: 'hero' | 'regiment' | 'enemy',
    isCommander?: boolean,
  ): void {
    if (isCommander) {
      this.spawnPixelBurst(x, y, 0xfacc15, 24, 150);
      this.spawnPixelBurst(x, y, 0xef4444, 18, 120);
      this.playExpandingRing(x, y, 76, 0xfacc15, 450, 4);
      this.cameras.main.shake(260, 0.008);
      return;
    }

    let color = 0xef4444;
    if (team === 'hero') {
      color = 0xfacc15;
    } else if (team === 'regiment') {
      color = 0x38bdf8;
    } else {
      // Match nearest enemy color if still present
      for (const ev of this.enemyVisuals.values()) {
        if (Math.hypot(ev.currentX - x, ev.currentY - y) < 36) {
          color = ENEMY_BURST_COLOR[ev.type] ?? 0xef4444;
          break;
        }
      }
    }

    this.spawnPixelBurst(x, y, color, 10, 85);
  }

  // ---------------------------------------------------------------------------
  // VFX Helpers
  // ---------------------------------------------------------------------------

  private playExpandingRing(
    x: number,
    y: number,
    targetRadius: number,
    color: number,
    duration: number,
    strokeWidth = 3,
  ): void {
    const ring = this.add
      .circle(x, y, 8, color, 0.14)
      .setStrokeStyle(strokeWidth, color, 0.92)
      .setDepth(42);

    const targetScale = Math.max(1.2, targetRadius / 8);
    this.tweens.add({
      targets: ring,
      scaleX: targetScale,
      scaleY: targetScale,
      alpha: 0,
      duration,
      ease: 'Cubic.easeOut',
      onComplete: () => ring.destroy(),
    });
  }

  private spawnFloatingText(
    x: number,
    y: number,
    label: string,
    color: string,
    fontSize: number,
    pop = false,
  ): void {
    const txt = this.add
      .text(Math.round(x), Math.round(y), label, {
        fontFamily: '"Microsoft JhengHei", system-ui, monospace, sans-serif',
        fontSize: `${fontSize}px`,
        fontStyle: 'bold',
        color,
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setOrigin(0.5)
      .setDepth(55);

    if (pop) {
      txt.setScale(1.3);
    }

    this.tweens.add({
      targets: txt,
      y: y - (pop ? 34 : 24),
      scaleX: 1,
      scaleY: 1,
      alpha: 0,
      duration: pop ? 720 : 560,
      ease: 'Cubic.easeOut',
      onComplete: () => txt.destroy(),
    });
  }

  private spawnPixelBurst(
    x: number,
    y: number,
    color: number,
    count: number,
    maxDist: number,
  ): void {
    for (let i = 0; i < count; i += 1) {
      const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.5;
      const dist = 14 + Math.random() * maxDist;
      const p = this.add
        .image(x, y, 'px-square')
        .setTint(color)
        .setScale(0.8 + Math.random() * 0.9)
        .setDepth(48);

      this.tweens.add({
        targets: p,
        x: x + Math.cos(angle) * dist,
        y: y + Math.sin(angle) * dist,
        alpha: 0,
        scaleX: 0.2,
        scaleY: 0.2,
        duration: 240 + Math.random() * 200,
        ease: 'Quad.easeOut',
        onComplete: () => p.destroy(),
      });
    }
  }

  private triggerEdgePulse(color: number, alpha: number): void {
    this.edgePulseColor = color;
    this.edgePulseAlpha = Math.max(this.edgePulseAlpha, alpha);
    this.drawEdgePulse();
  }
}
