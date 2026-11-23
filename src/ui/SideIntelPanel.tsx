import { AlertTriangle, Keyboard, ScrollText, Skull } from 'lucide-react';
import { ENEMY_DEFINITIONS } from '../core/combat/presets';
import type { EnemyState, EnemyUnitType, WaveDefinition } from '../core/types/combat';

export interface CombatLogItem {
  id: string;
  timeSec: number;
  kind: 'command' | 'skill' | 'danger' | 'victory' | 'system';
  message: string;
}

export interface SideIntelPanelProps {
  waveDef: WaveDefinition;
  totalEnemies: number;
  defeatedEnemies: number;
  enemies: EnemyState[];
  logs: CombatLogItem[];
}

const LOG_STYLES: Record<CombatLogItem['kind'], string> = {
  command: 'border-cyan-500/40 bg-cyan-950/30 text-cyan-200',
  skill: 'border-amber-500/40 bg-amber-950/30 text-amber-200',
  danger: 'border-rose-500/50 bg-rose-950/40 text-rose-200',
  victory: 'border-emerald-500/40 bg-emerald-950/30 text-emerald-200',
  system: 'border-slate-700/70 bg-slate-900/70 text-slate-300',
};

const CONTROL_HINTS: Array<{ key: string; label: string; spanFull?: boolean }> = [
  { key: 'WASD', label: '移動' },
  { key: 'LMB', label: '三連斬' },
  { key: 'Space', label: '翻滾' },
  { key: 'RMB / Q', label: '破陣衝鋒' },
  { key: 'E', label: '戰意咆哮' },
  { key: 'C / X / V', label: '兵團指令' },
  { key: 'F', label: '兵團特技' },
  { key: '1 / 2', label: '切換陣型' },
  { key: 'Tab', label: '切換 3D 俯視 / TPS 視角', spanFull: true },
];

function formatTime(sec: number): string {
  const s = Math.max(0, sec);
  const mins = Math.floor(s / 60);
  const rem = s - mins * 60;
  return `${String(mins).padStart(2, '0')}:${rem.toFixed(0).padStart(2, '0')}`;
}

