# ZMJ 玩法开发工作记录

- 项目：Idle Rift
- 仓库：`zhang1ii/idle-rift`
- 开发分支：`zmj`
- 记录日期：2026-07-16
- Godot 版本：4.7.1 stable

## 1. 本阶段目标

建立可以实际运行和持续扩展的横版自动战斗玩法原型，并为后续职业、技能、装备、楼层和 Boss 设计提供统一数值模型。

核心体验为：玩家在战前选择并排列技能，角色自动战斗；普通层可重复 farm；每 5 层出现守关 Boss；玩家被 Boss 卡住后通过装备、配装和技能组合成长并完成突破。

## 2. 已完成工作

| 模块 | 完成内容 | 状态 |
|---|---|---|
| 工程与运行环境 | Godot 4.7.1 项目可启动，主场景和脚本可以无界面测试 | 已完成 |
| 横版战斗原型 | 玩家固定在左侧、敌人固定在右侧，全自动按技能队列战斗 | 已完成 |
| 技能调度器 | 五技能槽、战前排序、冷却检查、资源检查、不可用技能自动跳过 | 已完成 |
| 角色属性 | 力量、敏捷、智力、耐力、精通、急速、暴击、全能 | 已完成 |
| 狂怒战士 | 0–100 怒意、六选五技能、流血、爆发、回血、单体/范围泄怒、怒意护盾 | 已完成 |
| Boss 原型 | 迟缓碎地板、恫吓减伤、势大力沉、外骨骼防御、摧毁全部地块后硬狂暴 | 已完成 |
| 楼层模型 | 普通层无限重复，5 层一个 Boss，击败 Boss 后解锁下一段楼层 | 已完成 |
| 成长曲线 | 每有效装备阶级约增加 12% 输出和 10% 生存，Boss 设置明确 farm 门槛 | 已完成 |
| 十三槽装备 | 1 武器、8 护甲、2 戒指、2 饰品，并按部位权重分配属性预算 | 已完成 |
| 品质与词缀 | 白装无词缀；绿、蓝、紫、橙装有两条不重复副属性；部分橙色首饰有特效 | 已完成 |
| 套装模型 | 护甲套装在 2/4/5 件触发，支持 5+2、4+4、4+2 等组合 | 已完成 |
| 纯掉落装备 | 普通装备来自敌人或 Boss，套装只由 Boss 掉落 | 已完成 |
| 背包数据层 | 掉落进入背包、潜在提升判断、手动装备、双戒指/饰品槽比较 | 已完成 |
| 出售与金币 | 无用装备出售为金币，与药水系统共用玩家钱包 | 已完成 |
| 在线/离线模型 | 离线只 farm 已稳定通关普通层，收益为在线的 60% | 已完成 |
| 自动化验证 | 战斗回归、装备规则、Boss 跨阶级、技能组合与两小时 farm 模拟 | 已完成 |

本阶段新增或重构约 20 个脚本/文档文件，玩法代码、测试和设计文档合计约 2200 行。

## 3. 狂怒战士技能原型

当前共有六个技能，战前选择五个并排列释放顺序：

1. 撕裂打击：获得 25 基础怒意并施加精通流血。
2. 狂怒爆发：强化后续 3 个技能，提高怒意获取并降低怒意消耗。
3. 鲜血回响：根据已经造成的 DOT 伤害恢复生命。
4. 毁灭猛击：消耗怒意造成高额单体伤害。
5. 血怒旋风：消耗怒意造成范围伤害并施加 DOT。
6. 怒意壁垒：将当前全部怒意转化为护盾。

精通会提高怒意获取、DOT 伤害和泄怒技能伤害；急速会降低首次出手时间、技能释放间隔和冷却时间。

## 4. Boss 与装备卡点结果

第 5 层 Boss 按 68 秒硬狂暴校准。默认五技能、每档 20 个随机种子的模拟结果：

| 有效装备阶级 | 胜率 | 获胜平均时间 | 定位 |
|---:|---:|---:|---|
| G4 | 20/20 | 48.7 秒 | farm 齐后稳定通过 |
| G3 | 20/20 | 57.5 秒 | 有压力但可以通过 |
| G2 | 3/20 | 60.6 秒 | 小概率提前挑战 |
| G1 | 0/20 | — | 明确卡关，需要 farm |
| G0 | 0/20 | — | 无法通过 |

满装备下的技能组合回归：

| 五技能组合 | 胜率 | 平均击杀时间 |
|---|---:|---:|
| 默认单体 + 护盾 | 10/10 | 49.8 秒 |
| AOE 替换护盾 | 10/10 | 56.5 秒 |
| AOE 替换回血 | 10/10 | 53.8 秒 |

## 5. 两小时 farm 模型

