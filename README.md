# mygame — 戰意守城原型（Phase 1 v0.2）

> 2.5D 俯視角《戰意》式「武將手操 × 兵團指揮 × Roguelike 守城」Webgame 原型。

## 技術棧與分層架構
- **建置與語言**：Vite + TypeScript + React 19 + Tailwind CSS v4 + Phaser 3 + Vitest
- **嚴格分層**（為未來 Node.js 即時多人協防預留）：
  - `src/core/`：純 TypeScript 模擬核心（零 React / Phaser / DOM 相依），透過 `CombatEngine`（`step` / `issueRegimentCommand` / `getSnapshot`）運作。
  - `src/game/`：Phaser 3 2.5D 像素戰場渲染層與指標世界座標橋接（`BattlefieldController`）。
  - `src/ui/` & `src/App.tsx`：React 60Hz 輸入迴圈、武將狀態列、兵團指令面板與波次情報。

## 常用指令
```bash
npm install          # 安裝相依套件
npm run dev          # 啟動本機開發伺服器 (http://localhost:5173/)
npm test             # 執行 Vitest 核心單元測試
npm run typecheck    # TypeScript 嚴格型別檢查
npm run build        # 型別檢查 + Vite 正式建置
```

## 規格與 Agent 接續開發必讀
- 核心企劃書：`docs/GDD.md`（v0.2）
- 架構決策紀錄：`docs/adr/0001-pivot-to-conquerors-blade-action-command.md`
- Agent 工作規範：`AGENTS.md` 與 `docs/agents/`
