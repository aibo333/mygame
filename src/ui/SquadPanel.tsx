import {
  Crosshair,
  Heart,
  Shield,
  Sparkles,
  Skull,
  Swords,
  Zap,
} from 'lucide-react';
import type {
  HeroState,
  SkillRuntimeState,
  SkillTriggerCondition,
  SquadRole,
} from '../core/types/combat';

export interface SquadPanelProps {
  heroes: HeroState[];
  elapsedSec: number;
}

const ROLE_STYLES: Record<
  SquadRole,
  {
    label: string;
    Icon: typeof Shield;
    ring: string;
    emblemBg: string;
    badge: string;
    hpBar: string;
  }
> = {
  tank: {
    label: '坦克',
    Icon: Shield,
    ring: 'border-cyan-500/35',
    emblemBg: 'from-cyan-500/30 via-sky-900/70 to-slate-950 text-cyan-200 border-cyan-400/50',
    badge: 'bg-cyan-500/15 text-cyan-300 border-cyan-400/30',
    hpBar: 'bg-gradient-to-r from-cyan-500 to-sky-400',
  },
  dps: {
    label: '輸出',
    Icon: Crosshair,
    ring: 'border-amber-500/35',
    emblemBg: 'from-amber-500/30 via-rose-900/60 to-slate-950 text-amber-200 border-amber-400/50',
    badge: 'bg-amber-500/15 text-amber-300 border-amber-400/30',
    hpBar: 'bg-gradient-to-r from-amber-500 to-orange-400',
  },
  support: {
    label: '補輔',
    Icon: Sparkles,
    ring: 'border-emerald-500/35',
    emblemBg: 'from-emerald-500/30 via-teal-900/60 to-slate-950 text-emerald-200 border-emerald-400/50',
    badge: 'bg-emerald-500/15 text-emerald-300 border-emerald-400/30',
    hpBar: 'bg-gradient-to-r from-emerald-500 to-teal-400',
  },
};

function getTriggerBadge(cond: SkillTriggerCondition): { label: string; className: string } {
  switch (cond) {
    case 'always':
      return {
        label: '自動施放',
        className: 'bg-slate-800/90 text-slate-300 border-slate-700',
      };
    case 'self_hp_below_55':
      return {
        label: '自血 <55%',
        className: 'bg-rose-950/70 text-rose-300 border-rose-500/30',
      };
    case 'any_ally_hp_below_45':
      return {
        label: '隊友 <45%',
        className: 'bg-emerald-950/70 text-emerald-300 border-emerald-500/30',
      };
    case 'elite_or_multi_enemies':
      return {
        label: '菁英/多敵',
        className: 'bg-amber-950/70 text-amber-300 border-amber-500/30',
      };
  }
}

function SkillRow({ skill }: { skill: SkillRuntimeState }) {
  const trigger = getTriggerBadge(skill.triggerCondition);
  const isOutOfCharges = skill.chargesRemaining !== null && skill.chargesRemaining <= 0;
  const isCooling = skill.cooldownRemainingSec > 0.05;
  const readyProgress =
    skill.cooldownSec > 0
      ? Math.min(100, Math.max(0, (1 - skill.cooldownRemainingSec / skill.cooldownSec) * 100))
      : 100;

  return (
    <div
      title={skill.description}
      className="rounded-md border border-slate-800/90 bg-slate-950/75 px-2 py-1.5"
    >
      <div className="flex items-center justify-between gap-1.5">
        <div className="flex min-w-0 items-center gap-1.5">
          <Zap
            className={`h-3 w-3 shrink-0 ${
              isOutOfCharges
                ? 'text-slate-600'
                : isCooling
                  ? 'text-amber-400/80'
                  : 'text-cyan-300'
            }`}
          />
          <span className="truncate text-xs font-semibold text-slate-100">
            {skill.name}
          </span>
          <span
            className={`shrink-0 rounded border px-1 py-px text-[9px] font-medium ${trigger.className}`}
          >
            {trigger.label}
          </span>
        </div>

        <div className="flex shrink-0 items-center gap-1.5 tabular-nums">
          {skill.maxChargesPerWave !== null && skill.chargesRemaining !== null && (
            <span
              className={`rounded px-1 py-px text-[10px] font-bold ${
                skill.chargesRemaining > 0
                  ? 'bg-amber-500/20 text-amber-300 ring-1 ring-inset ring-amber-400/30'
                  : 'bg-slate-800 text-slate-500'
              }`}
              title="本波剩餘施放次數"
            >
              {skill.chargesRemaining}/{skill.maxChargesPerWave}
            </span>
          )}

          <span
            className={`min-w-[38px] text-right text-[10px] font-semibold ${
              isOutOfCharges
                ? 'text-slate-500'
                : isCooling
                  ? 'text-amber-300'
                  : 'text-emerald-300'
            }`}
          >
            {isOutOfCharges
              ? '耗盡'
              : isCooling
                ? `${skill.cooldownRemainingSec.toFixed(1)}s`
                : '就緒'}
          </span>
        </div>
      </div>

      {/* Cooldown progress bar */}
      <div className="mt-1 h-1 w-full overflow-hidden rounded-full bg-slate-800/90">
        <div
          className={`h-full transition-all duration-75 ${
            isOutOfCharges
              ? 'bg-slate-700'
              : isCooling
                ? 'bg-amber-400/85'
                : 'bg-emerald-400/90'
          }`}
          style={{ width: isOutOfCharges ? '0%' : `${readyProgress}%` }}
        />
      </div>
    </div>
  );
}

