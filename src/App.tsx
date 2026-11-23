import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Castle,
  ChevronRight,
  Clock,
  FastForward,
  Pause,
  Play,
  RotateCcw,
  ShieldCheck,
  Skull,
  Swords,
  Trophy,
} from 'lucide-react';
import { CombatEngine } from './core/combat/CombatEngine';
import {
  ENEMY_DEFINITIONS,
  PHASE1_WAVES,
  STANCE_MODIFIERS,
} from './core/combat/presets';
import type {
  CombatEvent,
  CombatSnapshot,
  TacticalStance,
} from './core/types/combat';
import type { BattlefieldController } from './game/BattlefieldController';
import { BattlefieldCanvas } from './ui/BattlefieldCanvas';
import { SquadPanel } from './ui/SquadPanel';
import { StanceBar } from './ui/StanceBar';
import { WaveIntelPanel } from './ui/WaveIntelPanel';
import type { CombatLogItem } from './ui/WaveIntelPanel';

const FIXED_DT = 1 / 30;
const MAX_LOG_ITEMS = 60;

function formatElapsed(sec: number): string {
  const clamped = Math.max(0, sec);
  const mins = Math.floor(clamped / 60);
  const rem = clamped - mins * 60;
  return `${String(mins).padStart(2, '0')}:${rem.toFixed(1).padStart(4, '0')}`;
}

function createWaveStartLog(waveIdx: number, serial: number): CombatLogItem {
  const wave = PHASE1_WAVES[waveIdx];
  return {
    id: `log-start-${serial}`,
    timeSec: 0,
    kind: 'system',
    message: `第 ${wave.waveNumber} 波【${wave.name}】開始，共 ${wave.spawns.length} 名敵軍逼近防線。`,
  };
}

