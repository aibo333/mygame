import Phaser from 'phaser';
import type { EnemyUnitType, RegimentType } from '../core/types/combat';

type Palette = Record<string, number>;

export const HERO_TEXTURE_KEY = 'hero-commander';

export function getSoldierTextureKey(type: RegimentType): string {
  return `soldier-${type}`;
}

export function getEnemyTextureKey(type: EnemyUnitType): string {
  return `enemy-${type}`;
}

/**
 * Draws an ASCII pixel grid onto a Phaser Graphics object and bakes it into a crisp texture.
 * Each character maps to a hex color in `palette`; '.' or ' ' is transparent.
 */
function bakePixelGrid(
  scene: Phaser.Scene,
  key: string,
  grid: string[],
  palette: Palette,
  pixelSize = 2,
): void {
  if (scene.textures.exists(key)) {
    return;
  }

  const rows = grid.length;
  const cols = grid[0]?.length ?? 0;
  const graphics = scene.make.graphics({ x: 0, y: 0 }, false);

  for (let r = 0; r < rows; r += 1) {
    const row = grid[r];
    for (let c = 0; c < cols; c += 1) {
      const ch = row[c];
      if (ch === '.' || ch === ' ') continue;
      const color = palette[ch];
      if (color === undefined) continue;
      graphics.fillStyle(color, 1);
      graphics.fillRect(c * pixelSize, r * pixelSize, pixelSize, pixelSize);
    }
  }

  graphics.generateTexture(key, cols * pixelSize, rows * pixelSize);
  graphics.destroy();
}

