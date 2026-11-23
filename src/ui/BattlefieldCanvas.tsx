import { useEffect, useRef } from 'react';
import type { MutableRefObject } from 'react';
import type { CombatSnapshot } from '../core/types/combat';
import { BattlefieldController } from '../game/BattlefieldController';

export interface BattlefieldCanvasProps {
  initialSnapshot: CombatSnapshot;
  controllerRef: MutableRefObject<BattlefieldController | null>;
}

export function BattlefieldCanvas({
  initialSnapshot,
  controllerRef,
}: BattlefieldCanvasProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const initialSnapshotRef = useRef<CombatSnapshot>(initialSnapshot);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const controller = new BattlefieldController(container, initialSnapshotRef.current);
    controllerRef.current = controller;

    return () => {
      controller.destroy();
      if (controllerRef.current === controller) {
        controllerRef.current = null;
      }
    };
  }, [controllerRef]);

  return (
    <div
      ref={containerRef}
      onContextMenu={(e) => e.preventDefault()}
      className="pixel-canvas-host relative aspect-[9/5] w-full cursor-crosshair select-none overflow-hidden rounded-xl border border-slate-700/80 bg-slate-950 shadow-[0_0_32px_rgba(2,6,23,0.9)]"
      aria-label="戰意守城即時戰場畫面"
    />
  );
}
