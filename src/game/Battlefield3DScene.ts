import * as THREE from 'three';
import type {
  CombatEvent,
  CombatSnapshot,
  EnemyState,
  EnemyUnitType,
  RegimentType,
  SoldierState,
} from '../core/types/combat';
import {
  createEnemyRig,
  createFormationSlotDisc,
  createHeroRig,
  createRegimentBanner,
  createSoldierRig,
  disposeObject3D,
  type BannerRig,
  type CharacterRig,
} from './models3d';

export type CameraMode = 'tactical' | 'tps';

export interface CameraBasis2D {
  forwardX: number; // core X component of camera forward on ground plane
  forwardY: number; // core Y component of camera forward on ground plane
  rightX: number;   // core X component of camera right on ground plane
  rightY: number;   // core Y component of camera right on ground plane
}

export interface PointerWorldState {
  x: number;
  y: number;
  leftDown: boolean;
  rightDown: boolean;
}

export const DEFAULT_ARENA_WIDTH = 1080;
export const DEFAULT_ARENA_HEIGHT = 600;
export const DEFAULT_GATE_X = 80;
export const WORLD_SCALE = 0.05;

export function toWorldX(coreX: number): number {
  return (coreX - DEFAULT_ARENA_WIDTH / 2) * WORLD_SCALE;
}

export function toWorldZ(coreY: number): number {
  return (coreY - DEFAULT_ARENA_HEIGHT / 2) * WORLD_SCALE;
}

export function toCoreX(worldX: number): number {
  return Math.max(0, Math.min(DEFAULT_ARENA_WIDTH, worldX / WORLD_SCALE + DEFAULT_ARENA_WIDTH / 2));
}

export function toCoreY(worldZ: number): number {
  return Math.max(0, Math.min(DEFAULT_ARENA_HEIGHT, worldZ / WORLD_SCALE + DEFAULT_ARENA_HEIGHT / 2));
}

interface OverheadBar {
  sprite: THREE.Sprite;
  canvas: HTMLCanvasElement;
  ctx: CanvasRenderingContext2D;
  texture: THREE.CanvasTexture;
  lastRatio: number;
  lastMax: number;
  isBoss: boolean;
  label?: string;
}

interface TrackedSoldier {
  rig: CharacterRig;
  slotDisc: THREE.Mesh;
  hpBar: OverheadBar;
  prevX: number;
  prevZ: number;
  lastAttackCd: number;
}

interface TrackedEnemy {
  type: EnemyUnitType;
  rig: CharacterRig;
  hpBar: OverheadBar;
  prevX: number;
  prevZ: number;
  telegraphGroup?: THREE.Group;
  telegraphFill?: THREE.Mesh;
  telegraphRing?: THREE.Mesh;
}

interface ActiveVfx {
  obj: THREE.Object3D;
  age: number;
  duration: number;
  update: (t: number, dt: number) => void;
}

interface ArrowVfx {
  mesh: THREE.Mesh;
  from: THREE.Vector3;
  to: THREE.Vector3;
  peakY: number;
  age: number;
  duration: number;
}

interface ParticleVfx {
  mesh: THREE.Mesh;
  vel: THREE.Vector3;
  rotVel: THREE.Vector3;
  age: number;
  duration: number;
}

interface FloatingSpriteVfx {
  sprite: THREE.Sprite;
  age: number;
  duration: number;
  riseSpeed: number;
}

interface VolleyVisual {
  group: THREE.Group;
  fillMesh: THREE.Mesh;
  ringMesh: THREE.Mesh;
}

function createGrassTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.fillStyle = '#131f1b';
    ctx.fillRect(0, 0, 512, 512);

    // Subtle organic dark grass & soil patches
    for (let i = 0; i < 1600; i++) {
      const x = (i * 73) % 512;
      const y = (i * 137 + Math.floor(i / 7) * 29) % 512;
      const shade = i % 3 === 0 ? '#182822' : i % 3 === 1 ? '#0f1916' : '#1d2f27';
      ctx.fillStyle = shade;
      ctx.fillRect(x, y, 4 + (i % 6), 3 + (i % 5));
    }

    // Subtle tactical grid
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.06)';
    ctx.lineWidth = 1;
    for (let g = 0; g <= 512; g += 64) {
      ctx.beginPath();
      ctx.moveTo(g, 0);
      ctx.lineTo(g, 512);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, g);
      ctx.lineTo(512, g);
      ctx.stroke();
    }
  }
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(6, 4);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function createCobbleTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 256;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.fillStyle = '#1e2430';
    ctx.fillRect(0, 0, 256, 256);

    const rows = 8;
    const cols = 6;
    const rh = 256 / rows;
    const cw = 256 / cols;

    for (let r = 0; r < rows; r++) {
      const offset = (r % 2) * (cw * 0.5);
      for (let c = -1; c <= cols; c++) {
        const x = c * cw + offset;
        const y = r * rh;
        const v = 38 + ((r * 17 + c * 31) & 15);
        ctx.fillStyle = `rgb(${v}, ${v + 5}, ${v + 14})`;
        ctx.fillRect(x + 2, y + 2, cw - 4, rh - 4);
      }
    }
  }
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(12, 3);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function createOverheadBar(
  widthWorld: number,
  heightWorld: number,
  isBoss = false,
  label?: string
): OverheadBar {
  const canvas = document.createElement('canvas');
  canvas.width = isBoss ? 256 : 128;
  canvas.height = isBoss ? 56 : 24;
  const ctx = canvas.getContext('2d')!;
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const mat = new THREE.SpriteMaterial({
    map: texture,
    transparent: true,
    depthTest: false,
    depthWrite: false,
  });
  const sprite = new THREE.Sprite(mat);
  sprite.scale.set(widthWorld, heightWorld, 1);
  sprite.renderOrder = 20;

  return {
    sprite,
    canvas,
    ctx,
    texture,
    lastRatio: -1,
    lastMax: -1,
    isBoss,
    label,
  };
}

function updateOverheadBar(
  bar: OverheadBar,
  hp: number,
  maxHp: number,
  fillColor: string
): void {
  const ratio = maxHp > 0 ? Math.max(0, Math.min(1, hp / maxHp)) : 0;
  if (Math.abs(ratio - bar.lastRatio) < 0.005 && maxHp === bar.lastMax) {
    return;
  }
  bar.lastRatio = ratio;
  bar.lastMax = maxHp;

  const { ctx, canvas, isBoss, label } = bar;
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  if (isBoss) {
    if (label) {
      ctx.font = 'bold 20px "Segoe UI", sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = '#fca5a5';
      ctx.strokeStyle = '#090d16';
      ctx.lineWidth = 4;
      ctx.strokeText(label, canvas.width / 2, 20);
      ctx.fillText(label, canvas.width / 2, 20);
    }
    const bx = 8;
    const by = 28;
    const bw = canvas.width - 16;
    const bh = 20;
    ctx.fillStyle = 'rgba(9, 13, 22, 0.88)';
    ctx.fillRect(bx - 2, by - 2, bw + 4, bh + 4);
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 2;
    ctx.strokeRect(bx - 2, by - 2, bw + 4, bh + 4);
    ctx.fillStyle = '#3f0f15';
    ctx.fillRect(bx, by, bw, bh);
    ctx.fillStyle = fillColor;
    ctx.fillRect(bx, by, Math.round(bw * ratio), bh);
  } else {
    const bx = 6;
    const by = 6;
    const bw = canvas.width - 12;
    const bh = canvas.height - 12;
    ctx.fillStyle = 'rgba(9, 13, 22, 0.85)';
    ctx.fillRect(bx - 2, by - 2, bw + 4, bh + 4);
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(bx, by, bw, bh);
    ctx.fillStyle = fillColor;
    ctx.fillRect(bx, by, Math.round(bw * ratio), bh);
  }

  bar.texture.needsUpdate = true;
}

