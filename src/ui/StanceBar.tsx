import { Shield, Swords, Timer, Wind } from 'lucide-react';
import { STANCE_MODIFIERS } from '../core/combat/presets';
import type { StanceModifier, TacticalStance } from '../core/types/combat';

export interface StanceBarProps {
  currentStance: TacticalStance;
  cooldownRemainingSec: number;
  cooldownSec: number;
  disabled: boolean;
  onSelectStance: (stance: TacticalStance) => void;
}

interface StanceMeta {
  stance: TacticalStance;
  hotkey: string;
  Icon: typeof Shield;
  activeBorder: string;
  activeBg: string;
  activeGlow: string;
  badgeBg: string;
  accentText: string;
}

const STANCE_ORDER: StanceMeta[] = [
  {
    stance: 'defense',
    hotkey: '1',
    Icon: Shield,
    activeBorder: 'border-cyan-400/90',
    activeBg: 'bg-cyan-950/55',
    activeGlow: 'shadow-[0_0_20px_rgba(34,211,238,0.22)]',
    badgeBg: 'bg-cyan-500/20 text-cyan-200 border-cyan-400/40',
    accentText: 'text-cyan-300',
  },
  {
    stance: 'assault',
    hotkey: '2',
    Icon: Swords,
    activeBorder: 'border-amber-400/90',
    activeBg: 'bg-amber-950/50',
    activeGlow: 'shadow-[0_0_20px_rgba(251,191,36,0.22)]',
    badgeBg: 'bg-amber-500/20 text-amber-200 border-amber-400/40',
    accentText: 'text-amber-300',
  },
  {
    stance: 'scatter',
    hotkey: '3',
    Icon: Wind,
    activeBorder: 'border-emerald-400/90',
    activeBg: 'bg-emerald-950/50',
    activeGlow: 'shadow-[0_0_20px_rgba(52,211,153,0.22)]',
    badgeBg: 'bg-emerald-500/20 text-emerald-200 border-emerald-400/40',
    accentText: 'text-emerald-300',
  },
];

interface ModifierChip {
  label: string;
  tone: 'pos' | 'neg';
}

