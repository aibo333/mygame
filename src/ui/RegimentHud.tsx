import {
  Crosshair,
  Flag,
  MapPin,
  Navigation,
  Shield,
  Sparkles,
  Swords,
  Users,
} from 'lucide-react';
import { REGIMENT_DEFINITIONS } from '../core/combat/presets';
import type {
  RegimentFormation,
  RegimentOrder,
  RegimentState,
  RegimentType,
} from '../core/types/combat';

export interface RegimentHudProps {
  regiment: RegimentState;
  disabled: boolean;
  onIssueOrder: (order: RegimentOrder) => void;
  onIssueFormation: (formation: RegimentFormation) => void;
  onIssueSkill: () => void;
}

const REGIMENT_BADGE: Record<RegimentType, { emoji: string; accent: string }> = {
  shieldmen: { emoji: '🛡️', accent: 'text-sky-300 border-sky-400/50 bg-sky-500/15' },
  pikemen: { emoji: '🔱', accent: 'text-amber-300 border-amber-400/50 bg-amber-500/15' },
  archers: { emoji: '🏹', accent: 'text-emerald-300 border-emerald-400/50 bg-emerald-500/15' },
};

const ORDER_BUTTONS: Array<{
  order: RegimentOrder;
  hotkey: string;
  label: string;
  hint: string;
  icon: typeof Navigation;
}> = [
  { order: 'follow', hotkey: 'C', label: '跟隨', hint: '貼身護衛', icon: Navigation },
  { order: 'hold', hotkey: 'X', label: '定點列陣', hint: '游標駐守', icon: MapPin },
  { order: 'engage', hotkey: 'V', label: '自由進攻', hint: '主動接戰', icon: Swords },
];

