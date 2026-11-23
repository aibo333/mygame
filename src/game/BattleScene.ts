import Phaser from 'phaser';
import {
  DEFAULT_ARENA_HEIGHT,
  DEFAULT_ARENA_WIDTH,
  DEFAULT_GATE_X,
  STANCE_MODIFIERS,
} from '../core/combat/presets';
import type {
  CombatEvent,
  CombatSnapshot,
  EnemyArchetype,
  EnemyState,
  HeroState,
  SquadRole,
  TacticalStance,
} from '../core/types/combat';
import {
  generateBattleTextures,
  getEnemyTextureKey,
  getHeroTextureKey,
} from './pixelSprites';

const STANCE_VISUALS: Record<
  TacticalStance,
  { color: number; hex: string; banner: string }
> = {
  defense: {
    color: 0x38bdf8,
    hex: '#38bdf8',
    banner: '🛡️ 結陣死守',
  },
  assault: {
    color: 0xf97316,
    hex: '#f97316',
    banner: '⚔️ 全力強攻',
  },
  scatter: {
    color: 0x34d399,
    hex: '#34d399',
    banner: '⚡ 散開追擊',
  },
};

const ROLE_BADGE: Record<SquadRole, { tag: string; color: string; hex: number }> = {
  tank: { tag: '盾', color: '#7dd3fc', hex: 0x38bdf8 },
  dps: { tag: '弓', color: '#6ee7b7', hex: 0x34d399 },
  support: { tag: '癒', color: '#ddd6fe', hex: 0xa78bfa },
};

const ENEMY_TINT_BURST: Record<EnemyArchetype, number> = {
  goblin: 0x4ade80,
  archer: 0xc084fc,
  bomber: 0xf97316,
  brute: 0xfacc15,
};

interface HeroVisual {
  id: string;
  role: SquadRole;
  container: Phaser.GameObjects.Container;
  shadow: Phaser.GameObjects.Ellipse;
  auraRing: Phaser.GameObjects.Arc;
  sprite: Phaser.GameObjects.Image;
  drRing: Phaser.GameObjects.Arc;
  barGraphics: Phaser.GameObjects.Graphics;
  label: Phaser.GameObjects.Text;
  targetX: number;
  targetY: number;
  currentX: number;
  currentY: number;
  bobPhase: number;
  hitFlashUntil: number;
  alive: boolean;
}

interface EnemyVisual {
  id: string;
  archetype: EnemyArchetype;
  isElite: boolean;
  container: Phaser.GameObjects.Container;
  shadow: Phaser.GameObjects.Ellipse;
  dangerRing: Phaser.GameObjects.Arc | null;
  sprite: Phaser.GameObjects.Image;
  barGraphics: Phaser.GameObjects.Graphics;
  tauntMark: Phaser.GameObjects.Text;
  eliteTag: Phaser.GameObjects.Text | null;
  targetX: number;
  targetY: number;
  currentX: number;
  currentY: number;
  bobPhase: number;
  hitFlashUntil: number;
  alive: boolean;
}

interface TorchFlicker {
  glow: Phaser.GameObjects.Arc;
  flame: Phaser.GameObjects.Rectangle;
  baseX: number;
  baseY: number;
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

  private heroVisuals = new Map<string, HeroVisual>();
  private enemyVisuals = new Map<string, EnemyVisual>();

  // Static & animated environment objects
  private gateDamageFlash!: Phaser.GameObjects.Rectangle;
  private gateHpGraphics!: Phaser.GameObjects.Graphics;
  private gateHpText!: Phaser.GameObjects.Text;
  private torches: TorchFlicker[] = [];
  private spawnPortals: Phaser.GameObjects.Image[] = [];

  // Tank intercept radius overlay
  private interceptGraphics!: Phaser.GameObjects.Graphics;
  private currentInterceptRadius = 118;
  private targetInterceptRadius = 118;

  // Screen-edge tactical tint pulse & stance banner
  private edgePulseGraphics!: Phaser.GameObjects.Graphics;
  private edgePulseAlpha = 0;
  private edgePulseColor = 0x38bdf8;
  private stanceBannerContainer!: Phaser.GameObjects.Container;
  private stanceBannerBg!: Phaser.GameObjects.Graphics;
  private stanceBannerText!: Phaser.GameObjects.Text;
  private stanceBannerTween: Phaser.Tweens.Tween | null = null;

  constructor() {
    super({ key: 'BattleScene' });
  }

