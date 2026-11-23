import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import type { EnemyUnitType, RegimentType } from '../core/types/combat';

export interface CharacterRig {
  root: THREE.Group;
  bodyGroup: THREE.Group;
  weaponPivot: THREE.Group;
  offhandPivot?: THREE.Group;
  shieldMaterial?: THREE.MeshStandardMaterial;
  auraRing?: THREE.Mesh;
  dodgeShell?: THREE.Mesh;
  capeMesh?: THREE.Mesh;
  baseScale: number;
  baseHeight: number;
  swingPhase: number;
}

export interface BannerRig {
  root: THREE.Group;
  clothMesh: THREE.Mesh;
  ringMesh: THREE.Mesh;
}

// Optional future .glb / .vrm model registry (non-blocking fallback to procedural Low-Poly)
const customModelUrls = new Map<string, string>();
const loadedModelCache = new Map<string, THREE.Group>();
const loadingPromises = new Map<string, Promise<THREE.Group | null>>();
let sharedGltfLoader: GLTFLoader | null = null;

export function registerCustomModelUrl(key: string, glbUrl: string): void {
  customModelUrls.set(key, glbUrl);
  loadedModelCache.delete(key);
  loadingPromises.delete(key);
}

export function clearCustomModelUrls(): void {
  customModelUrls.clear();
  loadedModelCache.clear();
  loadingPromises.clear();
}

function getGltfLoader(): GLTFLoader {
  if (!sharedGltfLoader) {
    sharedGltfLoader = new GLTFLoader();
  }
  return sharedGltfLoader;
}

function enableShadows(obj: THREE.Object3D): void {
  obj.traverse((child) => {
    if (child instanceof THREE.Mesh) {
      child.castShadow = true;
      child.receiveShadow = true;
    }
  });
}

/**
 * Non-blocking hook: if a custom .glb URL is registered for `key`, loads it and swaps
 * the procedural body meshes inside `rig.bodyGroup`. Falls back seamlessly to procedural mesh.
 */
export function tryAttachCustomModel(
  key: string,
  rig: CharacterRig,
  scale = 1
): void {
  const url = customModelUrls.get(key);
  if (!url) return;

  const applyModel = (template: THREE.Group) => {
    // Guard if rig was already removed/disposed
    if (!rig.bodyGroup) return;
    while (rig.bodyGroup.children.length > 0) {
      const child = rig.bodyGroup.children[0];
      rig.bodyGroup.remove(child);
    }
    const clone = template.clone(true);
    clone.scale.setScalar(scale);
    enableShadows(clone);
    rig.bodyGroup.add(clone);
  };

  const cached = loadedModelCache.get(key);
  if (cached) {
    applyModel(cached);
    return;
  }

  let promise = loadingPromises.get(key);
  if (!promise) {
    promise = new Promise<THREE.Group | null>((resolve) => {
      getGltfLoader().load(
        url,
        (gltf) => {
          loadedModelCache.set(key, gltf.scene);
          resolve(gltf.scene);
        },
        undefined,
        () => {
          resolve(null);
        }
      );
    });
    loadingPromises.set(key, promise);
  }

  void promise.then((scene) => {
    if (scene) {
      applyModel(scene);
    }
  });
}

function makeMat(
  color: number,
  options?: {
    roughness?: number;
    metalness?: number;
    emissive?: number;
    emissiveIntensity?: number;
    transparent?: boolean;
    opacity?: number;
    side?: THREE.Side;
    flatShading?: boolean;
  }
): THREE.MeshStandardMaterial {
  return new THREE.MeshStandardMaterial({
    color,
    roughness: options?.roughness ?? 0.65,
    metalness: options?.metalness ?? 0.2,
    emissive: options?.emissive ?? 0x000000,
    emissiveIntensity: options?.emissiveIntensity ?? 0,
    transparent: options?.transparent ?? false,
    opacity: options?.opacity ?? 1,
    side: options?.side ?? THREE.FrontSide,
    flatShading: options?.flatShading ?? true,
  });
}

