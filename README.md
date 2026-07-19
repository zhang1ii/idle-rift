# Idle Rift

Idle Rift（工作名）是一款以自动战斗、装备掉落、Build 调整和离线收菜为核心的横版像素挂机 RPG。

玩家在战前选择五个技能并排列循环，英雄在屏幕左侧与右侧敌人自动战斗。普通层首次通关后可以反复 farm；每 5 层为守关 Boss。玩家通过装备、技能顺序、天赋和战前补给突破卡点。

## 当前状态

项目处于玩法垂直切片阶段，Godot 原型可以运行。目前已经建立：

- 默认启动场景已统一横版战斗表现与完整规则控制器，不再由独立演示模型驱动画面。
- 狂怒战士六选五技能、严格循环队列、怒意、流血、回血、泄怒和护盾。
- 普通层、Boss 层、战前药水、死亡停止挂机和首个裂隙推进模型。
- 13 个装备槽、5 个品质和随机词缀；战前背包支持属性查看、可能提升、换装与出售，所得金币与药水经济共用，实际穿戴属性驱动角色面板和战斗结算。
- 三路线、四层、12 节点的狂怒战士天赋树；完整战斗原型已提供战前加点、免费洗点、Boss 点数奖励和战斗锁定界面。

装备耐久与维修、套装效果和传奇首饰特效仍待接入。装备只由敌人或 Boss 掉落，不设打造入口。准确边界见 [Codex 开发交接](docs/CODEX_HANDOFF.md)。

## 技术栈

- Godot 4.7.1 stable
- GDScript
- 逻辑分辨率：640 × 360
- 桌面目标分辨率：1280 × 720

## 启动

1. 安装 Godot 4.7.x。
2. 在 Godot Project Manager 中导入仓库根目录的 `project.godot`。
3. 运行项目，或在仓库根目录执行：

```powershell
godot --path .
```

运行时按 `Esc` 收成桌面右下角挂机条，按 `Tab` 在挂机条与整备界面之间切换，按 `R` 打开远征结算。三个状态中战斗模拟都会继续运行。

## 新电脑部署

完整的 Windows 安装、克隆、登录、验证和 Codex 对话恢复步骤见 [新电脑部署指南](docs/NEW_PC_SETUP.md)。推荐使用纯英文路径，例如：

```text
C:\dev\godotgame\idle-rift
```

## 测试

在 Windows PowerShell 中运行全部无界面测试：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_windows.ps1
```

快速验证核心迁移链路：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_windows.ps1 -Quick
```

## 文档

- [PRODUCT.md](PRODUCT.md)：产品方向与范围
- [DESIGN.md](DESIGN.md)：视觉与交互原则
- [docs/GDD.md](docs/GDD.md)：首版玩法规则
- [docs/FURY_WARRIOR.md](docs/FURY_WARRIOR.md)：狂怒战士技能与数值
- [docs/TALENT_SYSTEM.md](docs/TALENT_SYSTEM.md)：狂怒战士天赋树
- [docs/EQUIPMENT_SYSTEM.md](docs/EQUIPMENT_SYSTEM.md)：装备、套装、出售和金币
- [docs/PROGRESSION_MODEL.md](docs/PROGRESSION_MODEL.md)：楼层与 Boss 成长模型
- [docs/CODEX_HANDOFF.md](docs/CODEX_HANDOFF.md)：本次对话的决策与开发交接

## 第三方资产

界面使用经过项目字符集裁剪的 Noto Sans SC 字体。字体依据 SIL Open Font License 1.1 使用，许可证位于 `assets/fonts/NotoSansSC-LICENSE.txt`。
