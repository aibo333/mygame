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
      className="pixel-canvas-host relative aspect-video w-full overflow-hidden rounded-xl border border-slate-700/80 bg-slate-950 shadow-[0_0_30px_rgba(2,6,23,0.85)]"
      aria-label="守村戰場即時畫面"
    />
  );
}
