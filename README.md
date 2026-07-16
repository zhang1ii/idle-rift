# Idle Rift

Idle Rift（工作名）是一款以自动战斗、装备掉落和离线收菜为核心的像素挂机 RPG。

玩家选择当前挑战层数，英雄持续自动战斗并积累战利品。上线后的主要决策是鉴定、筛选和搭配装备，调整 Build，然后突破更高层数。

## 当前状态

项目处于概念验证阶段。第一阶段只验证三个问题：

1. 自动战斗是否值得观看。
2. 装备掉落是否让人期待。
3. 换装后是否能明显推进更高层数。

## 技术栈

- Godot 4.x
- GDScript
- 像素画基准分辨率：640 × 360
- 桌面目标分辨率：1280 × 720

## 启动

1. 安装 Godot 4.x。
2. 在 Godot Project Manager 中导入本目录的 `project.godot`。
3. 运行项目，或在仓库根目录执行 `godot --path .`。

## 文档

- [PRODUCT.md](PRODUCT.md)：产品方向与范围
- [DESIGN.md](DESIGN.md)：视觉与交互原则
- [docs/GDD.md](docs/GDD.md)：首版玩法设计
- [docs/AI_TOOLCHAIN.md](docs/AI_TOOLCHAIN.md)：AI Agent 工具链计划