export function generateBattleTextures(scene: Phaser.Scene): void {
  // 1. Player Hero — Valkyrie Knight Commander (18x18 * 2 = 36x36), facing right
  // Armored valkyrie knight with flowing crimson-gold cape, winged golden crest, kite shield & spear
  bakePixelGrid(
    scene,
    HERO_TEXTURE_KEY,
    [
      '....G..GG..G......',
      '.....GGGGGG.......',
      '....GGSSSSGG......',
      '....GSKKKKSS......',
      '....GSSWWSSG....P.',
      '...RRGSSSSG....PP.',
      '..RRRRGGGGGB..PPL.',
      '..RRGGCCCCGGBBPL..',
      '..RRGCGGGGCCBBP...',
      '..RRGGCCCCGGBB....',
      '..RRRGGGGGGGBB....',
      '..RRR.CCCC.GB.....',
      '...RR.CCCC........',
      '...R..CC.C........',
      '.....GGC.CG.......',
      '.....DD..DD.......',
      '..................',
      '..................',
    ],
    {
      G: 0xfacc15, // golden crest & trim
      S: 0xe2e8f0, // silver-steel helm & plates
      K: 0x0f172a, // helmet visor
      W: 0x38bdf8, // valkyrie eye glint
      R: 0xdc2626, // flowing commander cape
      C: 0x0ea5e9, // azure knight cuirass
      B: 0x1d4ed8, // kite shield body
      P: 0xf8fafc, // spearhead tip
      L: 0x94a3b8, // spear shaft
      D: 0x1e293b, // armored boots
    },
    2,
  );

  // 2. Friendly Soldier: Shieldmen — steel-blue kite shield + helmet (12x12 * 2 = 24x24), facing right
  bakePixelGrid(
    scene,
    getSoldierTextureKey('shieldmen'),
    [
      '....SSSS....',
      '...SSSSSS...',
      '...SKKKKS...',
      '....SSSS....',
      '...BBCCGGG..',
      '..BBBCCGBBG.',
      '..BBCCCGBBG.',
      '..BBCCCGBBG.',
      '...BCCCGGG..',
      '....CC.C....',
      '...DD..DD...',
      '............',
    ],
    {
      S: 0x94a3b8, // steel helmet
      K: 0x0f172a, // visor
      C: 0x38bdf8, // steel-blue surcoat
      B: 0x1d4ed8, // deep blue armor & kite shield face
      G: 0xe2e8f0, // kite shield rim
      D: 0x1e293b, // boots
    },
    2,
  );

  // 3. Friendly Soldier: Pikemen — teal/silver armor + long pike protruding forward (12x12 * 2 = 24x24)
  bakePixelGrid(
    scene,
    getSoldierTextureKey('pikemen'),
    [
      '...SSSS.....',
      '..SSSSSS....',
      '..SKKKKS....',
      '...TTTT.....',
      '..TTTTTT..PP',
      '..TTGGTTLLPP',
      '.TTTGGTTLL..',
      '..TTTTTT....',
      '...TTTT.....',
      '...TT.T.....',
      '..DD..DD....',
      '............',
    ],
    {
      S: 0xcbd5e1, // silver helm
      K: 0x0f172a, // visor
      T: 0x14b8a6, // teal lamellar armor
      G: 0x99f6e4, // silver-teal chestplate
      L: 0xb45309, // pike shaft
      P: 0xf8fafc, // sharp steel pike tip
      D: 0x1e293b, // boots
    },
    2,
  );

  // 4. Friendly Soldier: Archers — emerald hooded ranger + bow (12x12 * 2 = 24x24)
  bakePixelGrid(
    scene,
    getSoldierTextureKey('archers'),
    [
      '...EEEE.....',
      '..EEEEEE....',
      '..EFFKFE.A..',
      '...EEEE..AA.',
      '..EGGGEEW.A.',
      '..EGGGEEW.A.',
      '..EGGGEEW.A.',
      '...EGGEE.AA.',
      '...EBBEE.A..',
      '...BB.B.....',
      '..DD..DD....',
      '............',
    ],
    {
      E: 0x10b981, // emerald hood & cloak
      G: 0x047857, // forest tunic
      F: 0xfde68a, // face
      K: 0x0f172a, // eye
      A: 0xf59e0b, // longbow wood
      W: 0xfef3c7, // bowstring
      B: 0x334155, // leather trousers
      D: 0x1e293b, // boots
    },
    2,
  );

  // 5. Enemy: Goblin Raider — agile green raider with dagger (12x12 * 2 = 24x24), facing left
  bakePixelGrid(
    scene,
    getEnemyTextureKey('goblin_raider'),
    [
      '............',
      '..GG...GG...',
      '.GGGGGGGGG..',
      '..GGRRGGG...',
      '...GGWWG....',
      '.S..LLLL....',
      'SS.LLLLLL...',
      '.S.GLLLLG...',
      '....LLLL....',
      '...GG..GG...',
      '..DD....DD..',
      '............',
    ],
    {
      G: 0x4ade80, // goblin green skin
      R: 0xef4444, // red eyes
      W: 0xfef08a, // fangs
      L: 0x78350f, // ragged leather
      S: 0xcbd5e1, // jagged blade
      D: 0x1e293b, // feet
    },
    2,
  );

  // 6. Enemy: Shield Orc — bulky crimson/iron shield orc (14x14 * 2 = 28x28), facing left
  bakePixelGrid(
    scene,
    getEnemyTextureKey('shield_orc'),
    [
      '.....IIII.....',
      '....ICCCCI....',
      '....CRRRRC....',
      '....CWCCWC....',
      '..IIICCCCII...',
      '.IGGICCCCDDI..',
      '.IGGICCCCDDI..',
      '.IGGICCCCDDI..',
      '.IGGICCCCDDI..',
      '..IIIDDDDDI...',
      '....DDDDDD....',
      '....DD..DD....',
      '...KK....KK...',
      '..............',
    ],
    {
      I: 0x64748b, // heavy iron shield & helm rim
      G: 0x991b1b, // crimson shield face
      C: 0xb91c1c, // crimson orc hide
      R: 0xfef08a, // fierce eyes
      W: 0xf8fafc, // orc tusks
      D: 0x450a0a, // dark iron-crimson armor
      K: 0x1e293b, // heavy boots
    },
    2,
  );

  // 7. Enemy: Skeleton Archer — bone/violet archer (12x12 * 2 = 24x24), facing left
  bakePixelGrid(
    scene,
    getEnemyTextureKey('skeleton_archer'),
    [
      '....BBBB....',
      '...BBBBBB...',
      '...BPVVPB...',
      '....BBBB....',
      '.P..PPPP....',
      'P.WPPBBPP...',
      'P.WPPPBPP...',
      'P.W.PPPP....',
      '.P..B..B....',
      '....B..B....',
      '...BB..BB...',
      '............',
    ],
    {
      B: 0xe2e8f0, // skeleton bone
      P: 0x9333ea, // dark violet cloak & bow
      V: 0xe879f9, // glowing magenta eyes
      W: 0xf8fafc, // bowstring
    },
    2,
  );

  // 8. Enemy: Berserker — dark-red twin-axe berserker (14x14 * 2 = 28x28), facing left
  bakePixelGrid(
    scene,
    getEnemyTextureKey('berserker'),
    [
      '....R....R....',
      '....RRRRRR....',
      '...RRYYYYRR...',
      '...RWWKKWWR...',
      '.S..DDDDDD..S.',
      'SS.DDRRRRDD.SS',
      'SS.DDRRRRDD.SS',
      '.S..DDDDDD..S.',
      '....DDRRDD....',
      '....DDDDDD....',
      '....DD..DD....',
      '...KK....KK...',
      '..............',
      '..............',
    ],
    {
      R: 0xdc2626, // blood-red warpaint / hair
      Y: 0xfef08a, // rage eyes
      W: 0xf8fafc, // tusks/teeth
      K: 0x1c1917, // dark mouth
      D: 0x7f1d1d, // dark-red scarred torso
      S: 0xcbd5e1, // twin axe blades
    },
    2,
  );

  // 9. Enemy: Enemy Commander — massive dark-crimson/gold boss warlord (22x22 * 2 = 44x44), facing left
  bakePixelGrid(
    scene,
    getEnemyTextureKey('enemy_commander'),
    [
      '....G............G....',
      '...GG....GGGG....GG...',
      '....GG..GGGGGG..GG....',
      '.....GGGGCCCCGGGG.....',
      '.....GCCRRRRRRCCG.....',
      '.....CCYYCCCCYYCC.....',
      '.....CCCCCCCCCCCC.....',
      '....GGCCWWCCWWCCGG....',
      '..SS.GDDDDDDDDDDG.....',
      '.SSSSGDDCCCCCCDDGG....',
      'SSSSSGDDCCGGCCDDGGG...',
      'SSSSSGDDDDDDDDDDGGG...',
      '.SSSSGDDCCCCCCDDGG....',
      '..SSSGDDDDDDDDDDGG....',
      '....SGDDDDDDDDDDG.....',
      '....S.GGDDDDDDGG......',
      '....S..GCCCCCCGG......',
      '.......GCC..CCG.......',
      '......GGCC..CCGG......',
      '......DDCC..CCDD......',
      '.....KKKK....KKKK.....',
      '......................',
    ],
    {
      G: 0xfacc15, // horned gold crown & trim
      C: 0x991b1b, // dark crimson warlord hide
      D: 0x450a0a, // obsidian-crimson plate armor
      R: 0xef4444, // warlord brow
      Y: 0xfef08a, // blazing golden eyes
      W: 0xf8fafc, // tusks
      S: 0xcbd5e1, // giant greataxe blade
      K: 0x0f172a, // iron greaves
    },
    2,
  );

  // 10. Crisp 4x4 white pixel square for particle bursts & sparks
  if (!scene.textures.exists('px-square')) {
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 1);
    g.fillRect(0, 0, 4, 4);
    g.generateTexture('px-square', 4, 4);
    g.destroy();
  }
}
