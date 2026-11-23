import Phaser from 'phaser';
import { DEFAULT_ARENA_HEIGHT, DEFAULT_ARENA_WIDTH } from '../core/combat/presets';
import type { CombatEvent, CombatSnapshot } from '../core/types/combat';
import { BattleScene } from './BattleScene';

export class BattlefieldController {
  private game: Phaser.Game | null = null;
  private scene: BattleScene;
  private destroyed = false;

  constructor(container: HTMLElement, initialSnapshot?: CombatSnapshot) {
    this.scene = new BattleScene();

    if (initialSnapshot) {
      this.scene.syncState(initialSnapshot, []);
    }

    const width = initialSnapshot?.arenaWidth ?? DEFAULT_ARENA_WIDTH;
    const height = initialSnapshot?.arenaHeight ?? DEFAULT_ARENA_HEIGHT;

    this.game = new Phaser.Game({
      type: Phaser.AUTO,
      parent: container,
      width,
      height,
      backgroundColor: '#0b1120',
      pixelArt: true,
      antialias: false,
      roundPixels: true,
      scale: {
        mode: Phaser.Scale.FIT,
        autoCenter: Phaser.Scale.CENTER_BOTH,
      },
      scene: [this.scene],
    });
  }

  public syncState(snapshot: CombatSnapshot, events: CombatEvent[]): void {
    if (this.destroyed) return;
    this.scene.syncState(snapshot, events);
  }

  public destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    if (this.game) {
      this.game.destroy(true);
      this.game = null;
    }
  }
}
