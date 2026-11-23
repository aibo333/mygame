import { Flame, Heart, Skull, Swords, Wind, Zap } from 'lucide-react';
import type { HeroState } from '../core/types/combat';

export interface HeroHudProps {
  hero: HeroState;
  disabled: boolean;
  onTriggerDodge: () => void;
  onTriggerSkill1: () => void;
  onTriggerSkill2: () => void;
}

const DODGE_STAMINA_COST = 30;

export function HeroHud({
  hero,
  disabled,
  onTriggerDodge,
  onTriggerSkill1,
  onTriggerSkill2,
}: HeroHudProps) {
  const hpPct = hero.maxHp > 0 ? Math.min(100, Math.max(0, (hero.hp / hero.maxHp) * 100)) : 0;
  const staminaPct =
    hero.maxStamina > 0 ? Math.min(100, Math.max(0, (hero.stamina / hero.maxStamina) * 100)) : 0;

  const skill1Ready = hero.alive && !disabled && hero.skill1CooldownSec <= 0.01;
  const skill2Ready = hero.alive && !disabled && hero.skill2CooldownSec <= 0.01;
  const dodgeReady =
    hero.alive && !disabled && hero.stamina >= DODGE_STAMINA_COST && hero.dodgeRemainingSec <= 0;

  const skill1CdPct =
    hero.skill1MaxCooldownSec > 0
      ? Math.min(100, Math.max(0, (hero.skill1CooldownSec / hero.skill1MaxCooldownSec) * 100))
      : 0;
  const skill2CdPct =
    hero.skill2MaxCooldownSec > 0
      ? Math.min(100, Math.max(0, (hero.skill2CooldownSec / hero.skill2MaxCooldownSec) * 100))
      : 0;

  const warcryActive = hero.warcryRemainingSec > 0.05;

  return (
    <section
      aria-label="武將狀態與技能欄"
      className="flex flex-col justify-between gap-2.5 rounded-xl border border-slate-800 bg-slate-900/90 p-3 shadow-lg"
    >
      {/* Top Row: Portrait + Vitals + Telemetry */}
      <div className="flex items-center gap-3">
        {/* Portrait Badge */}
        <div className="relative shrink-0">
          <div
            className={`flex h-12 w-12 items-center justify-center rounded-xl border-2 shadow-inner transition ${
              !hero.alive
                ? 'border-rose-500/70 bg-rose-950/60 text-rose-400'
                : warcryActive
                  ? 'border-amber-400 bg-gradient-to-br from-amber-500/35 to-orange-950/80 text-amber-200 shadow-[0_0_14px_rgba(251,191,36,0.4)]'
                  : 'border-cyan-400/60 bg-gradient-to-br from-cyan-500/25 to-slate-900 text-cyan-200'
            }`}
          >
            {hero.alive ? <Swords className="h-6 w-6" /> : <Skull className="h-6 w-6" />}
          </div>
          {warcryActive && hero.alive && (
            <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-amber-400 text-[9px] font-black text-slate-950 shadow">
              吼
            </span>
          )}
        </div>

        {/* Name + HP / Stamina Bars */}
        <div className="min-w-0 flex-1 space-y-1.5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className="text-sm font-black tracking-wide text-white">{hero.name}</span>
              <span className="rounded bg-slate-800 px-1.5 py-0.5 text-[10px] font-semibold text-cyan-300">
                守城武將
              </span>
              {warcryActive && (
                <span className="inline-flex items-center gap-1 rounded-full border border-amber-400/50 bg-amber-500/20 px-2 py-0.5 text-[10px] font-bold text-amber-200 tabular-nums animate-pulse">
                  <Flame className="h-3 w-3 text-amber-400" />
                  戰吼 {hero.warcryRemainingSec.toFixed(1)}s
                </span>
              )}
              {!hero.alive && (
                <span className="inline-flex items-center gap-1 rounded-full border border-rose-500/60 bg-rose-500/20 px-2 py-0.5 text-[10px] font-bold text-rose-200 tabular-nums">
                  復活倒數 {Math.max(0, hero.respawnRemainingSec).toFixed(1)}s
                </span>
              )}
            </div>

            {/* Kills / Damage Telemetry */}
            <div className="flex items-center gap-2.5 text-[11px] tabular-nums">
              <span className="text-slate-400">
                擊殺 <strong className="text-cyan-300">{hero.kills}</strong>
              </span>
              <span className="text-slate-400">
                輸出 <strong className="text-amber-300">{Math.round(hero.damageDealt)}</strong>
              </span>
            </div>
          </div>

          {/* HP Bar */}
          <div className="space-y-0.5">
            <div className="flex items-center justify-between text-[10px] tabular-nums">
              <span className="inline-flex items-center gap-1 font-semibold text-slate-300">
                <Heart className="h-3 w-3 text-rose-400" />
                生命
              </span>
              <span className={hero.alive ? 'font-bold text-emerald-300' : 'font-bold text-rose-400'}>
                {hero.alive
                  ? `${Math.ceil(hero.hp)} / ${hero.maxHp}`
                  : `陣亡重整中 (${Math.max(0, hero.respawnRemainingSec).toFixed(1)}s)`}
              </span>
            </div>
            <div className="h-2 w-full overflow-hidden rounded-full bg-slate-950 ring-1 ring-inset ring-slate-800">
              <div
                className={`h-full transition-all duration-100 ${
                  !hero.alive
                    ? 'bg-rose-700/70'
                    : hpPct > 55
                      ? 'bg-gradient-to-r from-emerald-500 to-teal-400'
                      : hpPct > 28
                        ? 'bg-gradient-to-r from-amber-500 to-yellow-400'
                        : 'bg-gradient-to-r from-rose-600 to-red-400'
                }`}
                style={{ width: `${hero.alive ? hpPct : 0}%` }}
              />
            </div>
          </div>

          {/* Stamina Bar */}
          <div className="space-y-0.5">
            <div className="flex items-center justify-between text-[10px] tabular-nums">
              <span className="inline-flex items-center gap-1 font-semibold text-slate-400">
                <Wind className="h-3 w-3 text-sky-400" />
                體力（翻滾消耗 {DODGE_STAMINA_COST}）
              </span>
              <span className="font-semibold text-sky-300">
                {Math.floor(hero.stamina)} / {hero.maxStamina}
              </span>
            </div>
            <div className="relative h-1.5 w-full overflow-hidden rounded-full bg-slate-950 ring-1 ring-inset ring-slate-800">
              <div
                className="h-full bg-gradient-to-r from-sky-500 to-cyan-300 transition-all duration-75"
                style={{ width: `${staminaPct}%` }}
              />
              {/* 30 stamina threshold tick */}
              <div
                className="pointer-events-none absolute top-0 h-full w-px bg-slate-300/50"
                style={{ left: `${(DODGE_STAMINA_COST / hero.maxStamina) * 100}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Bottom Row: 4 Skill Slots */}
      <div className="grid grid-cols-4 gap-2">
        {/* LMB 3-Hit Combo */}
        <div className="relative flex flex-col justify-between overflow-hidden rounded-lg border border-slate-700/80 bg-slate-950/85 px-2.5 py-2">
          <div className="flex items-center justify-between">
            <span className="rounded bg-slate-800 px-1.5 py-0.5 text-[10px] font-bold text-slate-200">
              LMB
            </span>
            <Swords className="h-3.5 w-3.5 text-slate-300" />
          </div>
          <div className="mt-1.5">
            <div className="text-xs font-bold text-slate-100">三連斬</div>
            <div className="mt-1 flex items-center gap-1">
              {[0, 1, 2].map((step) => (
                <span
                  key={step}
                  className={`h-1.5 flex-1 rounded-full transition ${
                    hero.comboStep === step
                      ? 'bg-cyan-400 shadow-[0_0_6px_rgba(34,211,238,0.8)]'
                      : 'bg-slate-800'
                  }`}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Space Dodge */}
        <button
          type="button"
          onClick={onTriggerDodge}
          disabled={!dodgeReady}
          className={`relative flex cursor-pointer flex-col justify-between overflow-hidden rounded-lg border px-2.5 py-2 text-left transition ${
            hero.dodgeRemainingSec > 0
              ? 'border-sky-300 bg-sky-500/25 text-sky-100'
              : dodgeReady
                ? 'border-sky-500/50 bg-slate-950/85 hover:border-sky-400 hover:bg-sky-950/50'
                : 'cursor-not-allowed border-slate-800 bg-slate-950/60 opacity-55'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="rounded bg-sky-500/20 px-1.5 py-0.5 text-[10px] font-bold text-sky-200">
              Space
            </span>
            <Wind className="h-3.5 w-3.5 text-sky-300" />
          </div>
          <div className="mt-1.5">
            <div className="text-xs font-bold text-slate-100">翻滾閃避</div>
            <div className="text-[10px] text-slate-400 tabular-nums">
              {hero.dodgeRemainingSec > 0
                ? '無敵位移中'
                : hero.stamina >= DODGE_STAMINA_COST
                  ? '體力 30 · 就緒'
                  : '體力不足'}
            </div>
          </div>
        </button>

        {/* Q / RMB Skill 1: 破陣衝鋒 */}
        <button
          type="button"
          onClick={onTriggerSkill1}
          disabled={!skill1Ready}
          className={`relative flex cursor-pointer flex-col justify-between overflow-hidden rounded-lg border px-2.5 py-2 text-left transition ${
            skill1Ready
              ? 'border-cyan-400/60 bg-slate-950/85 hover:border-cyan-300 hover:bg-cyan-950/40'
              : 'cursor-not-allowed border-slate-800 bg-slate-950/60 opacity-70'
          }`}
        >
          {skill1CdPct > 0 && (
            <div
              className="pointer-events-none absolute inset-x-0 bottom-0 bg-slate-900/80 transition-all duration-75"
              style={{ height: `${skill1CdPct}%` }}
            />
          )}
          <div className="relative z-10 flex items-center justify-between">
            <span className="rounded bg-cyan-500/20 px-1.5 py-0.5 text-[10px] font-bold text-cyan-200">
              Q / RMB
            </span>
            <Zap className="h-3.5 w-3.5 text-cyan-300" />
          </div>
          <div className="relative z-10 mt-1.5">
            <div className="text-xs font-bold text-slate-100">破陣衝鋒</div>
            <div className="text-[10px] tabular-nums text-cyan-300/90">
              {hero.skill1CooldownSec > 0.05
                ? `冷卻 ${hero.skill1CooldownSec.toFixed(1)}s`
                : '穿刺擊退 · 就緒'}
            </div>
          </div>
        </button>

        {/* E Skill 2: 戰意咆哮 */}
        <button
          type="button"
          onClick={onTriggerSkill2}
          disabled={!skill2Ready}
          className={`relative flex cursor-pointer flex-col justify-between overflow-hidden rounded-lg border px-2.5 py-2 text-left transition ${
            warcryActive
              ? 'border-amber-400 bg-amber-500/20 shadow-[0_0_12px_rgba(251,191,36,0.25)]'
              : skill2Ready
                ? 'border-amber-400/60 bg-slate-950/85 hover:border-amber-300 hover:bg-amber-950/40'
                : 'cursor-not-allowed border-slate-800 bg-slate-950/60 opacity-70'
          }`}
        >
          {skill2CdPct > 0 && (
            <div
              className="pointer-events-none absolute inset-x-0 bottom-0 bg-slate-900/80 transition-all duration-75"
              style={{ height: `${skill2CdPct}%` }}
            />
          )}
          <div className="relative z-10 flex items-center justify-between">
            <span className="rounded bg-amber-500/20 px-1.5 py-0.5 text-[10px] font-bold text-amber-200">
              E
            </span>
            <Flame className="h-3.5 w-3.5 text-amber-300" />
          </div>
          <div className="relative z-10 mt-1.5">
            <div className="text-xs font-bold text-slate-100">戰意咆哮</div>
            <div className="text-[10px] tabular-nums text-amber-300/90">
              {warcryActive
                ? `增幅中 ${hero.warcryRemainingSec.toFixed(1)}s`
                : hero.skill2CooldownSec > 0.05
                  ? `冷卻 ${hero.skill2CooldownSec.toFixed(1)}s`
                  : '兵團增傷 · 就緒'}
            </div>
          </div>
        </button>
      </div>
    </section>
  );
}