function buildModifierChips(mod: StanceModifier): ModifierChip[] {
  const chips: ModifierChip[] = [];

  if (mod.tankInterceptRadiusMultiplier !== 1) {
    const pct = Math.round((mod.tankInterceptRadiusMultiplier - 1) * 100);
    chips.push({ label: `攔截 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct > 0 ? 'pos' : 'neg' });
  }
  if (mod.teamAtkMultiplier !== 1) {
    const pct = Math.round((mod.teamAtkMultiplier - 1) * 100);
    chips.push({ label: `全隊攻擊 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct > 0 ? 'pos' : 'neg' });
  }
  if (mod.attackSpeedMultiplier !== 1) {
    const pct = Math.round((mod.attackSpeedMultiplier - 1) * 100);
    chips.push({ label: `攻速 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct > 0 ? 'pos' : 'neg' });
  }
  if (mod.damageTakenMultiplier !== 1) {
    const pct = Math.round((mod.damageTakenMultiplier - 1) * 100);
    chips.push({ label: `承傷 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct < 0 ? 'pos' : 'neg' });
  }
  if (mod.aoeDamageTakenMultiplier !== 1) {
    const pct = Math.round((mod.aoeDamageTakenMultiplier - 1) * 100);
    chips.push({ label: `範圍傷 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct < 0 ? 'pos' : 'neg' });
  }
  if (mod.healMultiplier !== 1) {
    const pct = Math.round((mod.healMultiplier - 1) * 100);
    chips.push({ label: `治療 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct > 0 ? 'pos' : 'neg' });
  }
  if (mod.moveSpeedMultiplier !== 1) {
    const pct = Math.round((mod.moveSpeedMultiplier - 1) * 100);
    chips.push({ label: `移速 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct > 0 ? 'pos' : 'neg' });
  }
  if (mod.dpsDamageMultiplier !== 1) {
    const pct = Math.round((mod.dpsDamageMultiplier - 1) * 100);
    chips.push({ label: `輸出傷害 ${pct > 0 ? `+${pct}%` : `${pct}%`}`, tone: pct > 0 ? 'pos' : 'neg' });
  }

  return chips;
}

export function StanceBar({
  currentStance,
  cooldownRemainingSec,
  cooldownSec,
  disabled,
  onSelectStance,
}: StanceBarProps) {
  const isOnCooldown = cooldownRemainingSec > 0.01;
  const cdRatio =
    cooldownSec > 0 ? Math.min(1, Math.max(0, cooldownRemainingSec / cooldownSec)) : 0;

  return (
    <section
      className="rounded-xl border border-slate-800 bg-slate-900/90 p-2.5 shadow-lg"
      aria-label="即時戰術指令切換"
    >
      {/* Header + global cooldown progress bar */}
      <div className="mb-2 flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold tracking-wider text-slate-300">
            即時戰術陣型
          </span>
          <span className="hidden text-[11px] text-slate-500 sm:inline">
            快捷鍵 [1] [2] [3] 即時下令
          </span>
        </div>

        <div className="flex items-center gap-2">
          <Timer
            className={`h-3.5 w-3.5 ${isOnCooldown ? 'text-amber-400' : 'text-emerald-400'}`}
          />
          <span
            className={`tabular-nums text-xs font-medium ${
              isOnCooldown ? 'text-amber-300' : 'text-emerald-300'
            }`}
          >
            {isOnCooldown
              ? `切換冷卻 ${cooldownRemainingSec.toFixed(1)}s`
              : '戰術指令就緒'}
          </span>
          <div className="h-1.5 w-24 overflow-hidden rounded-full bg-slate-800">
            <div
              className={`h-full transition-all duration-75 ${
                isOnCooldown ? 'bg-amber-400' : 'bg-emerald-400'
              }`}
              style={{ width: `${isOnCooldown ? (1 - cdRatio) * 100 : 100}%` }}
            />
          </div>
        </div>
      </div>

      {/* 3 Tactical Stance Buttons */}
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
        {STANCE_ORDER.map((meta) => {
          const mod = STANCE_MODIFIERS[meta.stance];
          const isActive = currentStance === meta.stance;
          const cannotClick = disabled || isActive || isOnCooldown;
          const chips = buildModifierChips(mod);
          const Icon = meta.Icon;

          return (
            <button
              key={meta.stance}
              type="button"
              disabled={cannotClick}
              onClick={() => onSelectStance(meta.stance)}
              title={mod.description}
              className={[
                'group relative flex flex-col justify-between overflow-hidden rounded-lg border px-3 py-2 text-left transition-all duration-150',
                isActive
                  ? `${meta.activeBorder} ${meta.activeBg} ${meta.activeGlow}`
                  : cannotClick
                    ? 'cursor-not-allowed border-slate-800 bg-slate-950/60 opacity-65'
                    : 'cursor-pointer border-slate-700/80 bg-slate-950/75 hover:border-slate-500 hover:bg-slate-800/80',
              ].join(' ')}
            >
              {/* Cooldown sweep overlay on inactive buttons */}
              {!isActive && isOnCooldown && (
                <div
                  className="pointer-events-none absolute inset-y-0 left-0 bg-slate-950/50 transition-all duration-75"
                  style={{ width: `${cdRatio * 100}%` }}
                />
              )}

              <div className="relative z-10 flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <span
                    className={`flex h-5 w-5 items-center justify-center rounded border text-[11px] font-bold tabular-nums ${
                      isActive
                        ? meta.badgeBg
                        : 'border-slate-700 bg-slate-900 text-slate-400'
                    }`}
                  >
                    {meta.hotkey}
                  </span>
                  <Icon
                    className={`h-4 w-4 ${isActive ? meta.accentText : 'text-slate-400'}`}
                  />
                  <span
                    className={`text-sm font-bold tracking-wide ${
                      isActive ? 'text-white' : 'text-slate-200'
                    }`}
                  >
                    {mod.label}
                  </span>
                </div>

                {isActive && (
                  <span
                    className={`rounded-full border px-1.5 py-0.5 text-[10px] font-semibold ${meta.badgeBg}`}
                  >
                    執行中
                  </span>
                )}
              </div>

              {/* Transparent modifier chips */}
              <div className="relative z-10 mt-1.5 flex flex-wrap gap-1">
                {chips.map((chip) => (
                  <span
                    key={chip.label}
                    className={`rounded px-1.5 py-0.5 text-[10px] font-medium tabular-nums ${
                      chip.tone === 'pos'
                        ? 'bg-emerald-950/75 text-emerald-300 ring-1 ring-inset ring-emerald-500/25'
                        : 'bg-rose-950/75 text-rose-300 ring-1 ring-inset ring-rose-500/25'
                    }`}
                  >
                    {chip.label}
                  </span>
                ))}
              </div>
            </button>
          );
        })}
      </div>
    </section>
  );
}
