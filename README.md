# mygame — 戰意守城原型（Godot 4 · GDScript）

> 3D 《戰意》式「武將手操 × 兵團指揮 × Roguelike 守城」原型，使用 **Godot 4 + GDScript** 開發。
> *(早期 Web + Three.js 驗證原型已完整封存於 Git Tag `v0.2-web-prototype`。)*

## 環境與啟動方式
1. 安裝 **Godot Engine 4.x**（本專案使用 Godot 4.7.2 Standard / GDScript）。
2. 用 Godot 開啟本資料夾（載入 `project.godot`）並按 **F5** 即可執行！
3. 或透過命令列直接啟動：
   ```powershell
   godot --path .
   ```

## 操作速覽
- **武將（艾莉絲）**：
  - `WASD`：鏡頭相對移動
  - `滑鼠左鍵`：三連斬（第 3 段擊退破防）
  - `Space`：翻滾閃避（消耗體力、無敵幀）
  - `滑鼠右鍵 / Q`：破陣衝鋒（突進擊退路徑敵軍）
  - `E`：戰意咆哮（強化自身與周圍兵團）
  - `Tab`：切換 **肩後 TPS 視角（SpringArm3D 防穿牆 360° 滑鼠轉視角）** ↔ **3D 戰術俯視角**
  - `Esc`：解鎖／釋放滑鼠游標
- **兵團即時指揮（上方 HUD 可即時切換 🛡️ 刀盾兵 / 🔱 長槍兵 / 🏹 長弓兵）**：
  - `C`：跟隨武將
  - `X`：定點列陣於準心／游標落點
  - `V`：自由進攻
  - `1` / `2`：切換密集陣／散陣
  - `F`：兵團招牌特技（盾擊衝鋒／疾風突刺／指定箭雨）

## 專案目錄結構
- `scenes/`：主戰場場景（`Main.tscn`）
- `scripts/core/`：純資料與規則常數（`GameConfig.gd`：兵種、敵軍與 3 波測試波次定義）
- `scripts/world/`：3D 攻城戰場建構、城門耐久、波次生成與勝負管理（`BattlefieldManager.gd`）
- `scripts/entities/`：3D 武將（`HeroController.gd`，含 `SpringArm3D` 雙視角）、兵團士兵（`RegimentManager.gd`）、敵軍與敵方武將（`EnemyUnit.gd`，含紅圈預警）
- `scripts/ui/`：戰術 HUD、兵種／波次切換、勝敗結算視窗（`BattleHud.gd`）
- `tests/`：Godot Headless 自動化邏輯驗證腳本（`run_tests.gd`）

## 規格與文件
- 核心企劃書：`docs/GDD.md`
- 架構決策紀錄：`docs/adr/`（ADR-0001 ~ ADR-0003）
- Agent 規範：`AGENTS.md` 與 `docs/agents/`
