# Idle Rift

Idle Rift（工作名）是一款以自动战斗、装备掉落、Build 调整和离线收菜为核心的横版像素挂机 RPG。

玩家在战前从六个技能中选择五个并编排循环。完整跑完五格会获得职业奖励，Boss 能破坏指定技能格，传奇装备则可以奖励完整/断裂结果，或者直接改写技能程序的执行方式。普通层首次通关后可反复 farm，每 5 层为守关 Boss。

## 当前状态

项目处于玩法垂直切片阶段，Godot 原型可以运行。目前已经建立：

- 默认启动场景统一横版战斗表现与完整规则控制器。
- 狂怒战士六选五、严格循环队列、完整回路奖励、怒意、流血、回复、泄怒和护盾。
- 第 5 层 Boss 固定技能格裂化、断链反馈和输出/生存失败诊断。
- 3 件结果型传奇：裂隙节拍器、断链齿轮、血色闭环。
- 4 件规则型传奇：孤鸣核心、无源炉心、裂隙熔接器、反震装甲。
- 普通层、Boss 层、战前药水、死亡停止挂机和首个裂隙推进模型。
- 13 个装备槽、5 个品质、随机词缀、背包比较、换装、出售和真实穿戴属性结算。
- 三路线、四层、12 节点的狂怒战士天赋树。

垂直切片初始背包提供 7 件 T4 测试传奇。装备耐久与维修、套装实际效果、正式传奇掉落来源、存档和真实离线结算仍待接入。

## 技术栈

- Godot 4.7.1 stable
- GDScript
- 逻辑分辨率：640 × 360
- 桌面目标分辨率：1280 × 720

## 启动

1. 安装 Godot 4.7.x。
2. 在 Godot Project Manager 中导入仓库根目录的 `project.godot`。
3. 运行项目，或执行：

```powershell
godot --path .
```

战前按 `B` 打开背包，按 `Tab` 打开天赋树。技能栏右侧按钮可以调整顺序或替换备选技能。

## 新电脑部署

完整步骤见 [新电脑部署指南](docs/NEW_PC_SETUP.md)。推荐使用纯英文路径：

```text
C:\dev\godotgame\idle-rift
```

## 测试

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_windows.ps1
powershell -ExecutionPolicy Bypass -File .\tools\verify_windows.ps1 -Quick
godot --path . --script res://tools/capture_ui_preview.gd
```

## 文档

- [PRODUCT.md](PRODUCT.md)：产品方向与范围
- [DESIGN.md](DESIGN.md)：视觉与交互原则
- [docs/GDD.md](docs/GDD.md)：首版玩法规则
- [docs/SKILL_LOOP_SYSTEM.md](docs/SKILL_LOOP_SYSTEM.md)：五技能回路、七件传奇和失败诊断
- [docs/FURY_WARRIOR.md](docs/FURY_WARRIOR.md)：狂怒战士技能与数值
- [docs/TALENT_SYSTEM.md](docs/TALENT_SYSTEM.md)：狂怒战士天赋树
- [docs/EQUIPMENT_SYSTEM.md](docs/EQUIPMENT_SYSTEM.md)：装备、套装、出售和金币
- [docs/PROGRESSION_MODEL.md](docs/PROGRESSION_MODEL.md)：楼层与 Boss 成长模型
- [docs/CODEX_HANDOFF.md](docs/CODEX_HANDOFF.md)：对话决策与开发交接

## 第三方资产

界面使用经过项目字符集裁剪的 Noto Sans SC 字体，依据 SIL Open Font License 1.1 使用。