export function RegimentHud({
  regiment,
  disabled,
  onIssueOrder,
  onIssueFormation,
  onIssueSkill,
}: RegimentHudProps) {
  const def = REGIMENT_DEFINITIONS[regiment.type];
  const badge = REGIMENT_BADGE[regiment.type];
  const hasSoldiers = regiment.aliveCount > 0;
  const skillReady = !disabled && hasSoldiers && regiment.skillCooldownSec <= 0.05;
  const skillCdPct =
    regiment.skillMaxCooldownSec > 0
      ? Math.min(100, Math.max(0, (regiment.skillCooldownSec / regiment.skillMaxCooldownSec) * 100))
      : 0;

  return (
    <section
      aria-label="兵團指揮列"
      className="flex flex-col justify-between gap-2.5 rounded-xl border border-slate-800 bg-slate-900/90 p-3 shadow-lg"
    >
      {/* Top Row: Regiment Identity + Alive Pips */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2.5 min-w-0">
          <div
            className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border text-lg shadow-inner ${badge.accent}`}
          >
            <span aria-hidden="true">{badge.emoji}</span>
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h2 className="truncate text-sm font-black tracking-wide text-white">
                {regiment.name}
              </h2>
              <span
                className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold tabular-nums ${
                  regiment.aliveCount === 0
                    ? 'bg-rose-500/20 text-rose-300'
                    : regiment.aliveCount <= Math.ceil(regiment.maxCount * 0.35)
                      ? 'bg-amber-500/20 text-amber-300'
                      : 'bg-emerald-500/20 text-emerald-300'
                }`}
              >
                <Users className="h-3 w-3" />
                {regiment.aliveCount} / {regiment.maxCount}
              </span>
            </div>
            <p className="mt-0.5 truncate text-[11px] text-slate-400" title={regiment.description}>
              {regiment.description}
            </p>
          </div>
        </div>

        {/* Visual Soldier Pips */}
        <div
          className="flex shrink-0 flex-wrap justify-end gap-1 max-w-[132px] pt-0.5"
          aria-label={`兵團存活士兵 ${regiment.aliveCount} / ${regiment.maxCount}`}
        >
          {regiment.soldiers.map((soldier) => {
            const hpRatio = soldier.maxHp > 0 ? soldier.hp / soldier.maxHp : 0;
            const pipClass = !soldier.alive
              ? 'bg-slate-800/80 border-slate-700/70'
              : hpRatio > 0.6
                ? 'bg-emerald-400 border-emerald-300/80 shadow-[0_0_4px_rgba(52,211,153,0.5)]'
                : hpRatio > 0.3
                  ? 'bg-amber-400 border-amber-300/80'
                  : 'bg-rose-500 border-rose-400/80';

            return (
              <span
                key={soldier.id}
                title={
                  soldier.alive
                    ? `士兵 #${soldier.index + 1} · HP ${Math.ceil(soldier.hp)}/${soldier.maxHp}`
                    : `士兵 #${soldier.index + 1} · 已陣亡`
                }
                className={`h-2.5 w-2.5 rounded-sm border transition-colors ${pipClass}`}
              />
            );
          })}
        </div>
      </div>

      {/* Bottom Controls: Orders + Formation + Signature Skill */}
      <div className="grid grid-cols-12 gap-2">
        {/* Orders: C / X / V (5 cols) */}
        <div className="col-span-5 grid grid-cols-3 gap-1.5">
          {ORDER_BUTTONS.map(({ order, hotkey, label, icon: Icon }) => {
            const active = regiment.order === order;
            return (
              <button
                key={order}
                type="button"
                disabled={disabled || !hasSoldiers}
                onClick={() => onIssueOrder(order)}
                className={`flex cursor-pointer flex-col justify-between rounded-lg border px-2 py-1.5 text-left transition ${
                  active
                    ? 'border-cyan-400 bg-cyan-500/20 text-cyan-100 shadow-[0_0_10px_rgba(34,211,238,0.2)]'
                    : 'border-slate-700/80 bg-slate-950/85 text-slate-300 hover:border-slate-500 hover:bg-slate-800/80'
                } disabled:cursor-not-allowed disabled:opacity-50`}
              >
                <div className="flex items-center justify-between">
                  <span
                    className={`rounded px-1 py-0.5 text-[10px] font-bold ${
                      active ? 'bg-cyan-400/30 text-cyan-100' : 'bg-slate-800 text-slate-300'
                    }`}
                  >
                    {hotkey}
                  </span>
                  <Icon className={`h-3.5 w-3.5 ${active ? 'text-cyan-300' : 'text-slate-400'}`} />
                </div>
                <div className="mt-1 text-[11px] font-bold leading-tight">{label}</div>
              </button>
            );
          })}
        </div>

        {/* Formation Toggle: 1 / 2 (4 cols) */}
        <div className="col-span-4 grid grid-cols-2 gap-1.5">
          <button
            type="button"
            disabled={disabled || !hasSoldiers}
            onClick={() => onIssueFormation('compact')}
            className={`flex cursor-pointer flex-col justify-between rounded-lg border px-2 py-1.5 text-left transition ${
              regiment.formation === 'compact'
                ? 'border-amber-400 bg-amber-500/20 text-amber-100'
                : 'border-slate-700/80 bg-slate-950/85 text-slate-300 hover:border-slate-500 hover:bg-slate-800/80'
            } disabled:cursor-not-allowed disabled:opacity-50`}
          >
            <div className="flex items-center justify-between">
              <span
                className={`rounded px-1 py-0.5 text-[10px] font-bold ${
                  regiment.formation === 'compact'
                    ? 'bg-amber-400/30 text-amber-100'
                    : 'bg-slate-800 text-slate-300'
                }`}
              >
                1
              </span>
              <Shield className="h-3.5 w-3.5 text-amber-300/80" />
            </div>
            <div className="mt-1 truncate text-[11px] font-bold leading-tight" title={def.compactLabel}>
              {def.compactLabel}
            </div>
          </button>

          <button
            type="button"
            disabled={disabled || !hasSoldiers}
            onClick={() => onIssueFormation('spread')}
            className={`flex cursor-pointer flex-col justify-between rounded-lg border px-2 py-1.5 text-left transition ${
              regiment.formation === 'spread'
                ? 'border-emerald-400 bg-emerald-500/20 text-emerald-100'
                : 'border-slate-700/80 bg-slate-950/85 text-slate-300 hover:border-slate-500 hover:bg-slate-800/80'
            } disabled:cursor-not-allowed disabled:opacity-50`}
          >
            <div className="flex items-center justify-between">
              <span
                className={`rounded px-1 py-0.5 text-[10px] font-bold ${
                  regiment.formation === 'spread'
                    ? 'bg-emerald-400/30 text-emerald-100'
                    : 'bg-slate-800 text-slate-300'
                }`}
              >
                2
              </span>
              <Flag className="h-3.5 w-3.5 text-emerald-300/80" />
            </div>
            <div className="mt-1 truncate text-[11px] font-bold leading-tight" title={def.spreadLabel}>
              {def.spreadLabel}
            </div>
          </button>
        </div>

        {/* Signature Skill: F (3 cols) */}
        <button
          type="button"
          disabled={!skillReady}
          onClick={onIssueSkill}
          className={`relative col-span-3 flex cursor-pointer flex-col justify-between overflow-hidden rounded-lg border px-2.5 py-1.5 text-left transition ${
            skillReady
              ? 'border-violet-400/75 bg-gradient-to-br from-violet-600/25 to-slate-950 text-violet-100 hover:border-violet-300 hover:from-violet-500/35'
              : 'cursor-not-allowed border-slate-800 bg-slate-950/60 text-slate-400 opacity-70'
          }`}
        >
          {skillCdPct > 0 && (
            <div
              className="pointer-events-none absolute inset-x-0 bottom-0 bg-slate-950/80 transition-all duration-75"
              style={{ height: `${skillCdPct}%` }}
            />
          )}
          <div className="relative z-10 flex items-center justify-between">
            <span className="rounded bg-violet-500/30 px-1.5 py-0.5 text-[10px] font-bold text-violet-200">
              F
            </span>
            {regiment.type === 'archers' ? (
              <Crosshair className="h-3.5 w-3.5 text-violet-300" />
            ) : (
              <Sparkles className="h-3.5 w-3.5 text-violet-300" />
            )}
          </div>
          <div className="relative z-10 mt-1">
            <div className="truncate text-xs font-black leading-tight">{regiment.skillName}</div>
            <div className="text-[10px] tabular-nums text-violet-300/90">
              {!hasSoldiers
                ? '兵團全滅'
                : regiment.skillCooldownSec > 0.05
                  ? `冷卻 ${regiment.skillCooldownSec.toFixed(1)}s`
                  : '游標目標 · 就緒'}
            </div>
          </div>
        </button>
      </div>
    </section>
  );
}