function createTextSprite(
  text: string,
  color: string,
  fontSize = 36,
  strokeColor = '#090d16',
  scaleFactor = 0.0125
): THREE.Sprite {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d')!;
  const font = `900 ${fontSize}px "Segoe UI", "Microsoft JhengHei", sans-serif`;
  ctx.font = font;
  const metrics = ctx.measureText(text);
  const w = Math.max(64, Math.ceil(metrics.width + 28));
  const h = Math.ceil(fontSize * 1.55);
  canvas.width = w;
  canvas.height = h;

  ctx.font = font;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineWidth = Math.max(4, Math.round(fontSize * 0.16));
  ctx.strokeStyle = strokeColor;
  ctx.strokeText(text, w / 2, h / 2);
  ctx.fillStyle = color;
  ctx.fillText(text, w / 2, h / 2);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const mat = new THREE.SpriteMaterial({
    map: texture,
    transparent: true,
    depthTest: false,
    depthWrite: false,
  });
  const sprite = new THREE.Sprite(mat);
  sprite.scale.set(w * scaleFactor, h * scaleFactor, 1);
  sprite.renderOrder = 30;
  return sprite;
}

export class Battlefield3DScene {
  private container: HTMLElement;
  private renderer: THREE.WebGLRenderer;
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private resizeObserver: ResizeObserver;

  private rafId: number | null = null;
  private lastFrameMs = 0;
  private elapsedTime = 0;
  private destroyed = false;

  // Camera state
  private cameraMode: CameraMode = 'tactical';
  private currentCamPos = new THREE.Vector3(-4, 25, 20);
  private currentCamLook = new THREE.Vector3(0, 0, 0);
  private shakeIntensity = 0;

  // Pointer & Raycaster
  private raycaster = new THREE.Raycaster();
  private groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private pointerNdc = new THREE.Vector2(0, 0);
  private pointerInside = false;
  private pointerState: PointerWorldState = {
    x: DEFAULT_ARENA_WIDTH * 0.5,
    y: DEFAULT_ARENA_HEIGHT * 0.5,
    leftDown: false,
    rightDown: false,
  };
  private crosshairGroup: THREE.Group;
  private crosshairOuterRing: THREE.Mesh;

  // Environment references
  private torchLights: THREE.PointLight[] = [];
  private torchFlames: THREE.Mesh[] = [];
  private gateWoodMat!: THREE.MeshStandardMaterial;
  private gateFlashSec = 0;
  private builtGateX = DEFAULT_GATE_X;
  private wallGroup: THREE.Group | null = null;

  // Entities
  private latestSnapshot: CombatSnapshot | null = null;
  private heroRig: CharacterRig;
  private heroHpBar: OverheadBar;
  private heroRespawnRing: THREE.Mesh;
  private prevHeroX = 0;
  private prevHeroZ = 0;

  private currentRegimentType: RegimentType | null = null;
  private soldiers = new Map<string, TrackedSoldier>();
  private bannerRig: BannerRig;

  private enemies = new Map<string, TrackedEnemy>();
  private volleys = new Map<string, VolleyVisual>();

  // VFX pools
  private activeVfx: ActiveVfx[] = [];
  private arrowVfx: ArrowVfx[] = [];
  private particles: ParticleVfx[] = [];
  private floatingSprites: FloatingSpriteVfx[] = [];

  // Shared particle geometry
  private sharedCubeGeo = new THREE.BoxGeometry(0.18, 0.18, 0.18);
  private sharedArrowGeo = new THREE.CylinderGeometry(0.03, 0.03, 1.05, 5);

  // Bound event listeners
  private onPointerMoveBound: (e: PointerEvent) => void;
  private onPointerDownBound: (e: PointerEvent) => void;
  private onPointerUpBound: (e: PointerEvent) => void;
  private onPointerLeaveBound: () => void;
  private onContextMenuBound: (e: MouseEvent) => void;

  constructor(container: HTMLElement, initialSnapshot?: CombatSnapshot) {
    this.container = container;

    // 1. Renderer
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.12;
    this.renderer.domElement.style.display = 'block';
    this.renderer.domElement.style.width = '100%';
    this.renderer.domElement.style.height = '100%';
    this.renderer.domElement.style.cursor = 'crosshair';
    this.container.appendChild(this.renderer.domElement);

    // 2. Scene & Atmosphere
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x0a1020);
    this.scene.fog = new THREE.FogExp2(0x0a1020, 0.011);

    // 3. Camera
    const initW = Math.max(1, container.clientWidth || 1080);
    const initH = Math.max(1, container.clientHeight || 600);
    this.camera = new THREE.PerspectiveCamera(42, initW / initH, 0.5, 160);
    this.camera.position.copy(this.currentCamPos);
    this.camera.lookAt(this.currentCamLook);
    this.renderer.setSize(initW, initH, false);

    // 4. Lighting & 3D Environment
    this.setupLighting();
    this.buildEnvironment(initialSnapshot?.gateX ?? DEFAULT_GATE_X);

    // 5. Crosshair
    const { group, outerRing } = this.createCrosshair();
    this.crosshairGroup = group;
    this.crosshairOuterRing = outerRing;
    this.scene.add(this.crosshairGroup);

    // 6. Hero & Banner
    this.heroRig = createHeroRig();
    this.scene.add(this.heroRig.root);

    this.heroHpBar = createOverheadBar(1.85, 0.34, false);
    this.heroHpBar.sprite.position.set(0, this.heroRig.baseHeight + 0.5, 0);
    this.heroRig.root.add(this.heroHpBar.sprite);

    this.heroRespawnRing = new THREE.Mesh(
      new THREE.RingGeometry(0.9, 1.15, 28),
      new THREE.MeshBasicMaterial({
        color: 0x38bdf8,
        transparent: true,
        opacity: 0.6,
        side: THREE.DoubleSide,
        depthWrite: false,
      })
    );
    this.heroRespawnRing.rotation.x = -Math.PI / 2;
    this.heroRespawnRing.position.y = 0.08;
    this.heroRespawnRing.visible = false;
    this.scene.add(this.heroRespawnRing);

    this.bannerRig = createRegimentBanner();
    this.bannerRig.root.visible = false;
    this.scene.add(this.bannerRig.root);

    // Orient shared arrow geometry along +Z so lookAt() aligns arrow tip forward
    this.sharedArrowGeo.rotateX(Math.PI / 2);

    // 7. Pointer events
    this.onPointerMoveBound = (e) => this.handlePointerMove(e);
    this.onPointerDownBound = (e) => this.handlePointerDown(e);
    this.onPointerUpBound = (e) => this.handlePointerUp(e);
    this.onPointerLeaveBound = () => this.handlePointerLeave();
    this.onContextMenuBound = (e) => {
      e.preventDefault();
    };

    const canvas = this.renderer.domElement;
    canvas.addEventListener('pointermove', this.onPointerMoveBound);
    canvas.addEventListener('pointerdown', this.onPointerDownBound);
    window.addEventListener('pointerup', this.onPointerUpBound);
    canvas.addEventListener('pointerleave', this.onPointerLeaveBound);
    canvas.addEventListener('contextmenu', this.onContextMenuBound);

    // 8. ResizeObserver
    this.resizeObserver = new ResizeObserver(() => this.handleResize());
    this.resizeObserver.observe(this.container);

    // 9. Initial snapshot
    if (initialSnapshot) {
      this.syncState(initialSnapshot, []);
      // Snap camera immediately on first frame
      const hx = toWorldX(initialSnapshot.hero.x);
      const hz = toWorldZ(initialSnapshot.hero.y);
      this.currentCamLook.set(hx * 0.45 + 2.0, 0, hz * 0.35);
      this.currentCamPos.set(hx * 0.45, 25, hz * 0.35 + 20);
      this.camera.position.copy(this.currentCamPos);
      this.camera.lookAt(this.currentCamLook);
    }

