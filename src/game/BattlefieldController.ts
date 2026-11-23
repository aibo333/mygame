import Phaser from 'phaser';
import type { CombatEvent, CombatSnapshot } from '../core/types/combat';
import {
  BattleScene,
  DEFAULT_ARENA_HEIGHT,
  DEFAULT_ARENA_WIDTH,
} from './BattleScene';

export interface PointerWorldState {
  x: number;
  y: number;
  leftDown: boolean;
  rightDown: boolean;
}

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

  public getPointerState(): PointerWorldState {
    if (this.destroyed) {
      return {
        x: DEFAULT_ARENA_WIDTH / 2,
        y: DEFAULT_ARENA_HEIGHT / 2,
        leftDown: false,
        rightDown: false,
      };
    }
    return this.scene.getPointerState();
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