function addBox(
  parent: THREE.Object3D,
  w: number,
  h: number,
  d: number,
  mat: THREE.Material,
  x: number,
  y: number,
  z: number,
  rx = 0,
  ry = 0,
  rz = 0
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  mesh.position.set(x, y, z);
  mesh.rotation.set(rx, ry, rz);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addCylinder(
  parent: THREE.Object3D,
  rt: number,
  rb: number,
  h: number,
  seg: number,
  mat: THREE.Material,
  x: number,
  y: number,
  z: number,
  rx = 0,
  ry = 0,
  rz = 0
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
  mesh.position.set(x, y, z);
  mesh.rotation.set(rx, ry, rz);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addCone(
  parent: THREE.Object3D,
  r: number,
  h: number,
  seg: number,
  mat: THREE.Material,
  x: number,
  y: number,
  z: number,
  rx = 0,
  ry = 0,
  rz = 0
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.ConeGeometry(r, h, seg), mat);
  mesh.position.set(x, y, z);
  mesh.rotation.set(rx, ry, rz);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

/**
 * Hero (艾莉絲) — Armored Valkyrie Knight
 * Local forward: +X, Right arm (weapon): +Z, Left arm (shield): -Z, Cape: -X
 */
export function createHeroRig(): CharacterRig {
  const root = new THREE.Group();
  const bodyGroup = new THREE.Group();
  root.add(bodyGroup);

  const silverArmor = makeMat(0xcbd5e1, { metalness: 0.72, roughness: 0.28 });
  const cyanTrim = makeMat(0x38bdf8, {
    metalness: 0.55,
    roughness: 0.3,
    emissive: 0x0ea5e9,
    emissiveIntensity: 0.35,
  });
  const goldTrim = makeMat(0xfbbf24, {
    metalness: 0.8,
    roughness: 0.25,
    emissive: 0xd97706,
    emissiveIntensity: 0.22,
  });
  const darkUnder = makeMat(0x1e293b, { roughness: 0.75, metalness: 0.15 });
  const capeMat = makeMat(0xb91c1c, {
    roughness: 0.6,
    metalness: 0.1,
    side: THREE.DoubleSide,
  });
  const skinMat = makeMat(0xfde2c8, { roughness: 0.7, metalness: 0.05 });

  // Greaves / Legs
  addBox(bodyGroup, 0.22, 0.58, 0.22, darkUnder, 0, 0.29, -0.17);
  addBox(bodyGroup, 0.22, 0.58, 0.22, darkUnder, 0, 0.29, 0.17);
  addBox(bodyGroup, 0.25, 0.28, 0.25, silverArmor, 0.02, 0.22, -0.17);
  addBox(bodyGroup, 0.25, 0.28, 0.25, silverArmor, 0.02, 0.22, 0.17);

  // Armored skirt / waist
  addCylinder(bodyGroup, 0.32, 0.42, 0.34, 6, cyanTrim, 0, 0.68, 0);
  addBox(bodyGroup, 0.5, 0.12, 0.56, goldTrim, 0, 0.84, 0);

  // Breastplate torso
  addBox(bodyGroup, 0.48, 0.62, 0.62, silverArmor, 0, 1.18, 0);
  // Glowing cyan chest core
  addBox(bodyGroup, 0.52, 0.24, 0.26, cyanTrim, 0.04, 1.24, 0);
  // Pauldrons (shoulders)
  addBox(bodyGroup, 0.36, 0.26, 0.3, silverArmor, 0, 1.44, -0.42, 0.2, 0, 0);
  addBox(bodyGroup, 0.36, 0.26, 0.3, silverArmor, 0, 1.44, 0.42, -0.2, 0, 0);
  addBox(bodyGroup, 0.38, 0.08, 0.32, goldTrim, 0, 1.56, -0.42, 0.2, 0, 0);
  addBox(bodyGroup, 0.38, 0.08, 0.32, goldTrim, 0, 1.56, 0.42, -0.2, 0, 0);

  // Head + Valkyrie Winged Helm
  addBox(bodyGroup, 0.38, 0.38, 0.38, skinMat, 0.02, 1.72, 0);
  addBox(bodyGroup, 0.42, 0.22, 0.44, silverArmor, 0, 1.84, 0);
  // Helm visor crest
  addBox(bodyGroup, 0.46, 0.1, 0.1, goldTrim, 0.05, 1.96, 0);
  // Valkyrie golden wings on left & right of helm
  addBox(bodyGroup, 0.34, 0.24, 0.06, goldTrim, -0.06, 1.98, -0.27, 0.35, 0.25, 0.35);
  addBox(bodyGroup, 0.34, 0.24, 0.06, goldTrim, -0.06, 1.98, 0.27, -0.35, -0.25, 0.35);

  // Flowing crimson-gold cape on back (-X)
  const capeGeo = new THREE.BoxGeometry(0.08, 1.12, 0.62);
  const capeMesh = new THREE.Mesh(capeGeo, capeMat);
  capeMesh.position.set(-0.36, 0.98, 0);
  capeMesh.rotation.z = -0.22;
  capeMesh.castShadow = true;
  bodyGroup.add(capeMesh);
  addBox(capeMesh, 0.1, 0.1, 0.64, goldTrim, 0, -0.52, 0);

  // Right arm weapon pivot (+Z): radiant valkyrie greatsword / spear
  const weaponPivot = new THREE.Group();
  weaponPivot.position.set(0.14, 1.18, 0.45);
  bodyGroup.add(weaponPivot);

  addBox(weaponPivot, 0.26, 0.14, 0.14, silverArmor, 0.08, 0, 0);
  // Hilt + crossguard
  addCylinder(weaponPivot, 0.045, 0.045, 0.42, 6, goldTrim, 0.24, 0, 0, 0, 0, Math.PI / 2);
  addBox(weaponPivot, 0.08, 0.08, 0.42, goldTrim, 0.42, 0, 0);
  // Long gleaming blade pointing forward (+X)
  const bladeMat = makeMat(0xe0f2fe, {
    metalness: 0.88,
    roughness: 0.15,
    emissive: 0x38bdf8,
    emissiveIntensity: 0.45,
  });
  addBox(weaponPivot, 1.28, 0.06, 0.16, bladeMat, 1.08, 0, 0);
  addCone(weaponPivot, 0.11, 0.32, 4, bladeMat, 1.85, 0, 0, 0, 0, -Math.PI / 2);

  // Left arm offhand pivot (-Z): Valkyrie Heater Shield
  const offhandPivot = new THREE.Group();
  offhandPivot.position.set(0.24, 1.14, -0.46);
  bodyGroup.add(offhandPivot);

  const shieldMat = makeMat(0x1d4ed8, {
    metalness: 0.55,
    roughness: 0.3,
    emissive: 0x0ea5e9,
    emissiveIntensity: 0.2,
  });
  addBox(offhandPivot, 0.12, 0.78, 0.56, shieldMat, 0.12, 0, 0, 0, 0.28, 0);
  addBox(offhandPivot, 0.14, 0.84, 0.08, goldTrim, 0.14, 0, 0, 0, 0.28, 0);
  addBox(offhandPivot, 0.14, 0.1, 0.6, goldTrim, 0.14, 0.1, 0, 0, 0.28, 0);

  // Directional ground ring + forward chevron
  const dirRingMat = new THREE.MeshBasicMaterial({
    color: 0x38bdf8,
    transparent: true,
    opacity: 0.55,
    side: THREE.DoubleSide,
    depthWrite: false,
  });
  const dirRing = new THREE.Mesh(new THREE.RingGeometry(0.82, 0.96, 28), dirRingMat);
  dirRing.rotation.x = -Math.PI / 2;
  dirRing.position.y = 0.05;
  root.add(dirRing);

  const arrowMesh = new THREE.Mesh(
    new THREE.ConeGeometry(0.22, 0.42, 3),
    new THREE.MeshBasicMaterial({ color: 0x7dd3fc })
  );
  arrowMesh.rotation.z = -Math.PI / 2;
  arrowMesh.position.set(1.18, 0.07, 0);
  root.add(arrowMesh);

  // Golden pulsing Warcry aura ring (hidden until warcryRemainingSec > 0)
  const auraMat = new THREE.MeshBasicMaterial({
    color: 0xfbbf24,
    transparent: true,
    opacity: 0.72,
    side: THREE.DoubleSide,
    depthWrite: false,
  });
  const auraRing = new THREE.Mesh(new THREE.RingGeometry(1.1, 1.42, 32), auraMat);
  auraRing.rotation.x = -Math.PI / 2;
  auraRing.position.y = 0.07;
  auraRing.visible = false;
  root.add(auraRing);

  // Translucent cyan dodge/invulnerable shell
  const dodgeMat = new THREE.MeshBasicMaterial({
    color: 0x38bdf8,
    transparent: true,
    opacity: 0.34,
    wireframe: false,
    depthWrite: false,
  });
  const dodgeShell = new THREE.Mesh(new THREE.SphereGeometry(1.15, 14, 12), dodgeMat);
  dodgeShell.position.y = 1.05;
  dodgeShell.visible = false;
  root.add(dodgeShell);

  const rig: CharacterRig = {
    root,
    bodyGroup,
    weaponPivot,
    offhandPivot,
    shieldMaterial: shieldMat,
    auraRing,
    dodgeShell,
    capeMesh,
    baseScale: 1,
    baseHeight: 2.3,
    swingPhase: 0,
  };

  tryAttachCustomModel('hero', rig, 1);
  return rig;
}

/**
 * Regiment Soldiers (shieldmen / pikemen / archers)
 */
export function createSoldierRig(type: RegimentType): CharacterRig {
  const root = new THREE.Group();
  const bodyGroup = new THREE.Group();
  root.add(bodyGroup);

  const darkBoot = makeMat(0x1e293b, { roughness: 0.8 });
  const skinMat = makeMat(0xf5d0b5, { roughness: 0.75 });
  const steelMat = makeMat(0x94a3b8, { metalness: 0.68, roughness: 0.32 });

  // Legs
  addBox(bodyGroup, 0.16, 0.44, 0.16, darkBoot, 0, 0.22, -0.12);
  addBox(bodyGroup, 0.16, 0.44, 0.16, darkBoot, 0, 0.22, 0.12);

  const weaponPivot = new THREE.Group();
  weaponPivot.position.set(0.12, 0.92, 0.32);
  bodyGroup.add(weaponPivot);

  let shieldMaterial: THREE.MeshStandardMaterial | undefined;

  if (type === 'shieldmen') {
    const armorMat = makeMat(0x2563eb, { metalness: 0.5, roughness: 0.35 });
    const trimMat = makeMat(0x93c5fd, { metalness: 0.65, roughness: 0.28 });

    // Torso & heavy helm
    addBox(bodyGroup, 0.38, 0.54, 0.48, armorMat, 0, 0.76, 0);
    addBox(bodyGroup, 0.3, 0.3, 0.3, skinMat, 0.02, 1.2, 0);
    addBox(bodyGroup, 0.34, 0.22, 0.34, steelMat, 0, 1.3, 0);
    addBox(bodyGroup, 0.14, 0.14, 0.12, trimMat, 0, 1.44, 0);

    // Short gladius on right (+Z)
    addBox(weaponPivot, 0.7, 0.06, 0.1, steelMat, 0.38, 0, 0);

    // Raised 3D Kite Shield on left/front (-Z)
    shieldMaterial = makeMat(0x1d4ed8, {
      metalness: 0.55,
      roughness: 0.3,
      emissive: 0x06b6d4,
      emissiveIntensity: 0.1,
    });
    const shieldGroup = new THREE.Group();
    shieldGroup.position.set(0.32, 0.78, -0.22);
    bodyGroup.add(shieldGroup);
    addBox(shieldGroup, 0.12, 0.88, 0.64, shieldMaterial, 0, 0, 0, 0, 0.18, 0);
    addBox(shieldGroup, 0.14, 0.92, 0.08, trimMat, 0.01, 0, 0, 0, 0.18, 0);
    addBox(shieldGroup, 0.14, 0.08, 0.68, trimMat, 0.01, 0.1, 0, 0, 0.18, 0);
  } else if (type === 'pikemen') {
    const tunicMat = makeMat(0x0d9488, { metalness: 0.35, roughness: 0.48 });
    const shaftMat = makeMat(0x78350f, { roughness: 0.85, metalness: 0.05 });

    addBox(bodyGroup, 0.36, 0.52, 0.44, tunicMat, 0, 0.75, 0);
    addBox(bodyGroup, 0.38, 0.22, 0.46, steelMat, 0, 0.88, 0);
    addBox(bodyGroup, 0.28, 0.28, 0.28, skinMat, 0.02, 1.18, 0);
    addCone(bodyGroup, 0.26, 0.22, 6, steelMat, 0, 1.38, 0);

    // Long angled 3D pike on right (+Z)
    addCylinder(weaponPivot, 0.035, 0.04, 2.35, 6, shaftMat, 0.95, 0.06, 0, 0, 0, Math.PI / 2 - 0.1);
    const tipMat = makeMat(0xe2e8f0, {
      metalness: 0.85,
      roughness: 0.18,
      emissive: 0x2dd4bf,
      emissiveIntensity: 0.25,
    });
    addCone(weaponPivot, 0.09, 0.42, 4, tipMat, 2.26, 0.2, 0, 0, 0, -Math.PI / 2 + 0.1);
  } else {
    // archers
    const cloakMat = makeMat(0x059669, { roughness: 0.65, metalness: 0.1 });
    const hoodMat = makeMat(0x047857, { roughness: 0.7 });
    const woodMat = makeMat(0x92400e, { roughness: 0.8 });

    addBox(bodyGroup, 0.34, 0.52, 0.4, cloakMat, 0, 0.74, 0);
    addBox(bodyGroup, 0.26, 0.26, 0.26, skinMat, 0.04, 1.16, 0);
    addCone(bodyGroup, 0.24, 0.32, 6, hoodMat, -0.02, 1.32, 0, 0, 0, 0.2);
    // Quiver on back
    addCylinder(bodyGroup, 0.08, 0.07, 0.45, 6, woodMat, -0.24, 0.92, -0.08, 0.25, 0, -0.2);

    // Curved 3D bow held forward
    const bowGroup = new THREE.Group();
    bowGroup.position.set(0.32, 0.94, -0.14);
    bodyGroup.add(bowGroup);
    const bowArc = new THREE.Mesh(
      new THREE.TorusGeometry(0.42, 0.04, 6, 12, Math.PI * 0.95),
      woodMat
    );
    bowArc.rotation.z = -Math.PI * 0.475;
    bowArc.castShadow = true;
    bowGroup.add(bowArc);

    const stringMat = new THREE.MeshBasicMaterial({ color: 0xd1fae5 });
    const bowString = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.8, 0.02), stringMat);
    bowString.position.set(-0.04, 0, 0);
    bowGroup.add(bowString);
  }

  // Subtle ally base ring
  const baseRing = new THREE.Mesh(
    new THREE.RingGeometry(0.46, 0.56, 20),
    new THREE.MeshBasicMaterial({
      color: type === 'shieldmen' ? 0x38bdf8 : type === 'pikemen' ? 0x2dd4bf : 0x34d399,
      transparent: true,
      opacity: 0.42,
      side: THREE.DoubleSide,
      depthWrite: false,
    })
  );
  baseRing.rotation.x = -Math.PI / 2;
  baseRing.position.y = 0.04;
  root.add(baseRing);

  const rig: CharacterRig = {
    root,
    bodyGroup,
    weaponPivot,
    shieldMaterial,
    baseScale: 1,
    baseHeight: 1.75,
    swingPhase: 0,
  };

  tryAttachCustomModel(`soldier_${type}`, rig, 1);
  return rig;
}