    // 10. Start loop
    this.lastFrameMs = performance.now();
    this.rafId = requestAnimationFrame(this.loop);
  }

  private setupLighting(): void {
    // Hemisphere sky/ground fill
    const hemi = new THREE.HemisphereLight(0x7aa2f7, 0x161c2c, 0.82);
    this.scene.add(hemi);

    // Cool blue-white directional moonlight with real soft shadows
    const moon = new THREE.DirectionalLight(0xcfe0ff, 1.55);
    moon.position.set(-16, 34, 18);
    moon.castShadow = true;
    moon.shadow.mapSize.width = 2048;
    moon.shadow.mapSize.height = 2048;
    moon.shadow.camera.near = 5;
    moon.shadow.camera.far = 90;
    moon.shadow.camera.left = -34;
    moon.shadow.camera.right = 34;
    moon.shadow.camera.top = 24;
    moon.shadow.camera.bottom = -24;
    moon.shadow.bias = -0.0006;
    this.scene.add(moon);

    // Subtle rim light from east/enemy side for silhouette pop
    const rim = new THREE.DirectionalLight(0x4f75b8, 0.45);
    rim.position.set(28, 16, -20);
    this.scene.add(rim);
  }

  private buildEnvironment(gateX: number): void {
    this.builtGateX = gateX;

    // 1. Dark-grass siege plain (slightly larger than arena so edges blend into fog)
    const grassTex = createGrassTexture();
    const groundMat = new THREE.MeshStandardMaterial({
      map: grassTex,
      roughness: 0.92,
      metalness: 0.04,
    });
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(86, 56), groundMat);
    ground.rotation.x = -Math.PI / 2;
    ground.position.y = 0;
    ground.receiveShadow = true;
    this.scene.add(ground);

    // 2. Raised cobblestone central siege road (z in [-5.5, 5.5])
    const cobbleTex = createCobbleTexture();
    const roadMat = new THREE.MeshStandardMaterial({
      map: cobbleTex,
      roughness: 0.82,
      metalness: 0.08,
    });
    const road = new THREE.Mesh(new THREE.BoxGeometry(58, 0.08, 11.0), roadMat);
    road.position.set(1, 0.01, 0);
    road.receiveShadow = true;
    this.scene.add(road);

    // Stone road curbs
    const curbMat = new THREE.MeshStandardMaterial({
      color: 0x334155,
      roughness: 0.85,
      metalness: 0.1,
    });
    for (const zSign of [-1, 1]) {
      const curb = new THREE.Mesh(new THREE.BoxGeometry(58, 0.16, 0.36), curbMat);
      curb.position.set(1, 0.08, zSign * 5.65);
      curb.receiveShadow = true;
      curb.castShadow = true;
      this.scene.add(curb);
    }

    // 3. Subtle tactical distance lane lines across battlefield
    const laneMat = new THREE.MeshBasicMaterial({
      color: 0x64748b,
      transparent: true,
      opacity: 0.16,
      depthWrite: false,
    });
    for (const coreX of [240, 440, 640, 840, 1000]) {
      const line = new THREE.Mesh(new THREE.PlaneGeometry(0.12, 29.6), laneMat);
      line.rotation.x = -Math.PI / 2;
      line.position.set(toWorldX(coreX), 0.055, 0);
      this.scene.add(line);
    }

    // 4. Wooden palisades along top/bottom arena borders (z = ±15.2)
    const woodMat = new THREE.MeshStandardMaterial({
      color: 0x452b18,
      roughness: 0.9,
      metalness: 0.05,
      flatShading: true,
    });
    const palisadeGroup = new THREE.Group();
    const stakeGeo = new THREE.ConeGeometry(0.24, 1.55, 5);
    const railGeo = new THREE.BoxGeometry(56, 0.18, 0.18);

    for (const zSign of [-1, 1]) {
      const zPos = zSign * 15.2;
      const rail1 = new THREE.Mesh(railGeo, woodMat);
      rail1.position.set(0, 0.55, zPos);
      rail1.castShadow = true;
      palisadeGroup.add(rail1);

      const rail2 = new THREE.Mesh(railGeo, woodMat);
      rail2.position.set(0, 1.0, zPos);
      rail2.castShadow = true;
      palisadeGroup.add(rail2);

      for (let wx = -26; wx <= 27; wx += 1.35) {
        const stake = new THREE.Mesh(stakeGeo, woodMat);
        stake.position.set(wx, 0.78, zPos);
        stake.castShadow = true;
        stake.receiveShadow = true;
        palisadeGroup.add(stake);
      }
    }
    this.scene.add(palisadeGroup);

    // 5. 3D Stone Castle Wall & Gatehouse
    this.buildCastleWall(gateX);
  }

  private buildCastleWall(gateX: number): void {
    if (this.wallGroup) {
      this.scene.remove(this.wallGroup);
      disposeObject3D(this.wallGroup);
      this.torchLights = [];
      this.torchFlames = [];
    }

    const group = new THREE.Group();
    const wx = toWorldX(gateX);
    group.position.set(wx, 0, 0);

    const stoneMat = new THREE.MeshStandardMaterial({
      color: 0x3f4b5e,
      roughness: 0.85,
      metalness: 0.1,
      flatShading: true,
    });
    const darkStoneMat = new THREE.MeshStandardMaterial({
      color: 0x2a3342,
      roughness: 0.9,
      metalness: 0.1,
      flatShading: true,
    });
    const ironMat = new THREE.MeshStandardMaterial({
      color: 0x1e293b,
      roughness: 0.45,
      metalness: 0.75,
    });
    this.gateWoodMat = new THREE.MeshStandardMaterial({
      color: 0x5c361d,
      roughness: 0.82,
      metalness: 0.1,
      emissive: 0x000000,
      emissiveIntensity: 0,
    });

    // North & South main wall segments
    for (const zSign of [-1, 1]) {
      const wallSeg = new THREE.Mesh(new THREE.BoxGeometry(2.1, 4.4, 9.8), stoneMat);
      wallSeg.position.set(-0.8, 2.2, zSign * 10.6);
      wallSeg.castShadow = true;
      wallSeg.receiveShadow = true;
      group.add(wallSeg);

      // Battlement crenelations (merlons)
      for (let i = 0; i < 6; i++) {
        const merlon = new THREE.Mesh(new THREE.BoxGeometry(0.75, 0.9, 1.05), darkStoneMat);
        merlon.position.set(0.05, 4.8, zSign * (6.6 + i * 1.65));
        merlon.castShadow = true;
        group.add(merlon);
      }

      // Twin Watchtowers flanking the gate at z = ±5.7
      const tower = new THREE.Mesh(new THREE.BoxGeometry(3.2, 6.4, 3.2), darkStoneMat);
      tower.position.set(-0.6, 3.2, zSign * 5.7);
      tower.castShadow = true;
      tower.receiveShadow = true;
      group.add(tower);

      const towerCap = new THREE.Mesh(new THREE.BoxGeometry(3.6, 0.55, 3.6), stoneMat);
      towerCap.position.set(-0.6, 6.55, zSign * 5.7);
      towerCap.castShadow = true;
      group.add(towerCap);

      // Tower corner merlons
      for (const ox of [-1.45, 1.45]) {
        for (const oz of [-1.45, 1.45]) {
          const capMerlon = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.8, 0.7), stoneMat);
          capMerlon.position.set(-0.6 + ox, 7.15, zSign * 5.7 + oz);
          capMerlon.castShadow = true;
          group.add(capMerlon);
        }
      }

      // Glowing Brazier + flickering warm PointLight torch
      const brazier = new THREE.Mesh(new THREE.CylinderGeometry(0.48, 0.3, 0.6, 6), ironMat);
      brazier.position.set(0.75, 7.1, zSign * 5.7);
      group.add(brazier);

      const flameMat = new THREE.MeshBasicMaterial({ color: 0xffa94d });
      const flame = new THREE.Mesh(new THREE.ConeGeometry(0.36, 1.0, 5), flameMat);
      flame.position.set(0.75, 7.85, zSign * 5.7);
      group.add(flame);
      this.torchFlames.push(flame);

      const torchLight = new THREE.PointLight(0xff8c3a, 18, 22, 1.6);
      torchLight.position.set(1.3, 8.1, zSign * 5.7);
      group.add(torchLight);
      this.torchLights.push(torchLight);
    }

    // Overhead gatehouse lintel arch
    const archTop = new THREE.Mesh(new THREE.BoxGeometry(2.5, 1.8, 8.6), stoneMat);
    archTop.position.set(-0.6, 4.7, 0);
    archTop.castShadow = true;
    group.add(archTop);

    // Reinforced wooden double gate (z in [-4.1, +4.1])
    for (const zSign of [-1, 1]) {
      const door = new THREE.Mesh(new THREE.BoxGeometry(0.65, 3.85, 3.95), this.gateWoodMat);
      door.position.set(0.05, 1.92, zSign * 2.02);
      door.castShadow = true;
      door.receiveShadow = true;
      group.add(door);

      // Horizontal iron reinforcement bands
      for (const bandY of [0.9, 1.95, 3.0]) {
        const band = new THREE.Mesh(new THREE.BoxGeometry(0.74, 0.2, 3.9), ironMat);
        band.position.set(0.08, bandY, zSign * 2.02);
        group.add(band);
      }
    }

    this.wallGroup = group;
    this.scene.add(group);
  }

  private createCrosshair(): { group: THREE.Group; outerRing: THREE.Mesh } {
    const group = new THREE.Group();
    group.position.set(0, 0.09, 0);

    const outerRing = new THREE.Mesh(
      new THREE.RingGeometry(0.58, 0.72, 24),
      new THREE.MeshBasicMaterial({
        color: 0x38bdf8,
        transparent: true,
        opacity: 0.85,
        side: THREE.DoubleSide,
        depthWrite: false,
      })
    );
    outerRing.rotation.x = -Math.PI / 2;
    group.add(outerRing);

    const innerDot = new THREE.Mesh(
      new THREE.CircleGeometry(0.14, 14),
      new THREE.MeshBasicMaterial({
        color: 0xfef08a,
        transparent: true,
        opacity: 0.95,
        side: THREE.DoubleSide,
        depthWrite: false,
      })
    );
    innerDot.rotation.x = -Math.PI / 2;
    group.add(innerDot);

    const tickMat = new THREE.MeshBasicMaterial({
      color: 0x7dd3fc,
      transparent: true,
      opacity: 0.85,
      side: THREE.DoubleSide,
      depthWrite: false,
    });
    for (let i = 0; i < 4; i++) {
      const angle = (i * Math.PI) / 2;
      const tick = new THREE.Mesh(new THREE.PlaneGeometry(0.28, 0.08), tickMat);
      tick.rotation.x = -Math.PI / 2;
      tick.rotation.z = angle;
      tick.position.set(Math.cos(angle) * 0.88, 0.01, -Math.sin(angle) * 0.88);
      group.add(tick);
    }

    return { group, outerRing };
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  public setCameraMode(mode: CameraMode): void {
    this.cameraMode = mode;
  }

  public getCameraMode(): CameraMode {
    return this.cameraMode;
  }

  public getCameraBasis2D(): CameraBasis2D {
    const dir = new THREE.Vector3();
    this.camera.getWorldDirection(dir);
    const fx = dir.x;
    const fy = dir.z;
    const len = Math.hypot(fx, fy);
    if (len < 1e-4) {
      return { forwardX: 0, forwardY: -1, rightX: 1, rightY: 0 };
    }
    const forwardX = fx / len;
    const forwardY = fy / len;
    return {
      forwardX,
      forwardY,
      rightX: -forwardY,
      rightY: forwardX,
    };
  }

  public getPointerState(): PointerWorldState {
    return { ...this.pointerState };
  }

  public syncState(snapshot: CombatSnapshot, events: CombatEvent[]): void {
    if (this.destroyed) return;
    this.latestSnapshot = snapshot;

    if (snapshot.gateX !== this.builtGateX) {
      this.buildCastleWall(snapshot.gateX);
    }

    // 1. Sync Hero
    this.syncHero(snapshot);

    // 2. Sync Regiment Soldiers & Banner
    this.syncRegiment(snapshot);

    // 3. Sync Enemies & Telegraphs
    this.syncEnemies(snapshot);

    // 4. Sync Pending Archer Volleys
    this.syncVolleys(snapshot);

    // 5. Process Combat Events into 3D VFX
    for (const ev of events) {
      this.handleCombatEvent(ev);
    }
  }

  // ---------------------------------------------------------------------------
  // Entity Sync Helpers
  // ---------------------------------------------------------------------------

  private syncHero(snapshot: CombatSnapshot): void {
    const { hero } = snapshot;
    const wx = toWorldX(hero.x);
    const wz = toWorldZ(hero.y);

    this.heroRig.root.visible = hero.alive;
    this.heroRespawnRing.visible = !hero.alive;

    if (!hero.alive) {
      this.heroRespawnRing.position.set(wx, 0.08, wz);
      return;
    }

    this.heroRig.root.position.set(wx, 0, wz);
    this.heroRig.root.rotation.y = -hero.facingAngle;

    const moved = Math.hypot(wx - this.prevHeroX, wz - this.prevHeroZ);
    this.prevHeroX = wx;
    this.prevHeroZ = wz;

    // Walk bobbing & cape sway
    if (moved > 0.01) {
      const bob = Math.abs(Math.sin(this.elapsedTime * 12)) * 0.14;
      this.heroRig.bodyGroup.position.y = bob;
      if (this.heroRig.capeMesh) {
        this.heroRig.capeMesh.rotation.z = -0.34 - Math.sin(this.elapsedTime * 14) * 0.1;
      }
    } else {
      this.heroRig.bodyGroup.position.y = Math.sin(this.elapsedTime * 3) * 0.03;
      if (this.heroRig.capeMesh) {
        this.heroRig.capeMesh.rotation.z = -0.22 - Math.sin(this.elapsedTime * 2.5) * 0.04;
      }
    }

    // Warcry golden aura ring
    if (this.heroRig.auraRing) {
      const active = hero.warcryRemainingSec > 0;
      this.heroRig.auraRing.visible = active;
      if (active) {
        const pulse = 1 + Math.sin(this.elapsedTime * 8) * 0.12;
        this.heroRig.auraRing.scale.setScalar(pulse);
      }
    }

    // Dodge / invulnerable translucent blue shell
    if (this.heroRig.dodgeShell) {
      const invuln = hero.dodgeRemainingSec > 0 || hero.invulnerableRemainingSec > 0;
      this.heroRig.dodgeShell.visible = invuln;
      if (invuln) {
        const s = 1 + Math.sin(this.elapsedTime * 20) * 0.06;
        this.heroRig.dodgeShell.scale.setScalar(s);
      }
    }

    updateOverheadBar(this.heroHpBar, hero.hp, hero.maxHp, '#38bdf8');
  }

  private syncRegiment(snapshot: CombatSnapshot): void {
    const { regiment } = snapshot;

    // Rebuild soldier rigs if regiment type changed (e.g. battle restart with new unit)
    if (this.currentRegimentType !== regiment.type) {
      for (const tracked of this.soldiers.values()) {
        this.scene.remove(tracked.rig.root);
        this.scene.remove(tracked.slotDisc);
        disposeObject3D(tracked.rig.root);
        disposeObject3D(tracked.slotDisc);
      }
      this.soldiers.clear();
      this.currentRegimentType = regiment.type;
    }

    // Banner flag when holding position
    const showBanner = regiment.order === 'hold' && regiment.aliveCount > 0;
    this.bannerRig.root.visible = showBanner;
    if (showBanner) {
      this.bannerRig.root.position.set(toWorldX(regiment.anchorX), 0, toWorldZ(regiment.anchorY));
    }

    const activeIds = new Set<string>();
    for (const s of regiment.soldiers) {
      activeIds.add(s.id);
      let tracked = this.soldiers.get(s.id);
      if (!tracked) {
        const rig = createSoldierRig(regiment.type);
        const slotDisc = createFormationSlotDisc();
        const hpBar = createOverheadBar(1.15, 0.22, false);
        hpBar.sprite.position.set(0, rig.baseHeight + 0.35, 0);
        rig.root.add(hpBar.sprite);

        this.scene.add(rig.root);
        this.scene.add(slotDisc);

        tracked = {
          rig,
          slotDisc,
          hpBar,
          prevX: toWorldX(s.x),
          prevZ: toWorldZ(s.y),
          lastAttackCd: s.attackCooldownSec,
        };
        this.soldiers.set(s.id, tracked);
      }

      this.updateSoldierVisual(tracked, s);
    }

    for (const [id, tracked] of this.soldiers.entries()) {
      if (!activeIds.has(id)) {
        this.scene.remove(tracked.rig.root);
        this.scene.remove(tracked.slotDisc);
        disposeObject3D(tracked.rig.root);
        disposeObject3D(tracked.slotDisc);
        this.soldiers.delete(id);
      }
    }
  }

  private updateSoldierVisual(tracked: TrackedSoldier, s: SoldierState): void {
    tracked.rig.root.visible = s.alive;
    tracked.slotDisc.visible = s.alive;
    if (!s.alive) return;

    const wx = toWorldX(s.x);
    const wz = toWorldZ(s.y);
    tracked.rig.root.position.set(wx, 0, wz);
    tracked.rig.root.rotation.y = -s.facingAngle;

    // Formation slot disc
    tracked.slotDisc.position.set(toWorldX(s.slotX), 0.035, toWorldZ(s.slotY));

    // Walk bob
    const moved = Math.hypot(wx - tracked.prevX, wz - tracked.prevZ);
    tracked.prevX = wx;
    tracked.prevZ = wz;
    if (moved > 0.008) {
      tracked.rig.bodyGroup.position.y = Math.abs(Math.sin(this.elapsedTime * 11 + s.index)) * 0.11;
    } else {
      tracked.rig.bodyGroup.position.y = 0;
    }

    // Charge lean forward
    tracked.rig.bodyGroup.rotation.z = s.chargingRemainingSec > 0 ? -0.24 : 0;

    // Trigger weapon swing pulse when attackCooldownSec jumps up
    if (s.attackCooldownSec > tracked.lastAttackCd + 0.1) {
      tracked.rig.swingPhase = 1;
    }
    tracked.lastAttackCd = s.attackCooldownSec;

    // Shieldman blocking glow
    if (tracked.rig.shieldMaterial) {
      if (s.shieldBlocking) {
        tracked.rig.shieldMaterial.emissive.setHex(0x22d3ee);
        tracked.rig.shieldMaterial.emissiveIntensity = 0.85;
      } else {
        tracked.rig.shieldMaterial.emissive.setHex(0x06b6d4);
        tracked.rig.shieldMaterial.emissiveIntensity = 0.1;
      }
    }

    // Overhead HP bar (only show when damaged to keep battlefield clean)
    const damaged = s.hp < s.maxHp;
    tracked.hpBar.sprite.visible = damaged;
    if (damaged) {
      updateOverheadBar(tracked.hpBar, s.hp, s.maxHp, '#34d399');
    }
  }

  private syncEnemies(snapshot: CombatSnapshot): void {
    const activeIds = new Set<string>();

    for (const e of snapshot.enemies) {
      if (!e.alive) continue;
      activeIds.add(e.id);

      let tracked = this.enemies.get(e.id);
      if (!tracked || tracked.type !== e.type) {
        if (tracked) {
          this.removeEnemyVisual(tracked);
        }
        const rig = createEnemyRig(e.type);
        const hpBar = e.isCommander
          ? createOverheadBar(3.4, 0.74, true, e.name)
          : createOverheadBar(1.3, 0.24, false);
        hpBar.sprite.position.set(0, rig.baseHeight + (e.isCommander ? 0.8 : 0.35), 0);
        rig.root.add(hpBar.sprite);
        this.scene.add(rig.root);

        tracked = {
          type: e.type,
          rig,
          hpBar,
          prevX: toWorldX(e.x),
          prevZ: toWorldZ(e.y),
        };
        this.enemies.set(e.id, tracked);
      }

      this.updateEnemyVisual(tracked, e);
    }

    for (const [id, tracked] of this.enemies.entries()) {
      if (!activeIds.has(id)) {
        this.removeEnemyVisual(tracked);
        this.enemies.delete(id);
      }
    }
  }

  private updateEnemyVisual(tracked: TrackedEnemy, e: EnemyState): void {
    const wx = toWorldX(e.x);
    const wz = toWorldZ(e.y);
    tracked.rig.root.position.set(wx, 0, wz);
    tracked.rig.root.rotation.y = -e.facingAngle;

    const moved = Math.hypot(wx - tracked.prevX, wz - tracked.prevZ);
    tracked.prevX = wx;
    tracked.prevZ = wz;
    if (moved > 0.008) {
      tracked.rig.bodyGroup.position.y = Math.abs(Math.sin(this.elapsedTime * 10 + wx)) * 0.1;
    } else {
      tracked.rig.bodyGroup.position.y = 0;
    }

    // Overhead HP bar (always visible for commander, visible for others when damaged)
    const showBar = e.isCommander || e.hp < e.maxHp;
    tracked.hpBar.sprite.visible = showBar;
    if (showBar) {
      updateOverheadBar(tracked.hpBar, e.hp, e.maxHp, e.isCommander ? '#ef4444' : '#f87171');
    }

    // Enemy Commander Red Telegraph Disc
    if (e.telegraph && e.telegraph.remainingSec > 0) {
      const rWorld = Math.max(0.5, e.telegraph.radius * WORLD_SCALE);
      const progress = Math.max(
        0.04,
        Math.min(1, 1 - e.telegraph.remainingSec / Math.max(0.01, e.telegraph.totalSec))
      );

      if (!tracked.telegraphGroup) {
        const tg = new THREE.Group();
        const ring = new THREE.Mesh(
          new THREE.RingGeometry(0.92, 1.0, 36),
          new THREE.MeshBasicMaterial({
            color: 0xff2d2d,
            transparent: true,
            opacity: 0.92,
            side: THREE.DoubleSide,
            depthWrite: false,
          })
        );
        ring.rotation.x = -Math.PI / 2;
        tg.add(ring);

        const fill = new THREE.Mesh(
          new THREE.CircleGeometry(1.0, 36),
          new THREE.MeshBasicMaterial({
            color: 0xdc2626,
            transparent: true,
            opacity: 0.36,
            side: THREE.DoubleSide,
            depthWrite: false,
          })
        );
        fill.rotation.x = -Math.PI / 2;
        fill.position.y = 0.005;
        tg.add(fill);

        this.scene.add(tg);
        tracked.telegraphGroup = tg;
        tracked.telegraphRing = ring;
        tracked.telegraphFill = fill;
      }

      tracked.telegraphGroup.visible = true;
      tracked.telegraphGroup.position.set(
        toWorldX(e.telegraph.x),
        0.06,
        toWorldZ(e.telegraph.y)
      );
      tracked.telegraphRing!.scale.setScalar(rWorld);
      tracked.telegraphFill!.scale.setScalar(rWorld * progress);
    } else if (tracked.telegraphGroup) {
      tracked.telegraphGroup.visible = false;
    }
  }

  private removeEnemyVisual(tracked: TrackedEnemy): void {
    this.scene.remove(tracked.rig.root);
    disposeObject3D(tracked.rig.root);
    if (tracked.telegraphGroup) {
      this.scene.remove(tracked.telegraphGroup);
      disposeObject3D(tracked.telegraphGroup);
    }
  }

  private syncVolleys(snapshot: CombatSnapshot): void {
    const activeIds = new Set<string>();

    for (const v of snapshot.pendingVolleys) {
      activeIds.add(v.id);
      let vis = this.volleys.get(v.id);
      if (!vis) {
        const group = new THREE.Group();
        const ringMesh = new THREE.Mesh(
          new THREE.RingGeometry(0.9, 1.0, 32),
          new THREE.MeshBasicMaterial({
            color: 0x34d399,
            transparent: true,
            opacity: 0.85,
            side: THREE.DoubleSide,
            depthWrite: false,
          })
        );
        ringMesh.rotation.x = -Math.PI / 2;
        group.add(ringMesh);

        const fillMesh = new THREE.Mesh(
          new THREE.CircleGeometry(1.0, 32),
          new THREE.MeshBasicMaterial({
            color: 0xf59e0b,
            transparent: true,
            opacity: 0.28,
            side: THREE.DoubleSide,
            depthWrite: false,
          })
        );
        fillMesh.rotation.x = -Math.PI / 2;
        fillMesh.position.y = 0.005;
        group.add(fillMesh);

        this.scene.add(group);
        vis = { group, fillMesh, ringMesh };
        this.volleys.set(v.id, vis);
      }

      const rWorld = Math.max(0.5, v.radius * WORLD_SCALE);
      const progress = Math.max(0.05, Math.min(1, 1 - v.remainingSec / Math.max(0.01, v.totalSec)));
      vis.group.position.set(toWorldX(v.x), 0.06, toWorldZ(v.y));
      vis.ringMesh.scale.setScalar(rWorld);
      vis.fillMesh.scale.setScalar(rWorld * progress);
    }

    for (const [id, vis] of this.volleys.entries()) {
      if (!activeIds.has(id)) {
        this.scene.remove(vis.group);
        disposeObject3D(vis.group);
        this.volleys.delete(id);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Combat Event VFX
  // ---------------------------------------------------------------------------

  private handleCombatEvent(ev: CombatEvent): void {
    switch (ev.type) {
      case 'hero_slash':
        this.heroRig.swingPhase = 1;
        this.spawnSlashVfx(ev.x, ev.y, ev.angle, ev.radius, ev.arcRad, ev.comboStep);
        break;

      case 'hero_charge':
        this.spawnChargeTrail(ev.fromX, ev.fromY, ev.toX, ev.toY);
        break;

      case 'hero_warcry':
        this.spawnShockwave(ev.x, ev.y, ev.radius * WORLD_SCALE, 0xfbbf24, 0.55);
        this.spawnFloatingText(ev.x, ev.y, '戰意咆哮!', '#fde047', 34, 0.9);
        break;

      case 'commander_slam':
        this.spawnShockwave(ev.x, ev.y, ev.radius * WORLD_SCALE, 0xef4444, 0.65);
        this.shakeIntensity = Math.max(this.shakeIntensity, 0.65);
        this.spawnCubeBurst(ev.x, ev.y, 0xef4444, 14);
        break;

      case 'hero_dodge':
        this.spawnShockwave(ev.x, ev.y, 1.4, 0x38bdf8, 0.35);
        break;

      case 'hero_down':
        this.spawnCubeBurst(ev.x, ev.y, 0x38bdf8, 16);
        this.spawnFloatingText(ev.x, ev.y, '武將重傷!', '#f87171', 36, 1.1);
        break;

      case 'hero_respawn':
        this.spawnShockwave(ev.x, ev.y, 2.2, 0x38bdf8, 0.55);
        this.spawnFloatingText(ev.x, ev.y, '重返戰場!', '#7dd3fc', 34, 1.0);
        break;

      case 'regiment_command':
        this.spawnShockwave(ev.x, ev.y, 1.8, 0x38bdf8, 0.5);
        this.spawnFloatingText(ev.x, ev.y, ev.label, '#7dd3fc', 32, 0.95);
        break;

      case 'arrow_shot':
        this.spawnArrow(ev.fromX, ev.fromY, ev.toX, ev.toY, ev.isPlayerSide);
        break;

      case 'volley_impact':
        this.spawnVolleyImpact(ev.x, ev.y, ev.radius);
        break;

      case 'damage': {
        if (ev.blocked) {
          this.spawnFloatingText(ev.x, ev.y, `格擋 ${Math.round(ev.amount)}`, '#67e8f9', 26, 0.72);
        } else if (ev.isCrit) {
          this.spawnFloatingText(ev.x, ev.y, `${Math.round(ev.amount)}!`, '#facc15', 38, 0.85);
        } else if (ev.targetTeam === 'player') {
          this.spawnFloatingText(ev.x, ev.y, `-${Math.round(ev.amount)}`, '#f87171', 28, 0.72);
        } else {
          this.spawnFloatingText(ev.x, ev.y, `${Math.round(ev.amount)}`, '#f8fafc', 28, 0.72);
        }
        break;
      }

      case 'gate_hit':
        this.gateFlashSec = 0.28;
        this.shakeIntensity = Math.max(this.shakeIntensity, 0.45);
        this.spawnCubeBurst(ev.x, ev.y, 0xf97316, 10);
        this.spawnFloatingText(ev.x, ev.y, `城門 -${Math.round(ev.amount)}`, '#fb923c', 32, 0.85);
        break;

      case 'unit_died': {
        const color =
          ev.team === 'enemy' ? (ev.isCommander ? 0xf59e0b : 0xef4444) : 0x38bdf8;
        this.spawnCubeBurst(ev.x, ev.y, color, ev.isCommander ? 26 : 10);
        if (ev.isCommander) {
          this.shakeIntensity = Math.max(this.shakeIntensity, 0.7);
          this.spawnShockwave(ev.x, ev.y, 4.2, 0xf59e0b, 0.75);
        }
        break;
      }

      case 'combat_ended':
        break;
    }
  }

  private spawnSlashVfx(
    coreX: number,
    coreY: number,
    angle: number,
    radius: number,
    arcRad: number,
    comboStep: 0 | 1 | 2
  ): void {
    const rWorld = Math.max(1.2, radius * WORLD_SCALE);
    const innerR = rWorld * (comboStep === 2 ? 0.35 : 0.48);
    const geo = new THREE.RingGeometry(innerR, rWorld, 20, 1, -arcRad / 2, arcRad);
    const color = comboStep === 2 ? 0xfbbf24 : comboStep === 1 ? 0x7dd3fc : 0xe0f2fe;
    const mat = new THREE.MeshBasicMaterial({
      color,
      transparent: true,
      opacity: 0.88,
      side: THREE.DoubleSide,
      depthWrite: false,
    });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.rotation.x = -Math.PI / 2;
    mesh.rotation.z = -angle;
    mesh.position.set(toWorldX(coreX), 1.05, toWorldZ(coreY));
    this.scene.add(mesh);

    const startScale = 0.78;
    const endScale = comboStep === 2 ? 1.2 : 1.08;
    this.activeVfx.push({
      obj: mesh,
      age: 0,
      duration: comboStep === 2 ? 0.28 : 0.2,
      update: (t) => {
        const s = startScale + (endScale - startScale) * t;
        mesh.scale.setScalar(s);
        mat.opacity = 0.88 * (1 - t);
      },
    });
  }

  private spawnChargeTrail(fromX: number, fromY: number, toX: number, toY: number): void {
    const p1 = new THREE.Vector3(toWorldX(fromX), 0.75, toWorldZ(fromY));
    const p2 = new THREE.Vector3(toWorldX(toX), 0.75, toWorldZ(toY));
    const dist = Math.max(0.5, p1.distanceTo(p2));
    const mid = p1.clone().add(p2).multiplyScalar(0.5);
    const angle = Math.atan2(p2.z - p1.z, p2.x - p1.x);

    const mat = new THREE.MeshBasicMaterial({
      color: 0x38bdf8,
      transparent: true,
      opacity: 0.8,
      depthWrite: false,
    });
    const beam = new THREE.Mesh(new THREE.BoxGeometry(dist, 0.26, 0.85), mat);
    beam.position.copy(mid);
    beam.rotation.y = -angle;
    this.scene.add(beam);

    this.activeVfx.push({
      obj: beam,
      age: 0,
      duration: 0.35,
      update: (t) => {
        beam.scale.set(1, 1 - t * 0.6, 1 + t * 0.4);
        mat.opacity = 0.8 * (1 - t);
      },
    });
  }

  private spawnShockwave(
    coreX: number,
    coreY: number,
    targetRadiusWorld: number,
    color: number,
    duration: number
  ): void {
    const mat = new THREE.MeshBasicMaterial({
      color,
      transparent: true,
      opacity: 0.88,
      side: THREE.DoubleSide,
      depthWrite: false,
    });
    const ring = new THREE.Mesh(new THREE.RingGeometry(0.76, 1.0, 32), mat);
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(toWorldX(coreX), 0.1, toWorldZ(coreY));
    this.scene.add(ring);

    this.activeVfx.push({
      obj: ring,
      age: 0,
      duration,
      update: (t) => {
        const s = 0.25 + (targetRadiusWorld - 0.25) * (1 - (1 - t) * (1 - t));
        ring.scale.setScalar(s);
        mat.opacity = 0.88 * (1 - t);
      },
    });
  }

  private spawnArrow(
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    isPlayerSide: boolean
  ): void {
    const from = new THREE.Vector3(toWorldX(fromX), 1.35, toWorldZ(fromY));
    const to = new THREE.Vector3(toWorldX(toX), 0.8, toWorldZ(toY));
    const dist = from.distanceTo(to);
    const mat = new THREE.MeshBasicMaterial({
      color: isPlayerSide ? 0x6ee7b7 : 0xc084fc,
    });
    const mesh = new THREE.Mesh(this.sharedArrowGeo, mat);
    mesh.position.copy(from);
    this.scene.add(mesh);

    this.arrowVfx.push({
      mesh,
      from,
      to,
      peakY: Math.min(5.5, 1.5 + dist * 0.16),
      age: 0,
      duration: Math.max(0.18, Math.min(0.42, dist * 0.02)),
    });
  }

  private spawnVolleyImpact(coreX: number, coreY: number, radius: number): void {
    const rWorld = Math.max(1.2, radius * WORLD_SCALE);
    this.spawnShockwave(coreX, coreY, rWorld, 0x34d399, 0.48);

    const cx = toWorldX(coreX);
    const cz = toWorldZ(coreY);
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2 + Math.random() * 0.4;
      const d = Math.random() * rWorld * 0.85;
      const tx = cx + Math.cos(a) * d;
      const tz = cz + Math.sin(a) * d;
      const from = new THREE.Vector3(tx - 1.4, 7.5 + Math.random() * 2.5, tz - 0.8);
      const to = new THREE.Vector3(tx, 0.1, tz);
      const mat = new THREE.MeshBasicMaterial({ color: 0xfde047 });
      const mesh = new THREE.Mesh(this.sharedArrowGeo, mat);
      mesh.position.copy(from);
      this.scene.add(mesh);

      this.arrowVfx.push({
        mesh,
        from,
        to,
        peakY: from.y + 0.5,
        age: 0,
        duration: 0.2 + Math.random() * 0.12,
      });
    }
  }

  private spawnCubeBurst(coreX: number, coreY: number, color: number, count: number): void {
    const cx = toWorldX(coreX);
    const cz = toWorldZ(coreY);

    for (let i = 0; i < count; i++) {
      const mat = new THREE.MeshStandardMaterial({
        color,
        emissive: color,
        emissiveIntensity: 0.35,
        roughness: 0.5,
      });
      const mesh = new THREE.Mesh(this.sharedCubeGeo, mat);
      mesh.position.set(
        cx + (Math.random() - 0.5) * 0.6,
        0.7 + Math.random() * 0.7,
        cz + (Math.random() - 0.5) * 0.6
      );
      const speed = 2.2 + Math.random() * 4.0;
      const ang = Math.random() * Math.PI * 2;
      this.scene.add(mesh);

      this.particles.push({
        mesh,
        vel: new THREE.Vector3(Math.cos(ang) * speed, 3.8 + Math.random() * 3.8, Math.sin(ang) * speed),
        rotVel: new THREE.Vector3(
          (Math.random() - 0.5) * 10,
          (Math.random() - 0.5) * 10,
          (Math.random() - 0.5) * 10
        ),
        age: 0,
        duration: 0.65 + Math.random() * 0.35,
      });
    }
  }

  private spawnFloatingText(
    coreX: number,
    coreY: number,
    text: string,
    color: string,
    fontSize: number,
    duration: number
  ): void {
    const sprite = createTextSprite(text, color, fontSize);
    sprite.position.set(
      toWorldX(coreX) + (Math.random() - 0.5) * 0.6,
      2.35 + Math.random() * 0.35,
      toWorldZ(coreY) + (Math.random() - 0.5) * 0.4
    );
    this.scene.add(sprite);
    this.floatingSprites.push({
      sprite,
      age: 0,
      duration,
      riseSpeed: 2.2,
    });
  }

  // ---------------------------------------------------------------------------
  // Pointer Raycasting & Resize
  // ---------------------------------------------------------------------------

  private updatePointerNdcFromEvent(e: PointerEvent): void {
    const rect = this.renderer.domElement.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    this.pointerNdc.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
    this.pointerNdc.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
  }

  private updateRaycastFromNdc(): void {
    this.raycaster.setFromCamera(this.pointerNdc, this.camera);
    const hit = new THREE.Vector3();
    if (this.raycaster.ray.intersectPlane(this.groundPlane, hit)) {
      const cx = toCoreX(hit.x);
      const cy = toCoreY(hit.z);
      this.pointerState.x = cx;
      this.pointerState.y = cy;
      this.crosshairGroup.position.set(toWorldX(cx), 0.09, toWorldZ(cy));
    }
  }

  private handlePointerMove(e: PointerEvent): void {
    this.pointerInside = true;
    this.updatePointerNdcFromEvent(e);
    this.updateRaycastFromNdc();
  }

  private handlePointerDown(e: PointerEvent): void {
    this.pointerInside = true;
    this.updatePointerNdcFromEvent(e);
    this.updateRaycastFromNdc();
    if (e.button === 0) this.pointerState.leftDown = true;
    if (e.button === 2) this.pointerState.rightDown = true;
  }

  private handlePointerUp(e: PointerEvent): void {
    if (e.button === 0) this.pointerState.leftDown = false;
    if (e.button === 2) this.pointerState.rightDown = false;
  }

  private handlePointerLeave(): void {
    this.pointerInside = false;
    this.pointerState.leftDown = false;
    this.pointerState.rightDown = false;
  }

  private handleResize(): void {
    if (this.destroyed) return;
    const width = Math.max(1, this.container.clientWidth);
    const height = Math.max(1, this.container.clientHeight);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
  }

  // ---------------------------------------------------------------------------
  // Animation Loop
  // ---------------------------------------------------------------------------

  private loop = (nowMs: number): void => {
    if (this.destroyed) return;
    this.rafId = requestAnimationFrame(this.loop);

    const dt = Math.min(0.05, Math.max(0.001, (nowMs - this.lastFrameMs) / 1000));
    this.lastFrameMs = nowMs;
    this.elapsedTime += dt;

    this.updateCamera(dt);
    if (this.pointerInside) {
      this.updateRaycastFromNdc();
    }
    this.updateEnvironmentAnimations(dt);
    this.updateRigAnimations(dt);
    this.updateVfx(dt);

    this.renderer.render(this.scene, this.camera);
  };

  private updateCamera(dt: number): void {
    const heroX = this.latestSnapshot ? toWorldX(this.latestSnapshot.hero.x) : -12;
    const heroZ = this.latestSnapshot ? toWorldZ(this.latestSnapshot.hero.y) : 0;

    const targetPos = new THREE.Vector3();
    const targetLook = new THREE.Vector3();

    if (this.cameraMode === 'tactical') {
      const trackX = heroX * 0.45 + 2.0;
      const trackZ = heroZ * 0.35;
      targetPos.set(trackX, 25, trackZ + 20);
      targetLook.set(trackX, 0, trackZ);
    } else {
      // Conqueror's Blade over-the-shoulder 3rd-person view aligned straight along +X
      const aimWorldX = toWorldX(this.pointerState.x);
      const aimWorldZ = toWorldZ(this.pointerState.y);
      const aimBiasX = Math.max(-2.0, Math.min(4.0, (aimWorldX - heroX) * 0.16));
      const aimBiasZ = Math.max(-1.6, Math.min(1.6, (aimWorldZ - heroZ) * 0.12));

      // Keep TPS camera safely in front of the castle wall & watchtowers
      const gateWorldX = toWorldX(this.builtGateX);
      const minCamX = gateWorldX + 2.0;
      const desiredCamX = heroX - 10.5;
      const camX = Math.max(minCamX, desiredCamX);
      const wallSqueeze = Math.max(0, minCamX - desiredCamX);
      const camY = 6.2 + Math.min(4.0, wallSqueeze * 0.4);
      const camZ = heroZ + 1.5 + Math.min(0.6, wallSqueeze * 0.06);

      targetPos.set(camX, camY, camZ);
      targetLook.set(heroX + 8.5 + aimBiasX, 1.25, heroZ + 0.6 + aimBiasZ);
    }

    const damp = 1 - Math.exp(-6.5 * dt);
    this.currentCamPos.lerp(targetPos, damp);
    this.currentCamLook.lerp(targetLook, damp);

    // Camera micro-shake on gate hit / commander slam
    let sx = 0;
    let sy = 0;
    if (this.shakeIntensity > 0.005) {
      sx = (Math.random() - 0.5) * this.shakeIntensity;
      sy = (Math.random() - 0.5) * this.shakeIntensity;
      this.shakeIntensity = Math.max(0, this.shakeIntensity - dt * 2.4);
    }

    this.camera.position.set(
      this.currentCamPos.x + sx,
      this.currentCamPos.y + sy,
      this.currentCamPos.z
    );
    this.camera.lookAt(this.currentCamLook);
  }

  private updateEnvironmentAnimations(dt: number): void {
    // Flickering gatehouse torches
    for (let i = 0; i < this.torchLights.length; i++) {
      const flicker = Math.sin(this.elapsedTime * 15 + i * 2.3) * 2.5 +
        Math.cos(this.elapsedTime * 27 + i) * 1.4;
      this.torchLights[i].intensity = 17 + flicker;
      const flame = this.torchFlames[i];
      if (flame) {
        const s = 0.92 + Math.sin(this.elapsedTime * 19 + i) * 0.14;
        flame.scale.set(s, 0.9 + Math.cos(this.elapsedTime * 23 + i) * 0.2, s);
      }
    }

    // Gate hit red flash decay
    if (this.gateFlashSec > 0) {
      this.gateFlashSec = Math.max(0, this.gateFlashSec - dt);
      const t = this.gateFlashSec / 0.28;
      this.gateWoodMat.emissive.setHex(0xdc2626);
      this.gateWoodMat.emissiveIntensity = t * 1.3;
    } else if (this.gateWoodMat.emissiveIntensity > 0) {
      this.gateWoodMat.emissiveIntensity = 0;
    }

    // Crosshair rotation
    this.crosshairOuterRing.rotation.z = this.elapsedTime * 1.4;

    // Regiment hold banner flutter
    if (this.bannerRig.root.visible) {
      this.bannerRig.clothMesh.rotation.y = Math.sin(this.elapsedTime * 5.2) * 0.26;
      const pulse = 1 + Math.sin(this.elapsedTime * 4) * 0.08;
      this.bannerRig.ringMesh.scale.setScalar(pulse);
    }
  }

  private updateRigAnimations(dt: number): void {
    // Hero weapon swing animation
    if (this.heroRig.swingPhase > 0) {
      this.heroRig.swingPhase = Math.max(0, this.heroRig.swingPhase - dt * 5.2);
      const s = Math.sin(this.heroRig.swingPhase * Math.PI);
      this.heroRig.weaponPivot.rotation.y = s * 1.35;
      this.heroRig.weaponPivot.rotation.z = -s * 0.35;
    } else {
      this.heroRig.weaponPivot.rotation.y = 0;
      this.heroRig.weaponPivot.rotation.z = 0;
    }

    // Soldier weapon swings
    for (const tracked of this.soldiers.values()) {
      if (tracked.rig.swingPhase > 0) {
        tracked.rig.swingPhase = Math.max(0, tracked.rig.swingPhase - dt * 4.5);
        const s = Math.sin(tracked.rig.swingPhase * Math.PI);
        tracked.rig.weaponPivot.rotation.y = s * 0.85;
      } else {
        tracked.rig.weaponPivot.rotation.y = 0;
      }
    }
  }

  private updateVfx(dt: number): void {
    // 1. Generic timed VFX (slashes, shockwaves, charge trails)
    for (let i = this.activeVfx.length - 1; i >= 0; i--) {
      const fx = this.activeVfx[i];
      fx.age += dt;
      const t = Math.min(1, fx.age / fx.duration);
      fx.update(t, dt);
      if (fx.age >= fx.duration) {
        this.scene.remove(fx.obj);
        disposeObject3D(fx.obj);
        this.activeVfx.splice(i, 1);
      }
    }

    // 2. Parabolic arrows
    for (let i = this.arrowVfx.length - 1; i >= 0; i--) {
      const a = this.arrowVfx[i];
      a.age += dt;
      const t = Math.min(1, a.age / a.duration);
      const nextT = Math.min(1, t + 0.05);

      const pos = new THREE.Vector3().lerpVectors(a.from, a.to, t);
      pos.y += Math.sin(t * Math.PI) * a.peakY;

      const nextPos = new THREE.Vector3().lerpVectors(a.from, a.to, nextT);
      nextPos.y += Math.sin(nextT * Math.PI) * a.peakY;

      a.mesh.position.copy(pos);
      if (nextT > t) {
        a.mesh.lookAt(nextPos);
      }

      if (a.age >= a.duration) {
        this.scene.remove(a.mesh);
        (a.mesh.material as THREE.Material).dispose();
        this.arrowVfx.splice(i, 1);
      }
    }

    // 3. Death / impact cube particles with gravity
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.age += dt;
      p.vel.y -= 14.5 * dt;
      p.mesh.position.addScaledVector(p.vel, dt);
      if (p.mesh.position.y < 0.1) {
        p.mesh.position.y = 0.1;
        p.vel.y *= -0.35;
        p.vel.x *= 0.7;
        p.vel.z *= 0.7;
      }
      p.mesh.rotation.x += p.rotVel.x * dt;
      p.mesh.rotation.y += p.rotVel.y * dt;
      p.mesh.rotation.z += p.rotVel.z * dt;
      const s = Math.max(0.01, 1 - p.age / p.duration);
      p.mesh.scale.setScalar(s);

      if (p.age >= p.duration) {
        this.scene.remove(p.mesh);
        (p.mesh.material as THREE.Material).dispose();
        this.particles.splice(i, 1);
      }
    }

    // 4. Floating damage / command sprites
    for (let i = this.floatingSprites.length - 1; i >= 0; i--) {
      const fs = this.floatingSprites[i];
      fs.age += dt;
      const t = Math.min(1, fs.age / fs.duration);
      fs.sprite.position.y += fs.riseSpeed * dt;
      fs.sprite.material.opacity = t < 0.65 ? 1 : (1 - t) / 0.35;

      if (fs.age >= fs.duration) {
        this.scene.remove(fs.sprite);
        disposeObject3D(fs.sprite);
        this.floatingSprites.splice(i, 1);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Memory-Safe Teardown
  // ---------------------------------------------------------------------------

  public destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;

    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }

    this.resizeObserver.disconnect();

    const canvas = this.renderer.domElement;
    canvas.removeEventListener('pointermove', this.onPointerMoveBound);
    canvas.removeEventListener('pointerdown', this.onPointerDownBound);
    window.removeEventListener('pointerup', this.onPointerUpBound);
    canvas.removeEventListener('pointerleave', this.onPointerLeaveBound);
    canvas.removeEventListener('contextmenu', this.onContextMenuBound);

    this.sharedCubeGeo.dispose();
    this.sharedArrowGeo.dispose();

    disposeObject3D(this.scene);
    this.scene.clear();

    this.soldiers.clear();
    this.enemies.clear();
    this.volleys.clear();
    this.activeVfx = [];
    this.arrowVfx = [];
    this.particles = [];
    this.floatingSprites = [];

    this.renderer.dispose();
    if (canvas.parentElement === this.container) {
      this.container.removeChild(canvas);
    }
  }
}