export function SideIntelPanel({
  waveDef,
  totalEnemies,
  defeatedEnemies,
  enemies,
  logs,
}: SideIntelPanelProps) {
  // Aggregate enemy roster from wave definition
  const rosterCounts = new Map<EnemyUnitType, { name: string; total: number; isCommander: boolean }>();
  for (const spawn of waveDef.spawns) {
    const def = ENEMY_DEFINITIONS[spawn.type];
    const existing = rosterCounts.get(spawn.type);
    if (existing) {
      existing.total += spawn.count;
    } else {
      rosterCounts.set(spawn.type, {
        name: spawn.customName ?? def.name,
        total: spawn.count,
        isCommander: def.isCommander,
      });
    }
  }

  const aliveByType = new Map<EnemyUnitType, number>();
  let activeCommander: EnemyState | undefined;
  for (const enemy of enemies) {
    if (!enemy.alive) continue;
    aliveByType.set(enemy.type, (aliveByType.get(enemy.type) ?? 0) + 1);
    if (enemy.isCommander) {
      activeCommander = enemy;
    }
  }

  const commanderSpawn = waveDef.spawns.find((s) => s.type === 'enemy_commander');
  const progressPct =
    totalEnemies > 0 ? Math.min(100, Math.max(0, (defeatedEnemies / totalEnemies) * 100)) : 0;

  return (
    <aside className="flex h-full flex-col gap-2.5 rounded-xl border border-slate-800 bg-slate-900/90 p-3 shadow-lg">
      {/* Section 1: Wave Intel */}
      <div className="space-y-2 border-b border-slate-800 pb-2.5">
        <div className="flex items-center justify-between gap-2">
          <div className="min-w-0">
            <div className="text-[10px] font-bold uppercase tracking-wider text-amber-400">
              波次情報 · WAVE {waveDef.waveNumber}
            </div>
            <h2 className="truncate text-sm font-black text-white">{waveDef.name}</h2>
          </div>
          <span className="shrink-0 rounded-md border border-slate-700 bg-slate-950 px-2 py-0.5 text-xs font-bold text-slate-200 tabular-nums">
            {defeatedEnemies}/{totalEnemies}
          </span>
        </div>

        <p className="text-[11px] leading-relaxed text-slate-400">{waveDef.description}</p>

        {/* Wave Progress Bar */}
        <div className="h-1.5 w-full overflow-hidden rounded-full bg-slate-950 ring-1 ring-inset ring-slate-800">
          <div
            className="h-full bg-gradient-to-r from-amber-500 to-emerald-400 transition-all duration-150"
            style={{ width: `${progressPct}%` }}
          />
        </div>

        {/* Commander Warning Badge */}
        {commanderSpawn && (
          <div
            className={`flex items-center justify-between gap-2 rounded-lg border px-2.5 py-1.5 text-[11px] ${
              activeCommander
                ? 'border-rose-500/70 bg-rose-950/60 text-rose-200 animate-pulse'
                : 'border-amber-500/40 bg-amber-950/30 text-amber-200'
            }`}
          >
            <span className="inline-flex items-center gap-1.5 font-bold">
              {activeCommander ? (
                <Skull className="h-3.5 w-3.5 text-rose-400" />
              ) : (
                <AlertTriangle className="h-3.5 w-3.5 text-amber-400" />
              )}
              {activeCommander
                ? `敵將接戰：${activeCommander.name}`
                : `敵將預警：${commanderSpawn.customName ?? '敵方武將'}`}
            </span>
            {activeCommander && (
              <span className="font-bold text-rose-300 tabular-nums">
                {Math.ceil(activeCommander.hp)} HP
              </span>
            )}
          </div>
        )}

        {/* Enemy Roster Counts */}
        <div className="grid grid-cols-2 gap-1.5 pt-0.5">
          {Array.from(rosterCounts.entries()).map(([type, info]) => {
            const onField = aliveByType.get(type) ?? 0;
            return (
              <div
                key={type}
                className={`flex items-center justify-between rounded-md border px-2 py-1 text-[11px] ${
                  info.isCommander
                    ? 'border-rose-500/40 bg-rose-950/25 text-rose-200'
                    : 'border-slate-800 bg-slate-950/75 text-slate-300'
                }`}
              >
                <span className="truncate font-semibold">{info.name}</span>
                <span className="ml-1 shrink-0 tabular-nums text-[10px] text-slate-400">
                  {onField > 0 ? (
                    <strong className="text-amber-300">{onField}</strong>
                  ) : (
                    <span>0</span>
                  )}
                  /{info.total}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Section 2: Quick Controls Cheatsheet */}
      <div className="space-y-1.5 border-b border-slate-800 pb-2.5">
        <div className="flex items-center gap-1.5 text-[11px] font-bold text-slate-300">
          <Keyboard className="h-3.5 w-3.5 text-cyan-400" />
          快捷鍵總覽
        </div>
        <div className="grid grid-cols-2 gap-1 text-[10px]">
          {CONTROL_HINTS.map((hint) => (
            <div
              key={hint.key}
              className={`flex items-center justify-between rounded bg-slate-950/80 px-2 py-1 ring-1 ring-inset ring-slate-800/80 ${
                hint.spanFull ? 'col-span-2' : ''
              }`}
            >
              <kbd className="font-mono font-bold text-cyan-300">{hint.key}</kbd>
              <span className="text-slate-300">{hint.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Section 3: Compact Live Combat Log */}
      <div className="flex min-h-0 flex-1 flex-col gap-1.5">
        <div className="flex items-center justify-between text-[11px] font-bold text-slate-300">
          <span className="inline-flex items-center gap-1.5">
            <ScrollText className="h-3.5 w-3.5 text-amber-400" />
            即時戰報
          </span>
          <span className="text-[10px] font-normal text-slate-500">按 P 暫停</span>
        </div>

        <div className="tactical-scroll flex-1 space-y-1 overflow-y-auto pr-1">
          {logs.map((item) => (
            <div
              key={item.id}
              className={`rounded-md border px-2 py-1 text-[11px] leading-snug ${LOG_STYLES[item.kind]}`}
            >
              <span className="mr-1.5 font-mono text-[10px] opacity-70 tabular-nums">
                [{formatTime(item.timeSec)}]
              </span>
              <span>{item.message}</span>
            </div>
          ))}
        </div>
      </div>
    </aside>
  );
}
