import Phaser from 'phaser';
import type { EnemyArchetype, SquadRole } from '../core/types/combat';

type Palette = Record<string, number>;

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

export function getHeroTextureKey(role: SquadRole): string {
  return `sprite-hero-${role}`;
}

export function getEnemyTextureKey(archetype: EnemyArchetype): string {
  return `sprite-enemy-${archetype}`;
}

export function generateBattleTextures(scene: Phaser.Scene): void {
  // 1. Hero Tank — 艾莉絲 (Cyan/Gold Paladin Knight with Kite Shield & Sword) — 18x18 * 2 = 36x36
  bakePixelGrid(
    scene,
    getHeroTextureKey('tank'),
    [
      '......GGGG........',
      '.....GCCCCG.......',
      '....GCCCCCCGG.....',
      '....GCKKKKCG......',
      '....GCSWWSG....S..',
      '...BBGCCCCGB..SS..',
      '..BBBBGGGGGBB.SG..',
      '..BGGCCCCGGBBGG...',
      '..BGCCGGCCGGGB....',
      '..BGGCCCCGGBG.....',
      '..BBGCCCCGGB......',
      '..BBBGGGGGB.......',
      '...BBBCCBB........',
      '....BCCCCB........',
      '....BC..CB........',
      '...GGC..CGG.......',
      '...DD....DD.......',
      '..................',
    ],
    {
      G: 0xfacc15, // gold trim
      C: 0x38bdf8, // cyan armor
      K: 0x0f172a, // helmet visor dark
      S: 0xe2e8f0, // steel / skin highlight
      W: 0xbae6fd, // bright cyan glint
      B: 0x0284c7, // deep azure cape / shield body
      D: 0x1e293b, // dark iron boots
    },
    2,
  );

  // 2. Hero DPS — 莉娜 (Emerald/Amber Ranger with Hood & Bow) — 18x18 * 2 = 36x36
  bakePixelGrid(
    scene,
    getHeroTextureKey('dps'),
    [
      '......EEEE........',
      '.....EEEEEE.......',
      '....EEFFFFEE......',
      '....EFKFFKFE..A...',
      '....EFFFFFFE...A..',
      '.....AAAAAA....AA.',
      '....EAAAAEEE..W.A.',
      '...EEGGGGEEEEW..A.',
      '...EGGAAAGGEW...A.',
      '...EEGAAAGGEW...A.',
      '....EGGGGGEEW..A..',
      '....EEGGGEEE..AA..',
      '.....EBBBE...A....',
      '.....EB.BE........',
      '....EEB.BEE.......',
      '....DD...DD.......',
      '..................',
      '..................',
    ],
    {
      E: 0x10b981, // emerald cloak
      G: 0x047857, // dark emerald tunic
      A: 0xf59e0b, // amber scarf & bow wood
      F: 0xfde68a, // face skin
      K: 0x0f172a, // eyes
      W: 0xfef3c7, // bowstring / arrow tip
      B: 0x334155, // leather leggings
      D: 0x1e293b, // boots
    },
    2,
  );

  // 3. Hero Support — 米婭 (Violet/White Cleric with Star Staff & Halo) — 18x18 * 2 = 36x36
  bakePixelGrid(
    scene,
    getHeroTextureKey('support'),
    [
      '.....YYYYYY.......',
      '....Y......Y..Y...',
      '.....VVVVVV..YYY..',
      '....VVFFFFVV..Y...',
      '....VFKFFKFV..S...',
      '....VVFFFFVV..S...',
      '.....VVGGVV...S...',
      '....WWWWWWWW..S...',
      '...WWVVGGVVWW.S...',
      '...WWVVVVVVWW.S...',
      '...WWWVVVVWWW.S...',
      '....WWWWWWWW..S...',
      '...WWVVWWVVWW.S...',
      '...WWWWWWWWWW.S...',
      '....WW....WW......',
      '....VV....VV......',
      '..................',
      '..................',
    ],
    {
      Y: 0xfef08a, // starlight gold
      V: 0xa78bfa, // violet hair & trim
      W: 0xf8fafc, // white vestments
      G: 0x7c3aed, // deep violet sash
      F: 0xfef3c7, // face
      K: 0x1e1b4b, // eyes
      S: 0xc4b5fd, // staff shaft
    },
    2,
  );

  // 4. Enemy Goblin — 哥布林突襲者 (Green Agile Raider with Dagger) — 16x16 * 2 = 32x32
  bakePixelGrid(
    scene,
    getEnemyTextureKey('goblin'),
    [
      '................',
      '....GG....GG....',
      '..GGGGGGGGGG....',
      '...GGGRRGGG.....',
      '....GGGGGG......',
      '.....GWWG.......',
      '..S..LLLL.......',
      '.SS.LLLLLL......',
      '..SGLLLLLG......',
      '....LLLLLL......',
      '....GLLLLG......',
      '.....G..G.......',
      '....GG..GG......',
      '...DD....DD.....',
      '................',
      '................',
    ],
    {
      G: 0x4ade80, // goblin green
      R: 0xef4444, // fierce red eyes
      W: 0xfef08a, // fangs
      L: 0x78350f, // ragged leather armor
      S: 0xcbd5e1, // jagged dagger steel
      D: 0x1e293b, // dark feet
    },
    2,
  );

  // 5. Enemy Archer — 骷髏弓手 (Bone-white/Purple Skeleton with Bow) — 16x16 * 2 = 32x32
  bakePixelGrid(
    scene,
    getEnemyTextureKey('archer'),
    [
      '................',
      '......BBBB......',
      '.....BBBBBB.....',
      '....BBPVVPBB....',
      '....BBBBBBBB....',
      '..P..BB..BB.....',
      '.PP..PPPPPP.....',
      'P.W.PPBBBBPP....',
      'P.W.PPBPPBPP....',
      'P.W..PPBBPP.....',
      '.PP...PPPP......',
      '..P...B..B......',
      '......B..B......',
      '.....BB..BB.....',
      '................',
      '................',
    ],
    {
      B: 0xe2e8f0, // skeleton bone
      P: 0x9333ea, // dark violet cloak & bow
      V: 0xe879f9, // glowing magenta eyes
      W: 0xf8fafc, // bowstring
    },
    2,
  );

  // 6. Enemy Bomber — 爆裂史萊姆 (Glowing Orange/Red Explosive Slime) — 16x16 * 2 = 32x32
  bakePixelGrid(
    scene,
    getEnemyTextureKey('bomber'),
    [
      '.......YY.......',
      '......YOO.......',
      '.......KK.......',
      '.....RRRRRR.....',
      '....RROOOORR....',
      '...ROOYYYYOOR...',
      '..RROYYKKYYORR..',
      '..ROOYKYYKYOOR..',
      '..ROOYYYYYYOOR..',
      '..RROOYYYYOORR..',
      '..RRROOOOOORRR..',
      '...RRRRRRRRRR...',
      '....RRRRRRRR....',
      '.....RR..RR.....',
      '................',
      '................',
    ],
    {
      Y: 0xfef08a, // spark / molten core
      O: 0xf97316, // glowing orange
      R: 0xdc2626, // fiery crimson shell
      K: 0x1c1917, // fuse / angry eyes
    },
    2,
  );

  // 7. Enemy Brute — 獸人狂戰士 (Large Dark-Crimson Elite Orc with Gold Crown & Battleaxe) — 22x22 * 2 = 44x44
  bakePixelGrid(
    scene,
    getEnemyTextureKey('brute'),
    [
      '.......G..GG..G.......',
      '.......GGGGGGGG.......',
      '......GCCCCCCCCG......',
      '.....GCCYYYYYYCCG.....',
      '.....CCCRRCCRRCCC.....',
      '.....CCCCCCCCCCCC.....',
      '....GGCCWWCCWWCCGG....',
      '..S..GDDDDDDDDDDG.....',
      '.SSSGGDDCCCCCCDDGG....',
      'SSSSGGDDCCGGCCDDGG....',
      '.SSSGGDDDDDDDDDDGG....',
      '..S..GDDCCCCCCDDG.....',
      '....SGDDDDDDDDDDG.....',
      '....S.GGDDDDDDGG......',
      '....S..GCCCCCCGG......',
      '.......GCC..CCG.......',
      '......GGCC..CCGG......',
      '......DDCC..CCDD......',
      '.....DDDD....DDDD.....',
      '......................',
      '......................',
      '......................',
    ],
    {
      G: 0xfacc15, // elite gold crown & outline trim
      C: 0x991b1b, // dark crimson berserker hide
      D: 0x450a0a, // heavy dark iron armor
      R: 0xfef08a, // glowing yellow-gold rage eyes
      Y: 0xef4444, // war paint / brow
      W: 0xf8fafc, // tusks
      S: 0x94a3b8, // massive battleaxe blade
    },
    2,
  );

  // 8. Crisp 4x4 white pixel square for particle bursts & embers
  if (!scene.textures.exists('px-square')) {
    const g = scene.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 1);
    g.fillRect(0, 0, 4, 4);
    g.generateTexture('px-square', 4, 4);
    g.destroy();
  }

  // 9. Spawn Portal Rune Texture (16x24 * 2 = 32x48)
  bakePixelGrid(
    scene,
    'spawn-portal',
    [
      '......PPPP......',
      '....PPVVVVPP....',
      '...PVVMMMMVVP...',
      '..PVMM....MMVP..',
      '..PVM..PP..MVP..',
      '.PVM..PVVP..MVP.',
      '.PVM.PVMMVP.MVP.',
      '.PVM.PM..MP.MVP.',
      '.PVM.PM..MP.MVP.',
      '.PVM.PVMMVP.MVP.',
      '.PVM..PVVP..MVP.',
      '..PVM..PP..MVP..',
      '..PVMM....MMVP..',
      '...PVVMMMMVVP...',
      '....PPVVVVPP....',
      '......PPPP......',
    ],
    {
      P: 0x581c87,
      V: 0x9333ea,
      M: 0xe879f9,
    },
    2,
  );
}