/**
 * Enemies (goblin_raider, shield_orc, skeleton_archer, berserker, enemy_commander)
 */
export function createEnemyRig(type: EnemyUnitType): CharacterRig {
  const root = new THREE.Group();
  const bodyGroup = new THREE.Group();
  root.add(bodyGroup);

  const weaponPivot = new THREE.Group();
  let baseScale = 1;
  let baseHeight = 1.75;

  if (type === 'goblin_raider') {
    const skin = makeMat(0x4d7c0f, { roughness: 0.72 });
    const leather = makeMat(0x451a03, { roughness: 0.85 });
    const blade = makeMat(0x94a3b8, { metalness: 0.7, roughness: 0.35 });

    // Crouched goblin body
    addBox(bodyGroup, 0.14, 0.32, 0.14, skin, 0, 0.16, -0.1);
    addBox(bodyGroup, 0.14, 0.32, 0.14, skin, 0, 0.16, 0.1);
    addBox(bodyGroup, 0.32, 0.38, 0.34, leather, 0.04, 0.5, 0, 0, 0, -0.2);
    addBox(bodyGroup, 0.28, 0.26, 0.28, skin, 0.12, 0.82, 0);
    // Pointy ears
    addCone(bodyGroup, 0.07, 0.24, 4, skin, 0.08, 0.86, -0.22, -1.1, 0, 0);
    addCone(bodyGroup, 0.07, 0.24, 4, skin, 0.08, 0.86, 0.22, 1.1, 0, 0);
    // Glowing yellow eyes
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0xfacc15 });
    addBox(bodyGroup, 0.04, 0.05, 0.06, eyeMat, 0.26, 0.85, -0.07);
    addBox(bodyGroup, 0.04, 0.05, 0.06, eyeMat, 0.26, 0.85, 0.07);

    weaponPivot.position.set(0.16, 0.54, 0.24);
    bodyGroup.add(weaponPivot);
    addBox(weaponPivot, 0.52, 0.06, 0.09, blade, 0.28, 0, 0);
    baseHeight = 1.25;
  } else if (type === 'shield_orc') {
    const skin = makeMat(0x991b1b, { roughness: 0.65 });
    const iron = makeMat(0x334155, { metalness: 0.7, roughness: 0.4 });
    const rim = makeMat(0x64748b, { metalness: 0.75, roughness: 0.35 });

    addBox(bodyGroup, 0.22, 0.46, 0.22, iron, 0, 0.23, -0.18);
    addBox(bodyGroup, 0.22, 0.46, 0.22, iron, 0, 0.23, 0.18);
    addBox(bodyGroup, 0.52, 0.66, 0.64, skin, 0, 0.8, 0);
    addBox(bodyGroup, 0.54, 0.26, 0.66, iron, 0, 0.88, 0);
    addBox(bodyGroup, 0.36, 0.34, 0.36, skin, 0.06, 1.32, 0);
    addBox(bodyGroup, 0.38, 0.14, 0.4, iron, 0.04, 1.48, 0);

    // Brutal iron cleaver on right (+Z)
    weaponPivot.position.set(0.16, 0.94, 0.44);
    bodyGroup.add(weaponPivot);
    addBox(weaponPivot, 0.85, 0.18, 0.08, rim, 0.46, 0, 0);

    // Bulky iron shield on left/front (-Z)
    addBox(bodyGroup, 0.16, 1.05, 0.74, iron, 0.36, 0.82, -0.26, 0, 0.18, 0);
    addBox(bodyGroup, 0.18, 0.12, 0.78, rim, 0.38, 1.15, -0.26, 0, 0.18, 0);
    addBox(bodyGroup, 0.18, 0.12, 0.78, rim, 0.38, 0.48, -0.26, 0, 0.18, 0);
    baseHeight = 1.95;
  } else if (type === 'skeleton_archer') {
    const bone = makeMat(0xe2e8f0, { roughness: 0.55, metalness: 0.1 });
    const violet = makeMat(0xa855f7, {
      emissive: 0x9333ea,
      emissiveIntensity: 0.6,
      roughness: 0.35,
    });
    const darkCloth = makeMat(0x1e1b4b, { roughness: 0.8 });

    addCylinder(bodyGroup, 0.05, 0.05, 0.48, 6, bone, 0, 0.24, -0.12);
    addCylinder(bodyGroup, 0.05, 0.05, 0.48, 6, bone, 0, 0.24, 0.12);
    // Ribcage + tattered cloak
    addBox(bodyGroup, 0.26, 0.5, 0.34, bone, 0, 0.74, 0);
    addBox(bodyGroup, 0.18, 0.54, 0.38, darkCloth, -0.12, 0.74, 0);
    // Skull
    addBox(bodyGroup, 0.28, 0.3, 0.28, bone, 0.02, 1.18, 0);
    // Glowing violet eyes
    addBox(bodyGroup, 0.04, 0.06, 0.06, violet, 0.16, 1.2, -0.07);
    addBox(bodyGroup, 0.04, 0.06, 0.06, violet, 0.16, 1.2, 0.07);

    // Violet curved bow
    weaponPivot.position.set(0.3, 0.92, -0.12);
    bodyGroup.add(weaponPivot);
    const bowArc = new THREE.Mesh(
      new THREE.TorusGeometry(0.42, 0.04, 6, 12, Math.PI * 0.95),
      violet
    );
    bowArc.rotation.z = -Math.PI * 0.475;
    bowArc.castShadow = true;
    weaponPivot.add(bowArc);
    baseHeight = 1.7;
  } else if (type === 'berserker') {
    const skin = makeMat(0x7f1d1d, { roughness: 0.58 });
    const leather = makeMat(0x27272a, { roughness: 0.8 });
    const axeMat = makeMat(0xd4d4d8, {
      metalness: 0.78,
      roughness: 0.25,
      emissive: 0xef4444,
      emissiveIntensity: 0.2,
    });

    addBox(bodyGroup, 0.22, 0.46, 0.22, leather, 0, 0.23, -0.18);
    addBox(bodyGroup, 0.22, 0.46, 0.22, leather, 0, 0.23, 0.18);
    addBox(bodyGroup, 0.5, 0.68, 0.66, skin, 0, 0.82, 0);
    addBox(bodyGroup, 0.34, 0.34, 0.34, skin, 0.06, 1.34, 0);
    // Shoulder spikes
    addCone(bodyGroup, 0.16, 0.34, 5, leather, 0, 1.28, -0.44, -0.5, 0, 0);
    addCone(bodyGroup, 0.16, 0.34, 5, leather, 0, 1.28, 0.44, 0.5, 0, 0);

    // Twin battleaxes (right & left)
    weaponPivot.position.set(0.14, 0.96, 0.44);
    bodyGroup.add(weaponPivot);
    addCylinder(weaponPivot, 0.04, 0.04, 0.82, 6, leather, 0.32, 0, 0, 0, 0, Math.PI / 2);
    addBox(weaponPivot, 0.32, 0.38, 0.07, axeMat, 0.64, 0.08, 0);

    const leftAxe = new THREE.Group();
    leftAxe.position.set(0.14, 0.96, -0.44);
    bodyGroup.add(leftAxe);
    addCylinder(leftAxe, 0.04, 0.04, 0.82, 6, leather, 0.32, 0, 0, 0, 0, Math.PI / 2);
    addBox(leftAxe, 0.32, 0.38, 0.07, axeMat, 0.64, 0.08, 0);
    baseHeight = 1.95;
  } else {
    // enemy_commander — 1.7x scale dark-crimson warlord w/ horned golden crown & giant battleaxe!
    baseScale = 1.7;
    const armor = makeMat(0x450a0a, { metalness: 0.62, roughness: 0.34 });
    const crimsonGlow = makeMat(0xdc2626, {
      metalness: 0.4,
      roughness: 0.35,
      emissive: 0xb91c1c,
      emissiveIntensity: 0.45,
    });
    const gold = makeMat(0xf59e0b, {
      metalness: 0.85,
      roughness: 0.22,
      emissive: 0xb45309,
      emissiveIntensity: 0.25,
    });
    const darkCape = makeMat(0x18181b, { roughness: 0.75, side: THREE.DoubleSide });

    addBox(bodyGroup, 0.24, 0.5, 0.24, armor, 0, 0.25, -0.2);
    addBox(bodyGroup, 0.24, 0.5, 0.24, armor, 0, 0.25, 0.2);
    addBox(bodyGroup, 0.56, 0.74, 0.72, armor, 0, 0.88, 0);
    addBox(bodyGroup, 0.6, 0.24, 0.32, crimsonGlow, 0.04, 0.96, 0);

    // Spiked heavy pauldrons
    addBox(bodyGroup, 0.42, 0.32, 0.36, armor, 0, 1.24, -0.5, 0.2, 0, 0);
    addBox(bodyGroup, 0.42, 0.32, 0.36, armor, 0, 1.24, 0.5, -0.2, 0, 0);
    addCone(bodyGroup, 0.1, 0.34, 4, gold, 0, 1.5, -0.54, -0.35, 0, 0);
    addCone(bodyGroup, 0.1, 0.34, 4, gold, 0, 1.5, 0.54, 0.35, 0, 0);

    // Head + Horned Golden Crown
    addBox(bodyGroup, 0.4, 0.4, 0.4, armor, 0.04, 1.48, 0);
    addBox(bodyGroup, 0.08, 0.08, 0.26, crimsonGlow, 0.24, 1.5, 0);
    addCylinder(bodyGroup, 0.24, 0.22, 0.14, 6, gold, 0.04, 1.72, 0);
    // Curved golden horns
    addCone(bodyGroup, 0.08, 0.44, 5, gold, 0.04, 1.9, -0.26, -0.55, 0, 0);
    addCone(bodyGroup, 0.08, 0.44, 5, gold, 0.04, 1.9, 0.26, 0.55, 0, 0);

    // Flowing dark cape
    addBox(bodyGroup, 0.08, 1.15, 0.74, darkCape, -0.4, 0.78, 0, 0, 0, -0.2);

    // Giant Warlord Battleaxe
    weaponPivot.position.set(0.2, 1.0, 0.54);
    bodyGroup.add(weaponPivot);
    addCylinder(weaponPivot, 0.055, 0.055, 1.75, 6, armor, 0.65, 0, 0, 0, 0, Math.PI / 2);
    const giantBlade = makeMat(0xfca5a5, {
      metalness: 0.82,
      roughness: 0.2,
      emissive: 0xef4444,
      emissiveIntensity: 0.4,
    });
    addBox(weaponPivot, 0.48, 0.72, 0.1, giantBlade, 1.32, 0.12, 0);
    addBox(weaponPivot, 0.34, 0.52, 0.09, gold, 1.32, -0.26, 0);

    // Ominous commander ground ring
    const bossRing = new THREE.Mesh(
      new THREE.RingGeometry(0.95, 1.14, 32),
      new THREE.MeshBasicMaterial({
        color: 0xef4444,
        transparent: true,
        opacity: 0.65,
        side: THREE.DoubleSide,
        depthWrite: false,
      })
    );
    bossRing.rotation.x = -Math.PI / 2;
    bossRing.position.y = 0.05;
    root.add(bossRing);

    baseHeight = 3.55;
  }

  bodyGroup.scale.setScalar(baseScale);

  const rig: CharacterRig = {
    root,
    bodyGroup,
    weaponPivot,
    baseScale,
    baseHeight,
    swingPhase: 0,
  };

  tryAttachCustomModel(`enemy_${type}`, rig, baseScale);
  return rig;
}