function convertEventsToLogs(
  events: CombatEvent[],
  snapshot: CombatSnapshot,
  nextId: () => string,
): CombatLogItem[] {
  const items: CombatLogItem[] = [];

  for (const ev of events) {
    switch (ev.type) {
      case 'stance_changed':
        items.push({
          id: nextId(),
          timeSec: ev.timeSec,
          kind: 'stance',
          message: `切換陣型：${STANCE_MODIFIERS[ev.previousStance].label} → ${STANCE_MODIFIERS[ev.nextStance].label}`,
        });
        break;

      case 'skill_cast':
        items.push({
          id: nextId(),
          timeSec: ev.timeSec,
          kind: 'skill',
          message: `${ev.heroName} 發動【${ev.skillName}】`,
        });
        break;

      case 'gate_hit':
        items.push({
          id: nextId(),
          timeSec: ev.timeSec,
          kind: 'gate_hit',
          message: `城門受擊 -${ev.amount}（剩餘 ${Math.max(0, Math.ceil(ev.gateHpRemaining))} HP）`,
        });
        break;

      case 'enemy_spawned':
        if (ev.isElite || ev.archetype === 'bomber') {
          const enemyName = ENEMY_DEFINITIONS[ev.archetype].name;
          items.push({
            id: nextId(),
            timeSec: ev.timeSec,
            kind: 'spawn',
            message: ev.isElite
              ? `菁英警告：【${enemyName}】進入戰場！`
              : `危險目標：【${enemyName}】逼近中，注意範圍自爆！`,
          });
        }
        break;

      case 'unit_died':
        if (ev.team === 'hero') {
          const hero = snapshot.heroes.find((h) => h.id === ev.unitId);
          items.push({
            id: nextId(),
            timeSec: ev.timeSec,
            kind: 'gate_hit',
            message: `${hero ? hero.name : '小隊成員'} 生命歸零退場！`,
          });
        } else if (ev.unitId.includes('brute')) {
          items.push({
            id: nextId(),
            timeSec: ev.timeSec,
            kind: 'death',
            message: '成功擊破菁英【獸人狂戰士】！',
          });
        }
        break;

      case 'combat_ended':
        items.push({
          id: nextId(),
          timeSec: ev.timeSec,
          kind: ev.status === 'victory' ? 'death' : 'gate_hit',
          message:
            ev.status === 'victory'
              ? `守衛成功！全數擊破敵軍，城門剩餘 ${Math.ceil(ev.gateHpRemaining)} HP。`
              : '防線失守，本波守衛失敗。',
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
  const [isPaused, setIsPaused] = useState(false);
  const [speedMultiplier, setSpeedMultiplier] = useState<1 | 2>(1);

  const engineRef = useRef<CombatEngine | null>(null);
  if (engineRef.current === null) {
    engineRef.current = new CombatEngine({ wave: PHASE1_WAVES[0] });
  }

  const controllerRef = useRef<BattlefieldController | null>(null);
  const isPausedRef = useRef(isPaused);
  const speedRef = useRef<1 | 2>(speedMultiplier);
  const logSerialRef = useRef(1);

  const [snapshot, setSnapshot] = useState<CombatSnapshot>(() =>
    engineRef.current!.getSnapshot(),
  );
  const [logs, setLogs] = useState<CombatLogItem[]>(() => [
    createWaveStartLog(0, 0),
  ]);

  useEffect(() => {
    isPausedRef.current = isPaused;
  }, [isPaused]);

  useEffect(() => {
    speedRef.current = speedMultiplier;
  }, [speedMultiplier]);

  const appendLogs = useCallback((newItems: CombatLogItem[]) => {
    if (newItems.length === 0) return;
    setLogs((prev) => [...newItems.reverse(), ...prev].slice(0, MAX_LOG_ITEMS));
  }, []);

  const resetWave = useCallback((waveIdx: number) => {
    const waveDef = PHASE1_WAVES[waveIdx] ?? PHASE1_WAVES[0];
    const nextEngine = new CombatEngine({ wave: waveDef });
    engineRef.current = nextEngine;
    const initialSnap = nextEngine.getSnapshot();

    setSelectedWaveIdx(waveIdx);
    setIsPaused(false);
    isPausedRef.current = false;
    setSnapshot(initialSnap);

    logSerialRef.current += 1;
    setLogs([createWaveStartLog(waveIdx, logSerialRef.current)]);
    controllerRef.current?.syncState(initialSnap, []);
  }, []);

  const handleSelectStance = useCallback(
    (stance: TacticalStance) => {
      const engine = engineRef.current;
      if (!engine) return;

      const result = engine.setStance(stance);
      if (!result.accepted) return;

      const nextSnap = engine.getSnapshot();
      const events = result.event ? [result.event] : [];
      controllerRef.current?.syncState(nextSnap, events);
      setSnapshot(nextSnap);

      const newItems = convertEventsToLogs(events, nextSnap, () => {
        logSerialRef.current += 1;
        return `log-${logSerialRef.current}`;
      });
      appendLogs(newItems);
    },
    [appendLogs],
  );

  // Fixed-step simulation loop (FIXED_DT = 1/30) via requestAnimationFrame
  useEffect(() => {
    let rafId = 0;
    let lastTimeMs = performance.now();
    let accumulator = 0;

    const frame = (nowMs: number) => {
      const rawDeltaSec = (nowMs - lastTimeMs) / 1000;
      lastTimeMs = nowMs;

      const engine = engineRef.current;
      if (engine && !isPausedRef.current) {
        const clampedDelta = Math.min(Math.max(rawDeltaSec, 0), 0.1);
        accumulator += clampedDelta * speedRef.current;

        let latestSnap: CombatSnapshot | null = null;
        const collectedLogs: CombatLogItem[] = [];

        let steps = 0;
        const maxStepsPerFrame = 6;
        while (accumulator >= FIXED_DT && steps < maxStepsPerFrame) {
          const current = engine.getSnapshot();
          if (current.status !== 'running') {
            accumulator = 0;
            break;
          }

          const tickResult = engine.step(FIXED_DT);
          latestSnap = tickResult.snapshot;
          controllerRef.current?.syncState(tickResult.snapshot, tickResult.events);

          if (tickResult.events.length > 0) {
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

        if (latestSnap) {
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
  }, [appendLogs]);

  // Global keyboard shortcuts: 1/2/3 stance, Space pause
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

      if (event.key === '1') {
        handleSelectStance('defense');
      } else if (event.key === '2') {
        handleSelectStance('assault');
      } else if (event.key === '3') {
        handleSelectStance('scatter');
      } else if (event.code === 'Space') {
        event.preventDefault();
        setIsPaused((prev) => !prev);
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleSelectStance]);

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
      <div className="mx-auto flex max-w-[1440px] flex-col gap-3 px-3 py-2.5 lg:px-4">
        {/* Top Header */}
        <header className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-900/90 px-3.5 py-2 shadow-lg">
          {/* Left: Game Title & Wave Progress */}
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg border border-amber-400/40 bg-gradient-to-br from-amber-500/25 to-slate-900 text-amber-300 shadow-inner">
                <Swords className="h-4 w-4" />
              </div>
              <div>
                <h1 className="text-sm font-black tracking-wide text-white">
                  守村戰術原型 · Phase 1
                </h1>
                <div className="flex items-center gap-2 text-[11px] text-slate-400 tabular-nums">
                  <span className="font-semibold text-amber-300">
                    波次 {snapshot.wave.waveNumber}
                  </span>
                  <span>·</span>
                  <span>
                    已擊破 {snapshot.wave.defeatedEnemies}/{snapshot.wave.totalEnemies}
                  </span>
                  <span>·</span>
                  <span className="inline-flex items-center gap-1 text-slate-300">
                    <Clock className="h-3 w-3 text-slate-400" />
                    {formatElapsed(snapshot.elapsedSec)}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Center: Prominent Village Gate HP Bar */}
          <div className="flex min-w-[230px] flex-1 max-w-md flex-col gap-1">
            <div className="flex items-center justify-between text-xs tabular-nums">
              <span className="inline-flex items-center gap-1.5 font-bold text-slate-200">
                <Castle className="h-3.5 w-3.5 text-cyan-400" />
                村莊城門耐久
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

          {/* Right: Wave Selector & Playback Controls */}
          <div className="flex flex-wrap items-center gap-2">
            {/* Wave 1 / 2 / 3 Selector */}
            <div
              className="flex items-center rounded-lg border border-slate-700/80 bg-slate-950 p-0.5"
              role="group"
              aria-label="波次選擇"
            >
              {PHASE1_WAVES.map((wave, idx) => {
                const active = idx === selectedWaveIdx;
                return (
                  <button
                    key={wave.id}
                    type="button"
                    onClick={() => resetWave(idx)}
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

            {/* Pause / Resume */}
            <button
              type="button"
              onClick={() => setIsPaused((prev) => !prev)}
              disabled={snapshot.status !== 'running'}
              title="暫停 / 繼續 (Space)"
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

            {/* 1x / 2x Speed Toggle */}
            <button
              type="button"
              onClick={() => setSpeedMultiplier((prev) => (prev === 1 ? 2 : 1))}
              title="切換戰鬥倍速"
              className={`inline-flex cursor-pointer items-center gap-1 rounded-lg border px-2.5 py-1.5 text-xs font-bold tabular-nums transition ${
                speedMultiplier === 2
                  ? 'border-cyan-400/70 bg-cyan-950/70 text-cyan-200'
                  : 'border-slate-700 bg-slate-800/90 text-slate-200 hover:border-slate-500 hover:bg-slate-700'
              }`}
            >
              <FastForward className="h-3.5 w-3.5" />
              {speedMultiplier}x
            </button>

            {/* Restart Wave */}
            <button
              type="button"
              onClick={() => resetWave(selectedWaveIdx)}
              title="重新開始本波"
              className="inline-flex cursor-pointer items-center gap-1 rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs font-semibold text-slate-200 transition hover:border-slate-500 hover:bg-slate-700"
            >
              <RotateCcw className="h-3.5 w-3.5" />
              重開
            </button>
          </div>
        </header>

        {/* Main Stage (2-column on lg) */}
        <main className="grid grid-cols-1 gap-3 lg:grid-cols-[minmax(0,1fr)_350px] xl:grid-cols-[minmax(0,1fr)_380px]">
          {/* Left / Center Primary Column: Battlefield + Stance Bar */}
          <div className="flex flex-col gap-2.5">
            <div className="relative">
              <BattlefieldCanvas
                initialSnapshot={snapshot}
                controllerRef={controllerRef}
              />

              {/* Pause Pill Indicator */}
              {isPaused && snapshot.status === 'running' && (
                <div className="pointer-events-none absolute inset-0 flex items-center justify-center rounded-xl bg-slate-950/35 backdrop-blur-[1px]">
                  <div className="flex items-center gap-2 rounded-full border border-amber-400/50 bg-slate-900/95 px-4 py-1.5 text-sm font-bold text-amber-200 shadow-xl">
                    <Pause className="h-4 w-4 text-amber-400" />
                    戰鬥暫停中 · 按 Space 繼續
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
                    <div className="flex items-center justify-between">
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
                            {snapshot.status === 'victory'
                              ? '防線守衛成功！'
                              : '防線失守'}
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

                    {/* Hero Damage / Healing Summary */}
                    <div className="mt-4 space-y-1.5 rounded-xl border border-slate-800 bg-slate-950/75 p-3">
                      <div className="flex items-center justify-between text-[11px] font-semibold text-slate-400">
                        <span>小隊戰績結算</span>
                        <span>輸出 / 治療 / 擊殺</span>
                      </div>
                      {snapshot.heroes.map((hero) => (
                        <div
                          key={hero.id}
                          className="flex items-center justify-between text-xs tabular-nums"
                        >
                          <span className="font-semibold text-slate-200">
                            {hero.name}
                            <span className="ml-1.5 text-[10px] text-slate-500">
                              {hero.title}
                            </span>
                          </span>
                          <span className="text-slate-300">
                            <span className="text-amber-300">
                              {Math.round(hero.stats.damageDealt)}
                            </span>
                            {' / '}
                            <span className="text-emerald-300">
                              {Math.round(hero.stats.healingDone)}
                            </span>
                            {' / '}
                            <span className="text-cyan-300">{hero.stats.kills}</span>
                          </span>
                        </div>
                      ))}
                    </div>

                    {/* Action Buttons */}
                    <div className="mt-4 flex items-center justify-end gap-2">
                      <button
                        type="button"
                        onClick={() => resetWave(selectedWaveIdx)}
                        className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-slate-700 bg-slate-800 px-3.5 py-2 text-xs font-bold text-slate-100 transition hover:border-slate-500 hover:bg-slate-700"
                      >
                        <RotateCcw className="h-3.5 w-3.5" />
                        重試本波
                      </button>

                      {snapshot.status === 'victory' && hasNextWave && (
                        <button
                          type="button"
                          onClick={() => resetWave(selectedWaveIdx + 1)}
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

            {/* Tactical Stance Control Bar */}
            <StanceBar
              currentStance={snapshot.stance}
              cooldownRemainingSec={snapshot.stanceCooldownRemainingSec}
              cooldownSec={snapshot.stanceCooldownSec}
              disabled={snapshot.status !== 'running'}
              onSelectStance={handleSelectStance}
            />
          </div>

          {/* Right Sidebar: Wave Intel & Live Combat Log */}
          <div className="min-h-[360px] lg:max-h-[640px]">
            <WaveIntelPanel
              waveDef={currentWaveDef}
              waveProgress={snapshot.wave}
              enemies={snapshot.enemies}
              logs={logs}
            />
          </div>
        </main>

        {/* Bottom Strip: 3-Hero Squad Panel */}
        <SquadPanel heroes={snapshot.heroes} elapsedSec={snapshot.elapsedSec} />
      </div>
    </div>
  );
}
