import type { CombatEvent, CombatSnapshot } from '../core/types/combat';
import {
  Battlefield3DScene,
  DEFAULT_ARENA_HEIGHT,
  DEFAULT_ARENA_WIDTH,
  type CameraBasis2D,
  type CameraMode,
  type PointerWorldState,
} from './Battlefield3DScene';

export type { CameraBasis2D, CameraMode, PointerWorldState };

export class BattlefieldController {
  private scene3d: Battlefield3DScene | null = null;
  private cameraMode: CameraMode = 'tactical';
  private destroyed = false;

  constructor(container: HTMLElement, initialSnapshot?: CombatSnapshot) {
    this.scene3d = new Battlefield3DScene(container, initialSnapshot);
  }

  public syncState(snapshot: CombatSnapshot, events: CombatEvent[]): void {
    if (this.destroyed || !this.scene3d) return;
    this.scene3d.syncState(snapshot, events);
  }

  public getPointerState(): PointerWorldState {
    if (this.destroyed || !this.scene3d) {
      return {
        x: DEFAULT_ARENA_WIDTH / 2,
        y: DEFAULT_ARENA_HEIGHT / 2,
        leftDown: false,
        rightDown: false,
      };
    }
    return this.scene3d.getPointerState();
  }

  public setCameraMode(mode: CameraMode): void {
    this.cameraMode = mode;
    if (this.destroyed || !this.scene3d) return;
    this.scene3d.setCameraMode(mode);
  }

  public getCameraMode(): CameraMode {
    if (this.destroyed || !this.scene3d) {
      return this.cameraMode;
    }
    return this.scene3d.getCameraMode();
  }

  public getCameraBasis2D(): CameraBasis2D {
    if (this.destroyed || !this.scene3d) {
      return { forwardX: 0, forwardY: -1, rightX: 1, rightY: 0 };
    }
    return this.scene3d.getCameraBasis2D();
  }

  public destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    if (this.scene3d) {
      this.scene3d.destroy();
      this.scene3d = null;
    }
  }
}