/**
 * 3D Regiment Hold Banner Flag
 */
export function createRegimentBanner(): BannerRig {
  const root = new THREE.Group();

  const stoneMat = makeMat(0x475569, { roughness: 0.85, metalness: 0.15 });
  const goldMat = makeMat(0xfbbf24, { metalness: 0.8, roughness: 0.25 });
  const poleMat = makeMat(0x78350f, { roughness: 0.8 });
  const clothMat = makeMat(0x0284c7, {
    roughness: 0.5,
    metalness: 0.1,
    emissive: 0x0ea5e9,
    emissiveIntensity: 0.35,
    side: THREE.DoubleSide,
  });

  // Base pedestal
  addCylinder(root, 0.35, 0.45, 0.18, 8, stoneMat, 0, 0.09, 0);
  // Pole
  addCylinder(root, 0.05, 0.06, 3.2, 6, poleMat, 0, 1.65, 0);
  // Finial spear tip
  addCone(root, 0.12, 0.34, 4, goldMat, 0, 3.38, 0);
  // Crossbar
  addCylinder(root, 0.035, 0.035, 1.1, 6, goldMat, 0, 3.05, 0, Math.PI / 2, 0, 0);

  // Pennant cloth
  const clothMesh = new THREE.Mesh(new THREE.PlaneGeometry(0.95, 1.45, 4, 4), clothMat);
  clothMesh.position.set(0.5, 2.32, 0);
  clothMesh.castShadow = true;
  root.add(clothMesh);

  // Glowing hold anchor ring on ground
  const ringMesh = new THREE.Mesh(
    new THREE.RingGeometry(0.85, 1.08, 28),
    new THREE.MeshBasicMaterial({
      color: 0x38bdf8,
      transparent: true,
      opacity: 0.65,
      side: THREE.DoubleSide,
      depthWrite: false,
    })
  );
  ringMesh.rotation.x = -Math.PI / 2;
  ringMesh.position.y = 0.05;
  root.add(ringMesh);

  return { root, clothMesh, ringMesh };
}

/**
 * Translucent glowing formation slot disc for regiment soldiers
 */
export function createFormationSlotDisc(): THREE.Mesh {
  const mat = new THREE.MeshBasicMaterial({
    color: 0x38bdf8,
    transparent: true,
    opacity: 0.24,
    side: THREE.DoubleSide,
    depthWrite: false,
  });
  const mesh = new THREE.Mesh(new THREE.RingGeometry(0.32, 0.46, 16), mat);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.y = 0.035;
  return mesh;
}

/**
 * Recursively disposes geometries, materials, and textures owned by an Object3D subtree.
 */
export function disposeObject3D(obj: THREE.Object3D): void {
  obj.traverse((child) => {
    if (child instanceof THREE.Mesh || child instanceof THREE.Line || child instanceof THREE.Points) {
      child.geometry?.dispose();
      const materials = Array.isArray(child.material) ? child.material : [child.material];
      for (const mat of materials) {
        if (!mat) continue;
        if ('map' in mat && mat.map instanceof THREE.Texture) {
          mat.map.dispose();
        }
        mat.dispose();
      }
    } else if (child instanceof THREE.Sprite) {
      if (child.material.map) {
        child.material.map.dispose();
      }
      child.material.dispose();
    }
  });
}