普通敌人每次击杀有 3% 独立装备掉落率。模拟从一套稀有 T1 装备开始，在第 4 层 farm 两小时，包含自动选择提升和出售无用装备，不包含任何装备打造。

| 模式 | 平均世界掉落 | 平均出售金币 | 平均有效 G | G≥3 | G≥3.5 |
|---|---:|---:|---:|---:|---:|
| 在线 2 小时 | 46.7 | 248.1 | 3.82 | 98.3% | 81.0% |
| 离线 2 小时 | 28.5 | 161.1 | 3.28 | 73.0% | 26.3% |

这使在线 farm 两小时基本可以完成第 5 层 Boss 的标准配装；离线仍然有明显成长，但接近毕业的概率显著更低。

## 6. 主要实现文件

### 战斗

- `src/main/combat_ui_base.gd`：通用战斗界面与基础自动战斗。
- `src/main/fury_combat_controller.gd`：狂怒战士和 Boss 战斗逻辑。
- `src/main/main.gd`：装备掉落与背包数据接入。
- `src/gameplay/character_stats.gd`：角色属性换算。
- `src/gameplay/fury_rules.gd`：狂怒战士技能与怒意公式。
- `src/gameplay/boss_rules.gd`：Boss 技能时间轴。

### 数值与装备

- `src/gameplay/progression_model.gd`：楼层、Boss、装备阶级成长曲线。
- `src/gameplay/equipment_rules.gd`：装备槽、品质、词缀和套装规则。
- `src/gameplay/equipment_inventory.gd`：背包、穿戴、出售和掉落。
- `src/gameplay/player_wallet.gd`：装备出售与药水购买共用的金币钱包。
- `src/gameplay/equipment_evaluator.gd`：实际属性到有效装备阶级的换算。

### 测试与模拟

- `tests/test_combat_prototype.gd`
- `tests/test_functional_battle_view.gd`
- `tests/test_talent_tree_ui.gd`
- `tests/test_progression_model.gd`
- `tests/test_equipment_system.gd`
- `tests/test_equipment_combat_stats.gd`
- `tests/test_equipment_inventory_ui.gd`
- `tests/simulate_progression_model.gd`
- `tests/simulate_fury_loadouts.gd`
- `tests/simulate_equipment_farm.gd`

## 7. 自动化测试结果

以下测试均已使用 Godot 4.7.1 headless 模式通过：

```text
Equipment tests passed: 13 slots, qualities, backpack sales, drop-only items, and 2/4/5 sets.
Progression model tests passed: 13-slot budgets, scaling, and boss wall thresholds.
Combat tests passed: six-pick-five Fury kit and boss timeline.
```

示例运行方式：

```powershell
godot --headless --path . --script res://tests/test_combat_prototype.gd
godot --headless --path . --script res://tests/test_equipment_system.gd
godot --headless --path . --script res://tests/simulate_equipment_farm.gd
```

## 8. 当前边界与后续工作

以下部分尚未完成，协作者接手时不应视为已有功能：

1. 装备耐久、损耗与金币维修规则。
2. 将套装 2/4/5 件效果和传奇首饰特效写回战斗角色。
3. 存档、背包持久化、离线时间计算与离线结算界面。
4. 第 10 层及后续 Boss 的独立机制、美术和关卡内容。
5. 装备名称、图标、美术资源、掉落动画和音效。
6. 多职业以及力量系、敏捷系、智力系装备池隔离。

战前天赋树已经接入完整规则原型，支持三系四层、合法前置、免费洗点、终极互斥、Boss 首杀点数和战斗锁定。默认启动场景也已改由完整规则控制器驱动，并复用裂隙背景、角色/敌人动画、伤害数字、护盾和命中特效；旧独立模型只保留为表现对照，不再承接新玩法规则。

实际穿戴的 13 件装备现在统一汇总到角色面板和战斗公式，战前换装会重建主属性、耐力和四项副属性，并保持当前生命百分比；战斗中禁止换装。

`B` 键战前背包已经接入 13 槽穿戴、品质/评分、属性详情、可能提升目标、自动替换较弱槽、单件出售和批量出售非提升；战斗中可查看但禁止改装。

建议下一阶段优先顺序：套装效果接入 → 装备耐久与金币维修 → 存档与离线结算 → 新职业与后续 Boss。

## 9. 设计文档索引

- `docs/COMBAT_SYSTEM.md`：自动战斗与技能调度。
- `docs/FURY_WARRIOR.md`：狂怒战士技能设计。
- `docs/PROGRESSION_MODEL.md`：楼层与 Boss 成长模型。
- `docs/EQUIPMENT_SYSTEM.md`：十三槽装备、品质、套装、出售和金币。
