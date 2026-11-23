import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Castle,
  ChevronRight,
  Clock,
  Pause,
  Play,
  RotateCcw,
  ShieldCheck,
  Skull,
  Swords,
  Trophy,
  Users,
} from 'lucide-react';
import { CombatEngine } from './core/combat/CombatEngine';
import { PHASE1_WAVES, REGIMENT_DEFINITIONS } from './core/combat/presets';
import type {
  CombatEvent,
  CombatSnapshot,
  PlayerInput,
  RegimentCommand,
  RegimentFormation,
  RegimentOrder,
  RegimentType,
} from './core/types/combat';
import type {
  BattlefieldController,
  CameraMode,
  PointerWorldState,
} from './game/BattlefieldController';
import { BattlefieldCanvas } from './ui/BattlefieldCanvas';
import { HeroHud } from './ui/HeroHud';
import { RegimentHud } from './ui/RegimentHud';
import { SideIntelPanel } from './ui/SideIntelPanel';
import type { CombatLogItem } from './ui/SideIntelPanel';

const FIXED_DT = 1 / 60;
const HUD_SYNC_INTERVAL_MS = 40; // ~25Hz React HUD updates
const MAX_LOG_ITEMS = 50;

const REGIMENT_SWITCHER_OPTIONS: Array<{
  type: RegimentType;
  emoji: string;
  shortLabel: string;
}> = [
  { type: 'shieldmen', emoji: '🛡️', shortLabel: '刀盾兵' },
  { type: 'pikemen', emoji: '🔱', shortLabel: '長槍兵' },
  { type: 'archers', emoji: '🏹', shortLabel: '長弓兵' },
];

function formatElapsed(sec: number): string {
  const clamped = Math.max(0, sec);
  const mins = Math.floor(clamped / 60);
  const rem = clamped - mins * 60;
  return `${String(mins).padStart(2, '0')}:${rem.toFixed(1).padStart(4, '0')}`;
}

function createWaveStartLog(
  waveIdx: number,
  regimentType: RegimentType,
  serial: number,
): CombatLogItem {
  const wave = PHASE1_WAVES[waveIdx] ?? PHASE1_WAVES[0];
  const reg = REGIMENT_DEFINITIONS[regimentType];
  const totalEnemies = wave.spawns.reduce((sum, s) => sum + s.count, 0);
  return {
    id: `log-start-${serial}`,
    timeSec: 0,
    kind: 'system',
    message: `第 ${wave.waveNumber} 波【${wave.name}】開戰！率領「${reg.name}」迎戰 ${totalEnemies} 名敵軍。`,
  };
}

function convertEventsToLogs(
  events: CombatEvent[],
  snapshot: CombatSnapshot,
  nextId: () => string,
): CombatLogItem[] {
  const items: CombatLogItem[] = [];
  const t = snapshot.elapsedSec;

  for (const ev of events) {
    switch (ev.type) {
      case 'regiment_command':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: ev.commandType === 'skill' ? 'skill' : 'command',
          message:
            ev.commandType === 'skill'
              ? `兵團發動特技【${ev.label}】！`
              : ev.commandType === 'formation'
                ? `兵團切換陣型：【${ev.label}】`
                : `下達兵團指令：【${ev.label}】`,
        });
        break;

      case 'hero_warcry':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: 'skill',
          message: `${snapshot.hero.name} 發動【戰意咆哮】，周圍兵團戰意高漲！`,
        });
        break;

      case 'hero_down':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: 'danger',
          message: `${snapshot.hero.name} 重傷退場，${ev.respawnSec.toFixed(0)} 秒後於城門重整歸陣！`,
        });
        break;

      case 'hero_respawn':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: 'victory',
          message: `${snapshot.hero.name} 重返戰場！`,
        });
        break;

      case 'commander_slam':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: 'danger',
          message: '敵方武將發動範圍重擊！注意翻滾閃避與拉開兵團！',
        });
        break;

      case 'gate_hit':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: 'danger',
          message: `城門受擊 -${Math.round(ev.amount)}（剩餘 ${Math.max(0, Math.ceil(ev.gateHpRemaining))} HP）`,
        });
        break;

      case 'unit_died':
        if (ev.team === 'enemy' && ev.isCommander) {
          items.push({
            id: nextId(),
            timeSec: t,
            kind: 'victory',
            message: '成功斬殺敵方武將！敵軍士氣動搖！',
          });
        }
        break;

      case 'combat_ended':
        items.push({
          id: nextId(),
          timeSec: t,
          kind: ev.status === 'victory' ? 'victory' : 'danger',
          message:
            ev.status === 'victory'
              ? `守城成功！全數殲滅敵軍，城門剩餘 ${Math.ceil(snapshot.gateHp)} HP。`
              : '城門失守，本波守城失敗！',
        });
        break;

      default:
        break;
    }
  }

  return items;
}

