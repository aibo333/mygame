import {
  AlertTriangle,
  Compass,
  Flame,
  Info,
  ScrollText,
  ShieldAlert,
  Sparkles,
  Swords,
} from 'lucide-react';
import { ENEMY_DEFINITIONS } from '../core/combat/presets';
import type {
  EnemyArchetype,
  EnemyState,
  WaveDefinition,
  WaveProgressSnapshot,
} from '../core/types/combat';

export type CombatLogKind =
  | 'stance'
  | 'skill'
  | 'gate_hit'
  | 'spawn'
  | 'death'
  | 'system';

export interface CombatLogItem {
  id: string;
  timeSec: number;
  kind: CombatLogKind;
  message: string;
}

export interface WaveIntelPanelProps {
  waveDef: WaveDefinition;
  waveProgress: WaveProgressSnapshot;
  enemies: EnemyState[];
  logs: CombatLogItem[];
}

function formatTime(sec: number): string {
  const clamped = Math.max(0, sec);
  const mins = Math.floor(clamped / 60);
  const rem = clamped - mins * 60;
  return `${String(mins).padStart(2, '0')}:${rem.toFixed(1).padStart(4, '0')}`;
}

const LOG_STYLE: Record<CombatLogKind, { badge: string; label: string }> = {
  stance: {
    badge: 'bg-amber-500/20 text-amber-300 border-amber-400/30',
    label: '戰術',
  },
  skill: {
    badge: 'bg-cyan-500/20 text-cyan-300 border-cyan-400/30',
    label: '技能',
  },
  gate_hit: {
    badge: 'bg-rose-500/25 text-rose-200 border-rose-400/40',
    label: '城門',
  },
  spawn: {
    badge: 'bg-violet-500/20 text-violet-300 border-violet-400/30',
    label: '來襲',
  },
  death: {
    badge: 'bg-emerald-500/20 text-emerald-300 border-emerald-400/30',
    label: '擊破',
  },
  system: {
    badge: 'bg-slate-700/60 text-slate-200 border-slate-600/50',
    label: '系統',
  },
};