export function SquadPanel({ heroes, elapsedSec }: SquadPanelProps) {
  const safeElapsed = Math.max(1, elapsedSec);

  return (
    <section
      className="grid grid-cols-1 gap-3 md:grid-cols-3"
      aria-label="三人小隊狀態面板"
    >
      {heroes.map((hero) => {
        const style = ROLE_STYLES[hero.role];
        const RoleIcon = style.Icon;
        const hpPct = hero.maxHp > 0 ? Math.min(100, Math.max(0, (hero.hp / hero.maxHp) * 100)) : 0;
        const shieldPct =
          hero.maxHp > 0 ? Math.min(100, Math.max(0, (hero.shield / hero.maxHp) * 100)) : 0;
        const dps = hero.stats.damageDealt / safeElapsed;

        return (
          <article
            key={hero.id}
            className={[
              'relative flex flex-col gap-2 rounded-xl border bg-slate-900/90 p-3 shadow-lg transition-opacity',
              hero.alive ? style.ring : 'border-rose-900/60 opacity-60 grayscale-[35%]',
            ].join(' ')}
          >
            {/* Top row: Avatar emblem + Name/Role + Live Telemetry */}
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-center gap-2.5">
                {/* Stylized anime-emblem role avatar badge */}
                <div
                  className={`relative flex h-11 w-11 shrink-0 items-center justify-center rounded-lg border bg-gradient-to-br shadow-inner ${style.emblemBg}`}
                >
                  <span className="text-base font-black tracking-tight">
                    {hero.name.slice(0, 1)}
                  </span>
                  <span className="absolute -bottom-1 -right-1 flex h-4.5 w-4.5 items-center justify-center rounded-full border border-slate-800 bg-slate-950">
                    <RoleIcon className="h-2.5 w-2.5" />
                  </span>
                </div>

                <div className="min-w-0">
                  <div className="flex items-center gap-1.5">
                    <h3 className="truncate text-sm font-bold text-white">
                      {hero.name}
                    </h3>
                    <span
                      className={`rounded border px-1.5 py-px text-[10px] font-semibold ${style.badge}`}
                    >
                      {style.label}
                    </span>
                    {!hero.alive && (
                      <span className="inline-flex items-center gap-0.5 rounded bg-rose-950 px-1.5 py-px text-[10px] font-bold text-rose-300 ring-1 ring-rose-500/40">
                        <Skull className="h-2.5 w-2.5" />
                        退場
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-[11px] text-slate-400">
                    <span>{hero.title}</span>
                    {hero.damageReductionRemainingSec > 0 && (
                      <span className="rounded bg-cyan-950/90 px-1 py-px text-[10px] font-medium text-cyan-300 ring-1 ring-cyan-500/30 tabular-nums">
                        減傷 {Math.round(hero.damageReductionRatio * 100)}% ·{' '}
                        {hero.damageReductionRemainingSec.toFixed(1)}s
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Live combat telemetry */}
              <div className="flex shrink-0 flex-col items-end text-right text-[11px] tabular-nums">
                <span className="inline-flex items-center gap-1 font-semibold text-amber-300">
                  <Swords className="h-3 w-3" />
                  {dps.toFixed(1)} DPS
                </span>
                {hero.role === 'support' || hero.stats.healingDone > 0 ? (
                  <span className="inline-flex items-center gap-1 text-emerald-300">
                    <Heart className="h-3 w-3" />
                    治療 {Math.round(hero.stats.healingDone)}
                  </span>
                ) : (
                  <span className="text-slate-400">
                    總傷 {Math.round(hero.stats.damageDealt)} · 擊殺 {hero.stats.kills}
                  </span>
                )}
              </div>
            </div>

            {/* HP & Shield bar */}
            <div>
              <div className="mb-1 flex items-center justify-between text-[11px] tabular-nums">
                <div className="flex items-center gap-1.5">
                  <span className="font-semibold text-slate-200">
                    HP {Math.ceil(hero.hp)} / {hero.maxHp}
                  </span>
                  {hero.shield > 0 && (
                    <span className="rounded bg-sky-500/20 px-1.5 py-px text-[10px] font-bold text-sky-200 ring-1 ring-inset ring-sky-400/40">
                      +{Math.ceil(hero.shield)} 盾
                    </span>
                  )}
                </div>

                {/* Base combat stats */}
                <div className="flex items-center gap-2 text-[10px] text-slate-400">
                  <span>ATK {hero.atk}</span>
                  <span>DEF {hero.def}</span>
                  <span>SPD {hero.attackSpeed.toFixed(2)}</span>
                </div>
              </div>

              <div className="relative h-2.5 w-full overflow-hidden rounded-full bg-slate-950 ring-1 ring-inset ring-slate-800">
                <div
                  className={`h-full transition-all duration-100 ${
                    hpPct < 35 ? 'bg-gradient-to-r from-rose-600 to-rose-400' : style.hpBar
                  }`}
                  style={{ width: `${hpPct}%` }}
                />
                {hero.shield > 0 && (
                  <div
                    className="absolute inset-y-0 left-0 bg-sky-300/45 ring-1 ring-inset ring-sky-200/70 transition-all duration-100"
                    style={{ width: `${shieldPct}%` }}
                  />
                )}
              </div>
            </div>

            {/* 2 Hero Skills */}
            <div className="grid grid-cols-1 gap-1.5">
              {hero.skills.map((skill) => (
                <SkillRow key={skill.skillId} skill={skill} />
              ))}
            </div>
          </article>
        );
      })}
    </section>
  );
}
