# Idle Rift

Idle Rift（工作名）是一款以自动战斗、装备掉落和离线收菜为核心的像素挂机 RPG。

玩家选择当前挑战层数，英雄持续自动战斗并积累战利品。上线后的主要决策是鉴定、筛选和搭配装备，调整 Build，然后突破更高层数。

## 当前状态

项目处于概念验证阶段。首个垂直切片已经可以运行，包含自动战斗、循环敌人、基础装备掉落、背包和换装。现阶段继续验证三个问题：

1. 自动战斗是否值得观看。
2. 装备掉落是否让人期待。
3. 换装后是否能明显推进更高层数。

当前装备支持普通、魔法和稀有品质，以及武器、头盔、胸甲、戒指和护符五个部位。传奇、套装、远古和神话装备将在基础掉落循环稳定后逐层加入。

## 技术栈

- Godot 4.x
- GDScript
- 展开界面逻辑分辨率：960 × 540
- 桌面目标分辨率：1280 × 720

## 启动

1. 安装 Godot 4.x。
2. 在 Godot Project Manager 中导入本目录的 `project.godot`。
3. 运行项目，或在仓库根目录执行 `godot --path .`。

运行时按 `Esc` 收成桌面右下角挂机条，按 `Tab` 在挂机条与整备界面之间切换，按 `R` 打开远征结算。三个状态中战斗模拟都会继续运行。

## 测试

```bash
godot --headless --path . --script res://tests/test_combat.gd
```

测试覆盖自动战斗推进、金币与掉落、裂隙等级增长，以及换装后属性立即生效。

## 文档

- [PRODUCT.md](PRODUCT.md)：产品方向与范围
- [DESIGN.md](DESIGN.md)：视觉与交互原则
- [docs/GDD.md](docs/GDD.md)：首版玩法设计
- [docs/CLASSES.md](docs/CLASSES.md)：职业资源、战斗风味与装备方向
- [docs/AI_TOOLCHAIN.md](docs/AI_TOOLCHAIN.md)：AI Agent 工具链计划
- [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md)：像素资产规格、生成和审核流程
- [docs/DATA_ARCHITECTURE.md](docs/DATA_ARCHITECTURE.md)：玩法配置、运行状态、规则和 UI 的分层约定

## 第三方资产

界面使用经过项目字符集裁剪的 Noto Sans SC 字体。字体依据 SIL Open Font License 1.1 使用，许可证位于 `assets/fonts/NotoSansSC-LICENSE.txt`。