export default function App() {
  const [selectedWaveIdx, setSelectedWaveIdx] = useState(0);
  const [selectedRegiment, setSelectedRegiment] = useState<RegimentType>('shieldmen');
  const [isPaused, setIsPaused] = useState(false);
  const [cameraMode, setCameraMode] = useState<CameraMode>('tactical');

  const engineRef = useRef<CombatEngine | null>(null);
  if (engineRef.current === null) {
    engineRef.current = new CombatEngine({
      regimentType: 'shieldmen',
      wave: PHASE1_WAVES[0],
    });
  }

  const controllerRef = useRef<BattlefieldController | null>(null);
  const isPausedRef = useRef(isPaused);
  const cameraModeRef = useRef<CameraMode>(cameraMode);
  const logSerialRef = useRef(1);

  // Live input refs (zero React re-renders on key/mouse events)
  const heldKeysRef = useRef<Set<string>>(new Set());
  const pendingActionsRef = useRef({
    dodge: false,
    skill1: false,
    skill2: false,
  });

  const [snapshot, setSnapshot] = useState<CombatSnapshot>(() =>
    engineRef.current!.getSnapshot(),
  );
  const [logs, setLogs] = useState<CombatLogItem[]>(() => [
    createWaveStartLog(0, 'shieldmen', 0),
  ]);

  useEffect(() => {
    isPausedRef.current = isPaused;
  }, [isPaused]);

  useEffect(() => {
    cameraModeRef.current = cameraMode;
  }, [cameraMode]);

  const toggleCameraMode = useCallback(() => {
    setCameraMode((prev) => {
      const next: CameraMode = prev === 'tactical' ? 'tps' : 'tactical';
      cameraModeRef.current = next;
      controllerRef.current?.setCameraMode(next);
      return next;
    });
  }, []);

  const appendLogs = useCallback((newItems: CombatLogItem[]) => {
    if (newItems.length === 0) return;
    setLogs((prev) => [...newItems.reverse(), ...prev].slice(0, MAX_LOG_ITEMS));
  }, []);

  const getPointerOrDefault = useCallback((): PointerWorldState => {
    const pointer = controllerRef.current?.getPointerState();
    if (pointer) return pointer;
    const snap = engineRef.current?.getSnapshot();
    return {
      x: (snap?.hero.x ?? 260) + 120,
      y: snap?.hero.y ?? 300,
      leftDown: false,
      rightDown: false,
    };
  }, []);

  const startWave = useCallback(
    (waveIdx: number, regimentType: RegimentType) => {
      const waveDef = PHASE1_WAVES[waveIdx] ?? PHASE1_WAVES[0];
      const nextEngine = new CombatEngine({
        regimentType,
        wave: waveDef,
      });
      engineRef.current = nextEngine;
      const initialSnap = nextEngine.getSnapshot();

      pendingActionsRef.current.dodge = false;
      pendingActionsRef.current.skill1 = false;
      pendingActionsRef.current.skill2 = false;

      setSelectedWaveIdx(waveIdx);
      setSelectedRegiment(regimentType);
      setIsPaused(false);
      isPausedRef.current = false;
      setSnapshot(initialSnap);

      logSerialRef.current += 1;
      setLogs([createWaveStartLog(waveIdx, regimentType, logSerialRef.current)]);
      controllerRef.current?.syncState(initialSnap, []);
      controllerRef.current?.setCameraMode(cameraModeRef.current);
    },
    [],
  );

  const dispatchRegimentCommand = useCallback(
    (cmd: RegimentCommand) => {
      const engine = engineRef.current;
      if (!engine || isPausedRef.current) return;
      const accepted = engine.issueRegimentCommand(cmd);
      if (accepted) {
        const snap = engine.getSnapshot();
        setSnapshot(snap);
      }
    },
    [],
  );

  const handleIssueOrder = useCallback(
    (order: RegimentOrder) => {
      const ptr = getPointerOrDefault();
      if (order === 'hold') {
        dispatchRegimentCommand({ type: 'order', order: 'hold', targetX: ptr.x, targetY: ptr.y });
      } else {
        dispatchRegimentCommand({ type: 'order', order });
      }
    },
    [dispatchRegimentCommand, getPointerOrDefault],
  );

  const handleIssueFormation = useCallback(
    (formation: RegimentFormation) => {
      dispatchRegimentCommand({ type: 'formation', formation });
    },
    [dispatchRegimentCommand],
  );

  const handleIssueRegimentSkill = useCallback(() => {
    const ptr = getPointerOrDefault();
    dispatchRegimentCommand({ type: 'skill', targetX: ptr.x, targetY: ptr.y });
  }, [dispatchRegimentCommand, getPointerOrDefault]);

  const handleTriggerDodge = useCallback(() => {
    if (isPausedRef.current) return;
    pendingActionsRef.current.dodge = true;
  }, []);

  const handleTriggerSkill1 = useCallback(() => {
    if (isPausedRef.current) return;
    pendingActionsRef.current.skill1 = true;
  }, []);

  const handleTriggerSkill2 = useCallback(() => {
    if (isPausedRef.current) return;
    pendingActionsRef.current.skill2 = true;
  }, []);

  // Fixed-step 60Hz simulation loop via requestAnimationFrame
  useEffect(() => {
    let rafId = 0;
    let lastTimeMs = performance.now();
    let lastHudSyncMs = lastTimeMs;
    let accumulator = 0;

    const frame = (nowMs: number) => {
      const rawDeltaSec = (nowMs - lastTimeMs) / 1000;
      lastTimeMs = nowMs;

      const engine = engineRef.current;
      if (engine && !isPausedRef.current) {
        const clampedDelta = Math.min(Math.max(rawDeltaSec, 0), 0.1);
        accumulator += clampedDelta;

        let latestSnap: CombatSnapshot | null = null;
        let forceHudSync = false;
        const collectedLogs: CombatLogItem[] = [];

        let steps = 0;
        const maxStepsPerFrame = 5;
        while (accumulator >= FIXED_DT && steps < maxStepsPerFrame) {
          const prevSnap = engine.getSnapshot();
          if (prevSnap.status !== 'running') {
            accumulator = 0;
            break;
          }

          // Compute normalized movement vector from held keys
          const keys = heldKeysRef.current;
          let moveX = 0;
          let moveY = 0;
          if (keys.has('KeyW') || keys.has('ArrowUp')) moveY -= 1;
          if (keys.has('KeyS') || keys.has('ArrowDown')) moveY += 1;
          if (keys.has('KeyA') || keys.has('ArrowLeft')) moveX -= 1;
          if (keys.has('KeyD') || keys.has('ArrowRight')) moveX += 1;
          if (moveX !== 0 && moveY !== 0) {
            const invLen = Math.SQRT1_2;
            moveX *= invLen;
            moveY *= invLen;
          }

          const ptr = getPointerOrDefault();
          const pending = pendingActionsRef.current;

          const input: PlayerInput = {
            moveX,
            moveY,
            aimX: ptr.x,
            aimY: ptr.y,
            attackPressed: ptr.leftDown,
            dodgePressed: pending.dodge,
            skill1Pressed: pending.skill1 || ptr.rightDown,
            skill2Pressed: pending.skill2,
          };

          // Clear edge-triggered latches once consumed
          pending.dodge = false;
          pending.skill1 = false;
          pending.skill2 = false;

          const tickResult = engine.step(FIXED_DT, input);
          latestSnap = tickResult.snapshot;
          controllerRef.current?.syncState(tickResult.snapshot, tickResult.events);

          if (tickResult.snapshot.status !== prevSnap.status) {
            forceHudSync = true;
          }

          if (tickResult.events.length > 0) {
            for (const ev of tickResult.events) {
              if (
                ev.type === 'regiment_command' ||
                ev.type === 'hero_down' ||
                ev.type === 'hero_respawn' ||
                ev.type === 'combat_ended'
              ) {
                forceHudSync = true;
              }
            }
            collectedLogs.push(
              ...convertEventsToLogs(tickResult.events, tickResult.snapshot, () => {
                logSerialRef.current += 1;
                return `log-${logSerialRef.current}`;
              }),
            );
          }

          accumulator -= FIXED_DT;
          steps += 1;
        }

        if (latestSnap && (forceHudSync || nowMs - lastHudSyncMs >= HUD_SYNC_INTERVAL_MS)) {
          lastHudSyncMs = nowMs;
          setSnapshot(latestSnap);
        }
        if (collectedLogs.length > 0) {
          appendLogs(collectedLogs);
        }
      } else {
        accumulator = 0;
      }

      rafId = window.requestAnimationFrame(frame);
    };

    rafId = window.requestAnimationFrame(frame);
    return () => {
      window.cancelAnimationFrame(rafId);
    };
  }, [appendLogs, getPointerOrDefault]);

  // Global keyboard controls
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.isContentEditable)
      ) {
        return;
      }

      const code = event.code;

      // Prevent browser scrolling / focus cycling on Space, Tab & Arrow keys
      if (
        code === 'Space' ||
        code === 'Tab' ||
        code === 'ArrowUp' ||
        code === 'ArrowDown' ||
        code === 'ArrowLeft' ||
        code === 'ArrowRight'
      ) {
        event.preventDefault();
      }

      heldKeysRef.current.add(code);

      if (event.repeat) return;

      if (code === 'Tab') {
        toggleCameraMode();
        return;
      }

      if (code === 'KeyP') {
        setIsPaused((prev) => !prev);
        return;
      }

      if (isPausedRef.current) return;

      if (code === 'Space') {
        pendingActionsRef.current.dodge = true;
      } else if (code === 'KeyQ') {
        pendingActionsRef.current.skill1 = true;
      } else if (code === 'KeyE') {
        pendingActionsRef.current.skill2 = true;
      } else if (code === 'KeyC') {
        dispatchRegimentCommand({ type: 'order', order: 'follow' });
      } else if (code === 'KeyX') {
        const ptr = getPointerOrDefault();
        dispatchRegimentCommand({
          type: 'order',
          order: 'hold',
          targetX: ptr.x,
          targetY: ptr.y,
        });
      } else if (code === 'KeyV') {
        dispatchRegimentCommand({ type: 'order', order: 'engage' });
      } else if (code === 'KeyF') {
        const ptr = getPointerOrDefault();
        dispatchRegimentCommand({
          type: 'skill',
          targetX: ptr.x,
          targetY: ptr.y,
        });
      } else if (code === 'Digit1') {
        dispatchRegimentCommand({ type: 'formation', formation: 'compact' });
      } else if (code === 'Digit2') {
        dispatchRegimentCommand({ type: 'formation', formation: 'spread' });
      }
    };

    const onKeyUp = (event: KeyboardEvent) => {
      heldKeysRef.current.delete(event.code);
    };

    const onBlur = () => {
      heldKeysRef.current.clear();
    };

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
    };
  }, [dispatchRegimentCommand, getPointerOrDefault, toggleCameraMode]);

  const currentWaveDef = PHASE1_WAVES[selectedWaveIdx] ?? PHASE1_WAVES[0];
  const hasNextWave = selectedWaveIdx < PHASE1_WAVES.length - 1;
  const gateHpPct =
    snapshot.gateMaxHp > 0
      ? Math.min(100, Math.max(0, (snapshot.gateHp / snapshot.gateMaxHp) * 100))
      : 0;
  const gateBarColor =
    gateHpPct > 60
      ? 'bg-gradient-to-r from-emerald-500 to-cyan-400'
      : gateHpPct > 30
        ? 'bg-gradient-to-r from-amber-500 to-yellow-400'
        : 'bg-gradient-to-r from-rose-600 to-red-400';

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-2.5 px-3 py-2 lg:px-4">
        {/* Top Bar */}
        <header className="flex flex-wrap items-center justify-between gap-2.5 rounded-xl border border-slate-800 bg-slate-900/95 px-3.5 py-2 shadow-lg">
          {/* Left: Title & Telemetry */}
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg border border-amber-400/40 bg-gradient-to-br from-amber-500/25 to-slate-900 text-amber-300 shadow-inner">
              <Swords className="h-4 w-4" />
            </div>
            <div>
              <h1 className="text-sm font-black tracking-wide text-white">
                戰意守城原型 · 3D (Three.js)
              </h1>
              <div className="flex items-center gap-2 text-[11px] text-slate-400 tabular-nums">
                <span className="font-semibold text-amber-300">W{snapshot.waveNumber}</span>
                <span>·</span>
                <span>
                  殲敵 {snapshot.defeatedEnemies}/{snapshot.totalEnemies}
                </span>
                <span>·</span>
                <span className="inline-flex items-center gap-1 text-slate-300">
                  <Clock className="h-3 w-3 text-slate-400" />
                  {formatElapsed(snapshot.elapsedSec)}
                </span>
              </div>
            </div>
          </div>

          {/* Center: Prominent Village Gate HP Bar */}
          <div className="flex min-w-[200px] flex-1 max-w-sm flex-col gap-1">
            <div className="flex items-center justify-between text-xs tabular-nums">
              <span className="inline-flex items-center gap-1.5 font-bold text-slate-200">
                <Castle className="h-3.5 w-3.5 text-cyan-400" />
                城門耐久
              </span>
              <span
                className={`font-bold ${
                  gateHpPct <= 30
                    ? 'text-rose-400'
                    : gateHpPct <= 60
                      ? 'text-amber-300'
                      : 'text-emerald-300'
                }`}
              >
                {Math.max(0, Math.ceil(snapshot.gateHp))} / {snapshot.gateMaxHp}
              </span>
            </div>
            <div className="h-2.5 w-full overflow-hidden rounded-full bg-slate-950 ring-1 ring-inset ring-slate-700/80">
              <div
                className={`h-full transition-all duration-150 ${gateBarColor}`}
                style={{ width: `${gateHpPct}%` }}
              />
            </div>
          </div>

          {/* Right: Regiment Switcher + Wave Selector + Pause/Restart */}
          <div className="flex flex-wrap items-center gap-2">
            {/* Regiment Switcher */}
            <div
              className="flex items-center rounded-lg border border-slate-700/80 bg-slate-950 p-0.5"
              role="group"
              aria-label="兵團切換"
            >
              {REGIMENT_SWITCHER_OPTIONS.map((opt) => {
                const active = opt.type === selectedRegiment;
                return (
                  <button
                    key={opt.type}
                    type="button"
                    onClick={() => startWave(selectedWaveIdx, opt.type)}
                    className={`cursor-pointer rounded-md px-2 py-1 text-xs font-semibold transition-colors ${
                      active
                        ? 'bg-cyan-500/20 text-cyan-200 ring-1 ring-inset ring-cyan-400/50'
                        : 'text-slate-400 hover:bg-slate-800/80 hover:text-slate-200'
                    }`}
                  >
                    <span className="mr-1" aria-hidden="true">
                      {opt.emoji}
                    </span>
                    {opt.shortLabel}
                  </button>
                );
              })}
            </div>

            {/* Wave Selector */}
            <div
              className="flex items-center rounded-lg border border-slate-700/80 bg-slate-950 p-0.5"
              role="group"
              aria-label="波次選擇"
            >
              {PHASE1_WAVES.map((wave, idx) => {
                const active = idx === selectedWaveIdx;
                return (
                  <button
                    key={wave.waveNumber}
                    type="button"
                    onClick={() => startWave(idx, selectedRegiment)}
                    className={`cursor-pointer rounded-md px-2 py-1 text-xs font-semibold transition-colors ${
                      active
                        ? 'bg-amber-500/20 text-amber-200 ring-1 ring-inset ring-amber-400/50'
                        : 'text-slate-400 hover:bg-slate-800/80 hover:text-slate-200'
                    }`}
                  >
                    W{wave.waveNumber}
                  </button>
                );
              })}
            </div>

            {/* Camera Mode Toggle (Tab) */}
            <button
              type="button"
              onClick={toggleCameraMode}
              title="切換視角：3D 俯視 / 肩後 TPS (Tab)"
              className={`inline-flex cursor-pointer items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs font-semibold transition ${
                cameraMode === 'tps'
                  ? 'border-indigo-400/60 bg-indigo-500/20 text-indigo-200 hover:bg-indigo-500/30'
                  : 'border-cyan-500/40 bg-cyan-950/50 text-cyan-200 hover:border-cyan-400/60 hover:bg-cyan-900/50'
              }`}
            >
              <span aria-hidden="true">🎥</span>
              <span>{cameraMode === 'tactical' ? '3D 俯視' : '肩後 TPS'}</span>
              <kbd className="rounded bg-slate-950/70 px-1 py-0.5 font-mono text-[10px] text-slate-300">
                Tab
              </kbd>
            </button>

            {/* Pause / Resume (P) */}
            <button
              type="button"
              onClick={() => setIsPaused((prev) => !prev)}
              disabled={snapshot.status !== 'running'}
              title="暫停 / 繼續 (P)"
              className="inline-flex cursor-pointer items-center gap-1 rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs font-semibold text-slate-100 transition hover:border-slate-500 hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isPaused ? (
                <>
                  <Play className="h-3.5 w-3.5 text-emerald-400" />
                  繼續
                </>
              ) : (
                <>
                  <Pause className="h-3.5 w-3.5 text-amber-300" />
                  暫停
                </>
              )}
            </button>

            {/* Restart */}
            <button
              type="button"
              onClick={() => startWave(selectedWaveIdx, selectedRegiment)}
              title="重新開始本波"
              className="inline-flex cursor-pointer items-center gap-1 rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs font-semibold text-slate-200 transition hover:border-slate-500 hover:bg-slate-700"
            >
              <RotateCcw className="h-3.5 w-3.5" />
              重開
            </button>
          </div>
        </header>

        {/* Center Primary Stage: Canvas + Compact Right Sidebar */}
        <main className="grid grid-cols-1 gap-2.5 lg:grid-cols-[minmax(0,1fr)_310px] xl:grid-cols-[minmax(0,1fr)_330px]">
          <div className="relative">
            <BattlefieldCanvas
              initialSnapshot={snapshot}
              controllerRef={controllerRef}
              cameraMode={cameraMode}
            />

            {/* Pause Overlay */}
            {isPaused && snapshot.status === 'running' && (
              <div className="pointer-events-none absolute inset-0 flex items-center justify-center rounded-xl bg-slate-950/40 backdrop-blur-[1px]">
                <div className="flex items-center gap-2 rounded-full border border-amber-400/50 bg-slate-900/95 px-4 py-1.5 text-sm font-bold text-amber-200 shadow-xl">
                  <Pause className="h-4 w-4 text-amber-400" />
                  戰鬥暫停中 · 按 P 繼續
                </div>
              </div>
            )}

            {/* Victory / Defeat Modal Overlay */}
            {snapshot.status !== 'running' && (
              <div className="absolute inset-0 z-20 flex items-center justify-center rounded-xl bg-slate-950/80 p-4 backdrop-blur-sm">
                <div
                  className={`w-full max-w-md rounded-2xl border bg-slate-900/95 p-5 shadow-2xl ${
                    snapshot.status === 'victory'
                      ? 'border-emerald-400/60'
                      : 'border-rose-500/60'
                  }`}
                >
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2.5">
                      {snapshot.status === 'victory' ? (
                        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-500/20 text-emerald-300 ring-1 ring-emerald-400/40">
                          <Trophy className="h-5 w-5" />
                        </div>
                      ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-rose-500/20 text-rose-300 ring-1 ring-rose-400/40">
                          <Skull className="h-5 w-5" />
                        </div>
                      )}
                      <div>
                        <h2
                          className={`text-lg font-black tracking-wide ${
                            snapshot.status === 'victory'
                              ? 'text-emerald-300'
                              : 'text-rose-300'
                          }`}
                        >
                          {snapshot.status === 'victory' ? '守城成功！' : '城門失守'}
                        </h2>
                        <p className="text-xs text-slate-400">
                          第 {currentWaveDef.waveNumber} 波 · {currentWaveDef.name}（耗時{' '}
                          {formatElapsed(snapshot.elapsedSec)}）
                        </p>
                      </div>
                    </div>

                    <div className="text-right tabular-nums">
                      <div className="flex items-center justify-end gap-1 text-xs text-slate-400">
                        <ShieldCheck className="h-3.5 w-3.5 text-cyan-400" />
                        城門剩餘
                      </div>
                      <div className="text-sm font-bold text-white">
                        {Math.max(0, Math.ceil(snapshot.gateHp))} / {snapshot.gateMaxHp}
                      </div>
                    </div>
                  </div>

                  {/* Battle Summary Grid */}
                  <div className="mt-4 grid grid-cols-3 gap-2 rounded-xl border border-slate-800 bg-slate-950/75 p-3 text-center tabular-nums">
                    <div className="rounded-lg bg-slate-900/80 p-2">
                      <div className="text-[11px] text-slate-400">武將擊殺</div>
                      <div className="mt-0.5 text-base font-black text-cyan-300">
                        {snapshot.hero.kills}
                      </div>
                    </div>
                    <div className="rounded-lg bg-slate-900/80 p-2">
                      <div className="text-[11px] text-slate-400">武將總輸出</div>
                      <div className="mt-0.5 text-base font-black text-amber-300">
                        {Math.round(snapshot.hero.damageDealt)}
                      </div>
                    </div>
                    <div className="rounded-lg bg-slate-900/80 p-2">
                      <div className="inline-flex items-center gap-1 text-[11px] text-slate-400">
                        <Users className="h-3 w-3" />
                        兵團生還
                      </div>
                      <div className="mt-0.5 text-base font-black text-emerald-300">
                        {snapshot.regiment.aliveCount} / {snapshot.regiment.maxCount}
                      </div>
                    </div>
                  </div>

                  {/* Action Buttons */}
                  <div className="mt-4 flex items-center justify-end gap-2">
                    <button
                      type="button"
                      onClick={() => startWave(selectedWaveIdx, selectedRegiment)}
                      className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-slate-700 bg-slate-800 px-3.5 py-2 text-xs font-bold text-slate-100 transition hover:border-slate-500 hover:bg-slate-700"
                    >
                      <RotateCcw className="h-3.5 w-3.5" />
                      重試本波
                    </button>

                    {snapshot.status === 'victory' && hasNextWave && (
                      <button
                        type="button"
                        onClick={() => startWave(selectedWaveIdx + 1, selectedRegiment)}
                        className="inline-flex cursor-pointer items-center gap-1 rounded-lg border border-emerald-400/60 bg-emerald-600 px-4 py-2 text-xs font-bold text-white shadow-lg transition hover:bg-emerald-500"
                      >
                        下一波
                        <ChevronRight className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Right Narrow Sidebar */}
          <div className="min-h-[320px] lg:max-h-[600px]">
            <SideIntelPanel
              waveDef={currentWaveDef}
              totalEnemies={snapshot.totalEnemies}
              defeatedEnemies={snapshot.defeatedEnemies}
              enemies={snapshot.enemies}
              logs={logs}
            />
          </div>
        </main>

        {/* Bottom Action & Command Dock (2 balanced panels) */}
        <footer className="grid grid-cols-1 gap-2.5 lg:grid-cols-2">
          <HeroHud
            hero={snapshot.hero}
            disabled={snapshot.status !== 'running' || isPaused}
            onTriggerDodge={handleTriggerDodge}
            onTriggerSkill1={handleTriggerSkill1}
            onTriggerSkill2={handleTriggerSkill2}
          />
          <RegimentHud
            regiment={snapshot.regiment}
            disabled={snapshot.status !== 'running' || isPaused}
            onIssueOrder={handleIssueOrder}
            onIssueFormation={handleIssueFormation}
            onIssueSkill={handleIssueRegimentSkill}
          />
        </footer>
      </div>
    </div>
  );
}