  public create(): void {
    generateBattleTextures(this);

    this.cameras.main.setBackgroundColor('#0b1120');

    this.buildBattleground();
    this.buildVillageGate();
    this.buildSpawnPortals();
    this.buildOverlays();

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
        if (this.pendingEvents.length > 80) {
          this.pendingEvents = this.pendingEvents.slice(-80);
        }
      }
      return;
    }
    this.applyState(snapshot, events);
  }

  private applyState(snapshot: CombatSnapshot, events: CombatEvent[]): void {
    const isReset =
      this.lastTick !== -1 &&
      (snapshot.tick < this.lastTick ||
        (this.latestSnapshot !== null &&
          snapshot.wave.id !== this.latestSnapshot.wave.id));

    if (isReset) {
      this.clearAllUnits();
    }

    this.lastTick = snapshot.tick;
    this.latestSnapshot = snapshot;
    this.gateX = snapshot.gateX || DEFAULT_GATE_X;

    this.syncHeroes(snapshot);
    this.syncEnemies(snapshot);
    this.updateGateHpBar(snapshot.gateHp, snapshot.gateMaxHp);

    for (const evt of events) {
      this.handleCombatEvent(evt);
    }

    this.pruneDeadEnemies(snapshot);
  }

  public update(time: number, delta: number): void {
    if (!this.isReady) return;

    const dtSec = Math.min(delta / 1000, 0.1);
    const lerpAlpha = 1 - Math.exp(-14 * dtSec);
    const tSec = time / 1000;

    // 1. Animate torches
    for (const torch of this.torches) {
      const flicker = 0.78 + 0.22 * Math.sin(tSec * 9.5 + torch.phase);
      torch.glow.setAlpha(0.16 * flicker);
      torch.glow.setScale(0.92 + 0.14 * flicker);
      torch.flame.setScale(1, 0.85 + 0.3 * Math.sin(tSec * 14 + torch.phase));
    }

    // 2. Animate spawn portals
    for (let i = 0; i < this.spawnPortals.length; i += 1) {
      const portal = this.spawnPortals[i];
      const pulse = 0.82 + 0.18 * Math.sin(tSec * 3.2 + i * 1.4);
      portal.setAlpha(0.68 * pulse);
      portal.setScale(0.95 + 0.08 * pulse, 1.0 + 0.06 * Math.cos(tSec * 2.4 + i));
    }

    // 3. Interpolate & bob heroes
    const stance: TacticalStance = this.latestSnapshot?.stance ?? 'defense';
    const stanceStyle = STANCE_VISUALS[stance];
    let tankPos: { x: number; y: number } | null = null;

    for (const hv of this.heroVisuals.values()) {
      const prevX = hv.currentX;
      const prevY = hv.currentY;
      hv.currentX = Phaser.Math.Linear(hv.currentX, hv.targetX, lerpAlpha);
      hv.currentY = Phaser.Math.Linear(hv.currentY, hv.targetY, lerpAlpha);

      const moveDist = Math.hypot(hv.currentX - prevX, hv.currentY - prevY);
      const bobSpeed = moveDist > 0.35 ? 11 : 4.2;
      const bobAmp = moveDist > 0.35 ? 2.6 : 1.4;
      const bobY = hv.alive ? Math.round(Math.sin(tSec * bobSpeed + hv.bobPhase) * bobAmp) : 0;

      hv.container.setPosition(Math.round(hv.currentX), Math.round(hv.currentY));
      hv.container.setDepth(20 + hv.currentY * 0.01);
      hv.sprite.setY(bobY);

      // Aura ring pulse
      hv.auraRing.setStrokeStyle(2, stanceStyle.color, hv.alive ? 0.65 + 0.25 * Math.sin(tSec * 4.5 + hv.bobPhase) : 0);
      hv.auraRing.setFillStyle(stanceStyle.color, hv.alive ? 0.12 : 0);

      // Clear expired hit flash
      if (hv.hitFlashUntil > 0 && time >= hv.hitFlashUntil) {
        hv.hitFlashUntil = 0;
        hv.sprite.clearTint();
      }

      if (hv.role === 'tank' && hv.alive) {
        tankPos = { x: hv.currentX, y: hv.currentY };
      }
    }

    // 4. Tank intercept radius circle
    this.currentInterceptRadius = Phaser.Math.Linear(
      this.currentInterceptRadius,
      this.targetInterceptRadius,
      1 - Math.exp(-8 * dtSec),
    );
    this.drawTankInterceptCircle(tankPos, stance, tSec);

    // 5. Interpolate & bob enemies
    for (const ev of this.enemyVisuals.values()) {
      const prevX = ev.currentX;
      const prevY = ev.currentY;
      ev.currentX = Phaser.Math.Linear(ev.currentX, ev.targetX, lerpAlpha);
      ev.currentY = Phaser.Math.Linear(ev.currentY, ev.targetY, lerpAlpha);

      const moveDist = Math.hypot(ev.currentX - prevX, ev.currentY - prevY);
      const bobSpeed = ev.archetype === 'goblin' ? 12 : ev.archetype === 'brute' ? 6.5 : 8.5;
      const bobAmp = moveDist > 0.25 ? 2.4 : 1.2;
      const bobY = ev.alive ? Math.round(Math.sin(tSec * bobSpeed + ev.bobPhase) * bobAmp) : 0;

      ev.container.setPosition(Math.round(ev.currentX), Math.round(ev.currentY));
      ev.container.setDepth(20 + ev.currentY * 0.01);
      ev.sprite.setY(bobY);

      if (ev.dangerRing) {
        const pulse = 0.55 + 0.45 * Math.sin(tSec * 8 + ev.bobPhase);
        ev.dangerRing.setStrokeStyle(1.5, 0xf97316, 0.35 + 0.45 * pulse);
        ev.dangerRing.setScale(0.92 + 0.12 * pulse);
      }

      if (ev.hitFlashUntil > 0 && time >= ev.hitFlashUntil) {
        ev.hitFlashUntil = 0;
        ev.sprite.clearTint();
      }
    }

    // 6. Decay screen-edge tactical tint pulse
    if (this.edgePulseAlpha > 0.005) {
      this.edgePulseAlpha = Math.max(0, this.edgePulseAlpha - dtSec * 1.15);
      this.drawEdgePulse();
    } else if (this.edgePulseAlpha > 0) {
      this.edgePulseAlpha = 0;
      this.edgePulseGraphics.clear();
    }
  }

  private buildBattleground(): void {
    const g = this.add.graphics().setDepth(0);
    const tile = 24;

    // Night-village dark grass/earth checkerboard tiles
    for (let y = 0; y < this.arenaHeight; y += tile) {
      for (let x = this.gateX; x < this.arenaWidth; x += tile) {
        const isAlt = ((x / tile + y / tile) | 0) % 2 === 0;
        const baseColor = isAlt ? 0x0f172a : 0x111c33;
        g.fillStyle(baseColor, 1);
        g.fillRect(x, y, tile, tile);

        // Subtle pixel grass tufts (deterministic hash)
        const hash = ((x * 73 + y * 151) ^ (x * 19)) & 0xff;
        if (hash < 34) {
          g.fillStyle(0x16293d, 0.85);
          g.fillRect(x + (hash % 16), y + ((hash * 3) % 16), 4, 2);
        } else if (hash > 235) {
          g.fillStyle(0x1e293b, 0.75);
          g.fillRect(x + (hash % 14), y + ((hash * 5) % 14), 2, 2);
        }
      }
    }

    // Three subtle tactical dirt lanes (top, mid, bottom)
    const laneYs = [165, 270, 375];
    for (const ly of laneYs) {
      g.fillStyle(0x172033, 0.72);
      g.fillRect(this.gateX, ly - 24, this.arenaWidth - this.gateX, 48);

      // Subtle stone flecks along the lane
      for (let x = this.gateX + 18; x < this.arenaWidth - 36; x += 44) {
        g.fillStyle(0x24324a, 0.55);
        g.fillRect(x, ly - 18 + ((x * 7) % 32), 6, 2);
      }

      // Dashed tactical lane guide line
      g.fillStyle(0x38bdf8, 0.14);
      for (let x = this.gateX + 24; x < this.arenaWidth - 64; x += 28) {
        g.fillRect(x, ly - 1, 12, 2);
      }
    }

    // Subtle top & bottom dark forest border framing
    g.fillStyle(0x070b14, 0.75);
    g.fillRect(this.gateX, 0, this.arenaWidth - this.gateX, 34);
    g.fillRect(this.gateX, this.arenaHeight - 34, this.arenaWidth - this.gateX, 34);

    // Subtle defense line marker in front of the gate
    g.fillStyle(0x38bdf8, 0.18);
    for (let y = 44; y < this.arenaHeight - 44; y += 16) {
      g.fillRect(this.gateX + 8, y, 2, 8);
    }

    // Lane chevron markers near right flank
    const guide = this.add.graphics().setDepth(5);
    for (const ly of laneYs) {
      guide.lineStyle(2, 0x94a3b8, 0.18);
      guide.beginPath();
      guide.moveTo(this.arenaWidth - 92, ly - 8);
      guide.lineTo(this.arenaWidth - 102, ly);
      guide.lineTo(this.arenaWidth - 92, ly + 8);
      guide.strokePath();
    }
  }

  private buildVillageGate(): void {
    const g = this.add.graphics().setDepth(10);
    const w = this.gateX;
    const h = this.arenaHeight;

    // Inner village dark stone backdrop
    g.fillStyle(0x111827, 1);
    g.fillRect(0, 0, w, h);

    // Stone brick wall body
    g.fillStyle(0x334155, 1);
    g.fillRect(10, 0, w - 18, h);

    // Pixel brick lines
    g.fillStyle(0x1e293b, 1);
    for (let y = 0; y < h; y += 16) {
      g.fillRect(10, y, w - 18, 2);
      const offset = (y / 16) % 2 === 0 ? 18 : 30;
      g.fillRect(offset, y, 2, 16);
      g.fillRect(offset + 22, y, 2, 16);
    }

    // Battlements / Crenellations on the eastern (battlefield-facing) edge
    for (let y = 8; y < h - 8; y += 28) {
      g.fillStyle(0x475569, 1);
      g.fillRect(w - 10, y, 10, 18);
      g.fillStyle(0x64748b, 1);
      g.fillRect(w - 10, y, 10, 3);
      g.fillStyle(0x0f172a, 1);
      g.fillRect(w - 2, y, 2, 18);
    }

    // Central wooden gatehouse (y = 205..335)
    const gateTop = 205;
    const gateH = 130;
    g.fillStyle(0x451a03, 1);
    g.fillRect(14, gateTop, w - 18, gateH);

    // Wood planks
    g.fillStyle(0x78350f, 1);
    for (let y = gateTop + 6; y < gateTop + gateH - 6; y += 14) {
      g.fillRect(16, y, w - 24, 10);
    }

    // Iron reinforcement bands & studs
    g.fillStyle(0x94a3b8, 1);
    g.fillRect(14, gateTop + 18, w - 18, 6);
    g.fillRect(14, gateTop + gateH - 24, w - 18, 6);
    g.fillStyle(0xfacc15, 0.85);
    g.fillRect(w - 16, gateTop + gateH / 2 - 4, 6, 8);

    // Bastion torches (top & bottom of gatehouse)
    const torchPositions = [
      { x: w - 6, y: gateTop - 16 },
      { x: w - 6, y: gateTop + gateH + 16 },
      { x: w - 6, y: 76 },
      { x: w - 6, y: h - 76 },
    ];

    for (let i = 0; i < torchPositions.length; i += 1) {
      const tp = torchPositions[i];
      // Bracket
      g.fillStyle(0x1e293b, 1);
      g.fillRect(tp.x - 4, tp.y + 2, 8, 6);

      const glow = this.add
        .circle(tp.x, tp.y - 2, 26, 0xf59e0b, 0.16)
        .setDepth(12);
      const flame = this.add
        .rectangle(tp.x, tp.y - 2, 6, 8, 0xfbbf24, 1)
        .setDepth(13);
      this.add.rectangle(tp.x, tp.y - 1, 3, 4, 0xfef08a, 1).setDepth(14);

      this.torches.push({
        glow,
        flame,
        baseX: tp.x,
        baseY: tp.y,
        phase: i * 1.7,
      });
    }

    // Gate damage flash overlay
    this.gateDamageFlash = this.add
      .rectangle(w / 2, h / 2, w + 4, h, 0xef4444, 0)
      .setDepth(35);

    // Gate HP bar (top-left on the wall header)
    this.gateHpGraphics = this.add.graphics().setDepth(36);
    this.gateHpText = this.add
      .text(8, 10, '城門 300/300', {
        fontFamily: 'monospace, "Microsoft JhengHei", sans-serif',
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#f8fafc',
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setDepth(37);

    this.updateGateHpBar(300, 300);
  }

  private buildSpawnPortals(): void {
    const laneYs = [165, 270, 375];
    const portalX = this.arenaWidth - 46;

    for (const ly of laneYs) {
      const portal = this.add
        .image(portalX, ly, 'spawn-portal')
        .setDepth(6)
        .setAlpha(0.7);
      this.spawnPortals.push(portal);
    }
  }

  private buildOverlays(): void {
    this.interceptGraphics = this.add.graphics().setDepth(15);
    this.edgePulseGraphics = this.add.graphics().setDepth(60);

    // Stance change banner (top-center)
    this.stanceBannerContainer = this.add
      .container(this.arenaWidth / 2, 58)
      .setDepth(62)
      .setAlpha(0);

    this.stanceBannerBg = this.add.graphics();
    this.stanceBannerText = this.add
      .text(0, 0, '', {
        fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
        fontSize: '18px',
        fontStyle: 'bold',
        color: '#f8fafc',
        stroke: '#020617',
        strokeThickness: 4,
      })
      .setOrigin(0.5);

    this.stanceBannerContainer.add([this.stanceBannerBg, this.stanceBannerText]);
  }

  private updateGateHpBar(hp: number, maxHp: number): void {
    const ratio = maxHp > 0 ? Phaser.Math.Clamp(hp / maxHp, 0, 1) : 0;
    const barX = 8;
    const barY = 26;
    const barW = 124;
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

  private drawTankInterceptCircle(
    tankPos: { x: number; y: number } | null,
    stance: TacticalStance,
    tSec: number,
  ): void {
    this.interceptGraphics.clear();
    if (!tankPos) return;

    const isDefense = stance === 'defense';
    const r = this.currentInterceptRadius;
    const color = isDefense ? 0x38bdf8 : 0x64748b;
    const fillAlpha = isDefense ? 0.11 + 0.03 * Math.sin(tSec * 3.5) : 0.05;
    const strokeAlpha = isDefense ? 0.52 : 0.24;

    this.interceptGraphics.fillStyle(color, fillAlpha);
    this.interceptGraphics.fillCircle(tankPos.x, tankPos.y, r);

    this.interceptGraphics.lineStyle(isDefense ? 2 : 1, color, strokeAlpha);
    this.interceptGraphics.strokeCircle(tankPos.x, tankPos.y, r);

    // Subtle inner tactical ring when in defense stance
    if (isDefense) {
      this.interceptGraphics.lineStyle(1, 0xbae6fd, 0.28);
      this.interceptGraphics.strokeCircle(tankPos.x, tankPos.y, r - 6);
    }
  }

  private drawEdgePulse(): void {
    this.edgePulseGraphics.clear();
    if (this.edgePulseAlpha <= 0) return;

    const w = this.arenaWidth;
    const h = this.arenaHeight;
    const thickness = 18;

    this.edgePulseGraphics.fillStyle(this.edgePulseColor, this.edgePulseAlpha * 0.45);
    this.edgePulseGraphics.fillRect(0, 0, w, thickness);
    this.edgePulseGraphics.fillRect(0, h - thickness, w, thickness);
    this.edgePulseGraphics.fillRect(0, thickness, thickness, h - thickness * 2);
    this.edgePulseGraphics.fillRect(w - thickness, thickness, thickness, h - thickness * 2);

    this.edgePulseGraphics.lineStyle(3, this.edgePulseColor, this.edgePulseAlpha * 0.9);
    this.edgePulseGraphics.strokeRect(2, 2, w - 4, h - 4);
  }

  private syncHeroes(snapshot: CombatSnapshot): void {
    const activeIds = new Set<string>();
    const interceptMult = STANCE_MODIFIERS[snapshot.stance].tankInterceptRadiusMultiplier;

    for (const hero of snapshot.heroes) {
      activeIds.add(hero.id);

      if (hero.role === 'tank') {
        this.targetInterceptRadius = hero.interceptRadius * interceptMult;
      }

      let hv = this.heroVisuals.get(hero.id);
      if (!hv) {
        hv = this.createHeroVisual(hero);
        this.heroVisuals.set(hero.id, hv);
      }

      // Snap immediately if teleported far (e.g. wave restart)
      if (Math.hypot(hero.x - hv.currentX, hero.y - hv.currentY) > 160) {
        hv.currentX = hero.x;
        hv.currentY = hero.y;
      }

      hv.targetX = hero.x;
      hv.targetY = hero.y;
      hv.alive = hero.alive;
      hv.container.setAlpha(hero.alive ? 1 : 0.28);
      hv.sprite.setFlipX(false);

      // Damage reduction golden/cyan ring
      hv.drRing.setVisible(hero.alive && hero.damageReductionRemainingSec > 0);

      this.redrawUnitBar(
        hv.barGraphics,
        hero.hp,
        hero.maxHp,
        hero.shield,
        36,
        -28,
        0x22c55e,
        false,
      );
    }

    for (const [id, hv] of this.heroVisuals.entries()) {
      if (!activeIds.has(id)) {
        hv.container.destroy();
        this.heroVisuals.delete(id);
      }
    }
  }

  private createHeroVisual(hero: HeroState): HeroVisual {
    const container = this.add.container(hero.x, hero.y).setDepth(20);
    const shadow = this.add.ellipse(0, 14, 24, 9, 0x020617, 0.55);
    const auraRing = this.add.circle(0, 12, 18, 0x38bdf8, 0.12);
    auraRing.setScale(1, 0.48);

    const drRing = this.add
      .circle(0, 0, 22, 0xfacc15, 0.08)
      .setStrokeStyle(2, 0xfacc15, 0.75)
      .setVisible(false);

    const sprite = this.add
      .image(0, 0, getHeroTextureKey(hero.role))
      .setOrigin(0.5, 0.5);

    const barGraphics = this.add.graphics();
    const badge = ROLE_BADGE[hero.role];
    const label = this.add
      .text(0, 21, `${badge.tag} ${hero.name}`, {
        fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
        fontSize: '10px',
        fontStyle: 'bold',
        color: badge.color,
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setOrigin(0.5, 0);

    container.add([shadow, auraRing, drRing, sprite, barGraphics, label]);

    return {
      id: hero.id,
      role: hero.role,
      container,
      shadow,
      auraRing,
      sprite,
      drRing,
      barGraphics,
      label,
      targetX: hero.x,
      targetY: hero.y,
      currentX: hero.x,
      currentY: hero.y,
      bobPhase: Math.random() * Math.PI * 2,
      hitFlashUntil: 0,
      alive: hero.alive,
    };
  }

  private syncEnemies(snapshot: CombatSnapshot): void {
    for (const enemy of snapshot.enemies) {
      if (!enemy.alive) {
        continue;
      }

      let ev = this.enemyVisuals.get(enemy.id);
      if (!ev) {
        ev = this.createEnemyVisual(enemy);
        this.enemyVisuals.set(enemy.id, ev);
      }

      ev.targetX = enemy.x;
      ev.targetY = enemy.y;
      ev.alive = enemy.alive;

      // Show taunt mark when taunted by tank
      ev.tauntMark.setVisible(enemy.tauntRemainingSec > 0);

      const barW = enemy.isElite ? 44 : 30;
      const barY = enemy.isElite ? -31 : -24;
      this.redrawUnitBar(
        ev.barGraphics,
        enemy.hp,
        enemy.maxHp,
        0,
        barW,
        barY,
        enemy.isElite ? 0xf59e0b : 0xef4444,
        enemy.isElite,
      );
    }
  }

  private pruneDeadEnemies(snapshot: CombatSnapshot): void {
    const aliveIds = new Set<string>();
    for (const enemy of snapshot.enemies) {
      if (enemy.alive) {
        aliveIds.add(enemy.id);
      }
    }

    for (const [id, ev] of this.enemyVisuals.entries()) {
      if (!aliveIds.has(id)) {
        ev.alive = false;
        ev.container.destroy();
        this.enemyVisuals.delete(id);
      }
    }
  }

  private createEnemyVisual(enemy: EnemyState): EnemyVisual {
    const container = this.add.container(enemy.x, enemy.y).setDepth(20);
    const shadowW = enemy.isElite ? 32 : 20;
    const shadowY = enemy.isElite ? 17 : 12;
    const shadow = this.add.ellipse(0, shadowY, shadowW, 8, 0x020617, 0.55);

    let dangerRing: Phaser.GameObjects.Arc | null = null;
    if (enemy.archetype === 'bomber') {
      dangerRing = this.add
        .circle(0, 2, 19, 0xf97316, 0.08)
        .setStrokeStyle(1.5, 0xf97316, 0.65);
    }

    const sprite = this.add
      .image(0, 0, getEnemyTextureKey(enemy.archetype))
      .setOrigin(0.5, 0.5);

    const barGraphics = this.add.graphics();

    const tauntMark = this.add
      .text(0, enemy.isElite ? -46 : -38, '嘲諷!', {
        fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
        fontSize: '9px',
        fontStyle: 'bold',
        color: '#38bdf8',
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setOrigin(0.5, 0.5)
      .setVisible(false);

    let eliteTag: Phaser.GameObjects.Text | null = null;
    if (enemy.isElite) {
      eliteTag = this.add
        .text(0, 23, '★ 狂戰士', {
          fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
          fontSize: '10px',
          fontStyle: 'bold',
          color: '#facc15',
          stroke: '#020617',
          strokeThickness: 3,
        })
        .setOrigin(0.5, 0);
    }

    const children: Phaser.GameObjects.GameObject[] = [shadow];
    if (dangerRing) children.push(dangerRing);
    children.push(sprite, barGraphics, tauntMark);
    if (eliteTag) children.push(eliteTag);
    container.add(children);

    return {
      id: enemy.id,
      archetype: enemy.archetype,
      isElite: enemy.isElite,
      container,
      shadow,
      dangerRing,
      sprite,
      barGraphics,
      tauntMark,
      eliteTag,
      targetX: enemy.x,
      targetY: enemy.y,
      currentX: enemy.x,
      currentY: enemy.y,
      bobPhase: Math.random() * Math.PI * 2,
      hitFlashUntil: 0,
      alive: true,
    };
  }

  private redrawUnitBar(
    g: Phaser.GameObjects.Graphics,
    hp: number,
    maxHp: number,
    shield: number,
    width: number,
    offsetY: number,
    hpColor: number,
    isElite: boolean,
  ): void {
    g.clear();
    const x = -Math.round(width / 2);
    const height = isElite ? 6 : 5;
    const hpRatio = maxHp > 0 ? Phaser.Math.Clamp(hp / maxHp, 0, 1) : 0;

    // Frame
    g.fillStyle(isElite ? 0xfacc15 : 0x020617, 0.92);
    g.fillRect(x - 1, offsetY - 1, width + 2, height + 2);

    // Background
    g.fillStyle(0x1e293b, 1);
    g.fillRect(x, offsetY, width, height);

    // HP fill
    if (hpRatio > 0) {
      g.fillStyle(hpColor, 1);
      g.fillRect(x, offsetY, Math.max(1, Math.round(width * hpRatio)), height);
    }

    // Cyan shield bar overlay (drawn along top & right edge of bar)
    if (shield > 0 && maxHp > 0) {
      const shieldRatio = Phaser.Math.Clamp(shield / maxHp, 0, 1);
      const shieldW = Math.max(2, Math.round(width * shieldRatio));
      g.fillStyle(0x38bdf8, 0.95);
      g.fillRect(x, offsetY - 2, shieldW, 2);
      g.fillStyle(0x7dd3fc, 0.6);
      g.fillRect(x, offsetY, shieldW, 1);
    }
  }

  private handleCombatEvent(event: CombatEvent): void {
    switch (event.type) {
      case 'damage':
        this.playDamageVfx(event);
        break;
      case 'heal':
        this.playHealVfx(event);
        break;
      case 'shield':
        this.playShieldVfx(event);
        break;
      case 'skill_cast':
        this.playSkillCastVfx(event);
        break;
      case 'stance_changed':
        this.playStanceChangedVfx(event.nextStance);
        break;
      case 'gate_hit':
        this.playGateHitVfx(event);
        break;
      case 'enemy_spawned':
        this.playSpawnRing(event.x, event.y, event.isElite ? 0xfacc15 : 0xc084fc);
        break;
      case 'unit_died':
        this.playUnitDiedVfx(event);
        break;
      case 'combat_ended':
        this.edgePulseColor = event.status === 'victory' ? 0x34d399 : 0xef4444;
        this.edgePulseAlpha = 0.85;
        this.drawEdgePulse();
        break;
    }
  }

  private getUnitPosition(unitId: string): { x: number; y: number } | null {
    const hv = this.heroVisuals.get(unitId);
    if (hv) return { x: hv.currentX, y: hv.currentY };
    const ev = this.enemyVisuals.get(unitId);
    if (ev) return { x: ev.currentX, y: ev.currentY };
    return null;
  }

  private playDamageVfx(event: Extract<CombatEvent, { type: 'damage' }>): void {
    const now = this.time.now;

    // 1. Hit flash on target
    if (event.targetTeam === 'hero') {
      const hv = this.heroVisuals.get(event.targetId);
      if (hv) {
        hv.sprite.setTintFill(event.shieldAbsorbed > 0 && event.amount === 0 ? 0x38bdf8 : 0xf87171);
        hv.hitFlashUntil = now + 95;
      }
    } else {
      const ev = this.enemyVisuals.get(event.targetId);
      if (ev) {
        ev.sprite.setTintFill(event.isCrit ? 0xfef08a : 0xffffff);
        ev.hitFlashUntil = now + 90;
      }
    }

    // 2. Projectile / slash line from source to target
    const src = this.getUnitPosition(event.sourceId);
    if (src) {
      const dist = Math.hypot(event.x - src.x, event.y - src.y);
      const isRanged = dist > 85;
      const lineColor =
        event.sourceTeam === 'hero'
          ? event.isCrit
            ? 0xfacc15
            : 0xbae6fd
          : 0xfb7185;
      this.drawAttackTrace(src.x, src.y, event.x, event.y, lineColor, isRanged);
    }

    // 3. AOE blast ring for explosive/AOE enemy hits
    if (event.isAoe && event.sourceTeam === 'enemy') {
      this.spawnExpandingRing(event.x, event.y, 48, 0xf97316, 0.55, 280);
    }

    // 4. Floating damage number
    const totalShown = Math.max(0, Math.round(event.amount));
    const jitterX = (Math.random() - 0.5) * 14;
    if (totalShown > 0) {
      const text = event.isCrit ? `${totalShown}!` : `${totalShown}`;
      const color =
        event.targetTeam === 'hero'
          ? '#f87171'
          : event.isCrit
            ? '#fde047'
            : '#f8fafc';
      const fontSize = event.isCrit ? '15px' : '12px';
      this.spawnFloatingText(event.x + jitterX, event.y - 22, text, color, fontSize);
    } else if (event.shieldAbsorbed > 0) {
      this.spawnFloatingText(
        event.x + jitterX,
        event.y - 22,
        `盾 -${Math.round(event.shieldAbsorbed)}`,
        '#38bdf8',
        '11px',
      );
    }
  }

  private drawAttackTrace(
    x1: number,
    y1: number,
    x2: number,
    y2: number,
    color: number,
    isRanged: boolean,
  ): void {
    const g = this.add.graphics().setDepth(40);
    if (isRanged) {
      g.lineStyle(2, color, 0.85);
      g.beginPath();
      g.moveTo(x1, y1 - 4);
      g.lineTo(x2, y2 - 4);
      g.strokePath();
      g.fillStyle(0xffffff, 0.95);
      g.fillRect(x2 - 2, y2 - 6, 4, 4);
    } else {
      // Crisp melee slash arc near target
      const angle = Math.atan2(y2 - y1, x2 - x1);
      g.lineStyle(2.5, color, 0.9);
      g.beginPath();
      g.arc(x2, y2, 16, angle - 0.9, angle + 0.9, false);
      g.strokePath();
    }

    this.tweens.add({
      targets: g,
      alpha: 0,
      duration: isRanged ? 150 : 120,
      onComplete: () => g.destroy(),
    });
  }

  private playHealVfx(event: Extract<CombatEvent, { type: 'heal' }>): void {
    const amount = Math.round(event.amount);
    if (amount > 0) {
      this.spawnFloatingText(event.x, event.y - 26, `+${amount}`, '#4ade80', '13px');
    }
    this.spawnExpandingRing(event.x, event.y, 26, 0x4ade80, 0.65, 340);

    // Rising pixel sparkles
    for (let i = 0; i < 4; i += 1) {
      const px = this.add
        .image(
          event.x + (Math.random() - 0.5) * 20,
          event.y + (Math.random() - 0.5) * 10,
          'px-square',
        )
        .setTint(0x86efac)
        .setDepth(42);
      this.tweens.add({
        targets: px,
        y: px.y - 24 - Math.random() * 12,
        alpha: 0,
        duration: 420,
        ease: 'Quad.easeOut',
        onComplete: () => px.destroy(),
      });
    }
  }

  private playShieldVfx(event: Extract<CombatEvent, { type: 'shield' }>): void {
    this.spawnExpandingRing(event.x, event.y, 32, 0x38bdf8, 0.75, 360);
    const amount = Math.round(event.amount);
    if (amount > 0) {
      this.spawnFloatingText(event.x, event.y - 30, `+${amount} 盾`, '#38bdf8', '11px');
    }
  }

  private playSkillCastVfx(event: Extract<CombatEvent, { type: 'skill_cast' }>): void {
    const hv = this.heroVisuals.get(event.heroId);
    const roleColor = hv ? ROLE_BADGE[hv.role].hex : 0xfacc15;
    const roleTextColor = hv ? ROLE_BADGE[hv.role].color : '#fde047';

    // Floating skill name banner above casting hero
    const banner = this.add
      .text(event.x, event.y - 42, `✦ ${event.skillName}`, {
        fontFamily: '"Microsoft JhengHei", system-ui, sans-serif',
        fontSize: '12px',
        fontStyle: 'bold',
        color: roleTextColor,
        backgroundColor: '#020617cc',
        padding: { x: 6, y: 2 },
        stroke: '#020617',
        strokeThickness: 2,
      })
      .setOrigin(0.5)
      .setDepth(52);

    this.tweens.add({
      targets: banner,
      y: banner.y - 18,
      alpha: 0,
      duration: 950,
      ease: 'Cubic.easeOut',
      onComplete: () => banner.destroy(),
    });

    // Expanding AOE / Taunt tactical circle if radius is present
    if (event.radius && event.radius > 0) {
      const cx = event.targetX ?? event.x;
      const cy = event.targetY ?? event.y;
      this.spawnExpandingRing(cx, cy, event.radius, roleColor, 0.65, 480);
    }
  }

  private playStanceChangedVfx(nextStance: TacticalStance): void {
    const style = STANCE_VISUALS[nextStance];

    // Screen-edge tint pulse
    this.edgePulseColor = style.color;
    this.edgePulseAlpha = 0.85;
    this.drawEdgePulse();

    // Banner text pop
    this.stanceBannerText.setText(style.banner);
    this.stanceBannerText.setColor(style.hex);

    const padX = 18;
    const padY = 8;
    const bw = Math.max(170, this.stanceBannerText.width + padX * 2);
    const bh = this.stanceBannerText.height + padY * 2;

    this.stanceBannerBg.clear();
    this.stanceBannerBg.fillStyle(0x020617, 0.85);
    this.stanceBannerBg.fillRoundedRect(-bw / 2, -bh / 2, bw, bh, 6);
    this.stanceBannerBg.lineStyle(2, style.color, 0.9);
    this.stanceBannerBg.strokeRoundedRect(-bw / 2, -bh / 2, bw, bh, 6);

    if (this.stanceBannerTween) {
      this.stanceBannerTween.stop();
      this.stanceBannerTween = null;
    }

    this.stanceBannerContainer.setPosition(this.arenaWidth / 2, 54);
    this.stanceBannerContainer.setAlpha(1);
    this.stanceBannerContainer.setScale(0.92);

    this.stanceBannerTween = this.tweens.add({
      targets: this.stanceBannerContainer,
      scaleX: 1,
      scaleY: 1,
      duration: 140,
      ease: 'Back.easeOut',
      onComplete: () => {
        this.stanceBannerTween = this.tweens.add({
          targets: this.stanceBannerContainer,
          alpha: 0,
          y: 44,
          delay: 750,
          duration: 380,
          ease: 'Quad.easeIn',
        });
      },
    });
  }

  private playGateHitVfx(event: Extract<CombatEvent, { type: 'gate_hit' }>): void {
    // Camera micro-shake
    this.cameras.main.shake(150, 0.006);

    // Red flash on village gate
    this.gateDamageFlash.setAlpha(0.52);
    this.tweens.add({
      targets: this.gateDamageFlash,
      alpha: 0,
      duration: 240,
      ease: 'Quad.easeOut',
    });

    // Floating -DMG on gate
    const hitY = Phaser.Math.Clamp(event.y, 70, this.arenaHeight - 70);
    this.spawnFloatingText(
      this.gateX - 10,
      hitY,
      `-${Math.round(event.amount)}`,
      '#ef4444',
      '16px',
    );
  }

  private playUnitDiedVfx(event: Extract<CombatEvent, { type: 'unit_died' }>): void {
    let burstColor = event.team === 'hero' ? 0x38bdf8 : 0xef4444;
    if (event.team === 'enemy') {
      const ev = this.enemyVisuals.get(event.unitId);
      if (ev) {
        burstColor = ENEMY_TINT_BURST[ev.archetype];
      }
    }

    // Pixel burst particles
    const count = 10;
    for (let i = 0; i < count; i += 1) {
      const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.4;
      const speed = 22 + Math.random() * 34;
      const px = this.add
        .image(event.x, event.y, 'px-square')
        .setTint(i % 2 === 0 ? burstColor : 0xf8fafc)
        .setScale(1.1)
        .setDepth(45);

      this.tweens.add({
        targets: px,
        x: event.x + Math.cos(angle) * speed,
        y: event.y + Math.sin(angle) * speed + 10,
        alpha: 0,
        scaleX: 0.3,
        scaleY: 0.3,
        duration: 360 + Math.random() * 140,
        ease: 'Quad.easeOut',
        onComplete: () => px.destroy(),
      });
    }
  }

  private playSpawnRing(x: number, y: number, color: number): void {
    this.spawnExpandingRing(x, y, 28, color, 0.7, 320);
  }

  private spawnExpandingRing(
    x: number,
    y: number,
    maxRadius: number,
    color: number,
    startAlpha: number,
    duration: number,
  ): void {
    const ring = this.add
      .circle(x, y, Math.max(8, maxRadius * 0.25), color, startAlpha * 0.2)
      .setStrokeStyle(2, color, startAlpha)
      .setDepth(41);

    const targetScale = maxRadius / Math.max(8, maxRadius * 0.25);

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
    content: string,
    color: string,
    fontSize: string,
  ): void {
    const txt = this.add
      .text(Math.round(x), Math.round(y), content, {
        fontFamily: 'monospace, "Microsoft JhengHei", sans-serif',
        fontSize,
        fontStyle: 'bold',
        color,
        stroke: '#020617',
        strokeThickness: 3,
      })
      .setOrigin(0.5)
      .setDepth(50);

    this.tweens.add({
      targets: txt,
      y: txt.y - 26,
      alpha: 0,
      duration: 680,
      ease: 'Cubic.easeOut',
      onComplete: () => txt.destroy(),
    });
  }

  private clearAllUnits(): void {
    for (const hv of this.heroVisuals.values()) {
      hv.container.destroy();
    }
    this.heroVisuals.clear();

    for (const ev of this.enemyVisuals.values()) {
      ev.container.destroy();
    }
    this.enemyVisuals.clear();
  }
}