export function WaveIntelPanel({
  waveDef,
  waveProgress,
  enemies,
  logs,
}: WaveIntelPanelProps) {
  // Build transparent enemy roster breakdown from waveDef.spawns
  const countsByArchetype = new Map<EnemyArchetype, number>();
  for (const spawn of waveDef.spawns) {
    countsByArchetype.set(
      spawn.archetype,
      (countsByArchetype.get(spawn.archetype) ?? 0) + 1,
    );
  }

  const aliveByArchetype = new Map<EnemyArchetype, number>();
  for (const enemy of enemies) {
    if (!enemy.alive) continue;
    aliveByArchetype.set(
      enemy.archetype,
      (aliveByArchetype.get(enemy.archetype) ?? 0) + 1,
    );
  }

  const rosterEntries = Array.from(countsByArchetype.entries()).map(
    ([archetype, totalCount]) => ({
      def: ENEMY_DEFINITIONS[archetype],
      totalCount,
      aliveCount: aliveByArchetype.get(archetype) ?? 0,
    }),
  );

  return (
    <aside
      className="flex h-full flex-col gap-2.5 rounded-xl border border-slate-800 bg-slate-900/90 p-3 shadow-lg"
      aria-label="波次情報與即時戰鬥日誌"
    >
      {/* Wave Info Header */}
      <div className="border-b border-slate-800 pb-2">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-1.5">
            <Compass className="h-4 w-4 text-amber-400" />
            <h2 className="text-sm font-bold text-white">
              第 {waveDef.waveNumber} 波 · {waveDef.name}
            </h2>
          </div>
          <span className="rounded bg-slate-800 px-1.5 py-0.5 text-[10px] font-semibold text-slate-300 tabular-nums">
            場上 {waveProgress.aliveEnemies} / 總計 {waveProgress.totalEnemies}
          </span>
        </div>
        <p className="mt-1 text-[11px] leading-relaxed text-slate-400">
          {waveDef.description}
        </p>

        {/* Recommended Stance Hint */}
        <div className="mt-2 flex items-start gap-1.5 rounded-lg border border-amber-500/25 bg-amber-950/30 px-2.5 py-1.5 text-[11px] leading-snug text-amber-200/95">
          <Info className="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-400" />
          <span>{waveDef.recommendedStanceHint}</span>
        </div>
      </div>

      {/* 100% Transparent Enemy Roster Breakdown */}
      <div>
        <div className="mb-1.5 flex items-center justify-between">
          <span className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">
            <Swords className="h-3.5 w-3.5 text-rose-400" />
            敵軍編制情報（全透明）
          </span>
          <span className="text-[10px] text-slate-500">HP / 攻 / 城門傷</span>
        </div>

        <div className="space-y-1.5">
          {rosterEntries.map(({ def, totalCount, aliveCount }) => (
            <div
              key={def.archetype}
              title={def.description}
              className="rounded-lg border border-slate-800/90 bg-slate-950/70 px-2.5 py-1.5"
            >
              <div className="flex items-center justify-between gap-1.5">
                <div className="flex min-w-0 items-center gap-1.5">
                  <span className="truncate text-xs font-bold text-slate-100">
                    {def.name}
                  </span>
                  {def.isElite && (
                    <span className="inline-flex items-center gap-0.5 rounded bg-amber-500/20 px-1 py-px text-[9px] font-bold text-amber-300 ring-1 ring-amber-400/40">
                      <Sparkles className="h-2.5 w-2.5" />
                      菁英
                    </span>
                  )}
                  {def.isExplosive && (
                    <span className="inline-flex items-center gap-0.5 rounded bg-rose-500/20 px-1 py-px text-[9px] font-bold text-rose-300 ring-1 ring-rose-400/40">
                      <Flame className="h-2.5 w-2.5" />
                      自爆
                    </span>
                  )}
                  {def.attackRange >= 150 && (
                    <span className="rounded bg-violet-500/20 px-1 py-px text-[9px] font-bold text-violet-300 ring-1 ring-violet-400/30">
                      遠程
                    </span>
                  )}
                </div>

                <div className="flex shrink-0 items-center gap-1.5 text-[11px] tabular-nums">
                  {aliveCount > 0 && (
                    <span className="rounded bg-rose-950/80 px-1 py-px text-[10px] font-semibold text-rose-300">
                      存活 {aliveCount}
                    </span>
                  )}
                  <span className="font-bold text-slate-200">×{totalCount}</span>
                </div>
              </div>

              <div className="mt-1 flex items-center justify-between text-[10px] text-slate-400 tabular-nums">
                <span className="truncate pr-2">{def.description}</span>
                <span className="shrink-0 font-medium text-slate-300">
                  {def.maxHp} / {def.atk} / {def.gateDamage}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Live Combat Event Log */}
      <div className="flex min-h-[160px] flex-1 flex-col overflow-hidden border-t border-slate-800 pt-2">
        <div className="mb-1.5 flex items-center justify-between">
          <span className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">
            <ScrollText className="h-3.5 w-3.5 text-cyan-400" />
            即時戰況日誌
          </span>
          <span className="text-[10px] text-slate-500 tabular-nums">
            最新 {logs.length} 筆
          </span>
        </div>

        <div className="tactical-scroll flex-1 space-y-1 overflow-y-auto pr-1">
          {logs.length === 0 ? (
            <div className="flex h-full items-center justify-center text-xs text-slate-500">
              等待戰況回報…
            </div>
          ) : (
            logs.map((item) => {
              const badgeStyle = LOG_STYLE[item.kind];
              return (
                <div
                  key={item.id}
                  className="flex items-start gap-1.5 rounded border border-slate-800/70 bg-slate-950/60 px-2 py-1 text-[11px] leading-snug"
                >
                  <span className="mt-px shrink-0 font-mono text-[10px] text-slate-500 tabular-nums">
                    {formatTime(item.timeSec)}
                  </span>
                  <span
                    className={`mt-px shrink-0 rounded border px-1 py-px text-[9px] font-semibold ${badgeStyle.badge}`}
                  >
                    {badgeStyle.label}
                  </span>
                  <span
                    className={
                      item.kind === 'gate_hit'
                        ? 'font-medium text-rose-200'
                        : 'text-slate-200'
                    }
                  >
                    {item.kind === 'gate_hit' && (
                      <ShieldAlert className="mr-1 inline h-3 w-3 text-rose-400" />
                    )}
                    {item.kind === 'spawn' && (
                      <AlertTriangle className="mr-1 inline h-3 w-3 text-amber-400" />
                    )}
                    {item.message}
                  </span>
                </div>
              );
            })
          )}
        </div>
      </div>
    </aside>
  );
}
