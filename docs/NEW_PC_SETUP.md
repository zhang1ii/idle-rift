# Idle Rift 新电脑部署指南

本指南用于在一台新的 Windows 电脑上恢复源码、`zmj` 分支、Godot 运行环境、GitHub 推送权限，以及本次 Codex 玩法设计上下文。

## 1. 安装基础环境

在 PowerShell 中安装 Git、Godot 4.7.1 和可选的 GitHub CLI：

```powershell
winget install --id Git.Git -e
winget install --id GodotEngine.GodotEngine -e --version 4.7.1
winget install --id GitHub.cli -e
```

安装后关闭并重新打开 PowerShell，检查：

```powershell
git --version
godot --version
gh --version
```

如果 `winget` 中已经没有 4.7.1，请从 Godot 官方历史版本安装 4.7.x，并把 `Godot_v4.7.x-stable_win64_console.exe` 加入 PATH，或在验证脚本中使用 `-GodotPath` 指定其完整路径。

## 2. 使用纯英文路径克隆 `zmj` 分支

推荐路径：`C:\dev\godotgame\idle-rift`。仓库是公开的，克隆和拉取不需要登录；推送才需要 GitHub 权限。

```powershell
New-Item -ItemType Directory -Force C:\dev\godotgame
Set-Location C:\dev\godotgame
git clone --branch zmj https://github.com/zhang1ii/idle-rift.git
Set-Location .\idle-rift
git status --short --branch
```

正常结果应显示当前分支为 `zmj`，并跟踪 `origin/zmj`。

不要用 GitHub 网页的 Download ZIP 代替克隆。ZIP 没有分支、提交历史和推送配置，不适合继续协作开发。

## 3. 登录 GitHub 以便推送

```powershell
gh auth login --hostname github.com --git-protocol https --web
gh auth status
git remote -v
```

浏览器授权时登录拥有 `zhang1ii/idle-rift` 写权限的账号。不要把 token、密码、`.env` 或 Codex 本机配置提交到仓库。

## 4. 验证项目

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_windows.ps1
```

若 Godot 没有加入 PATH：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_windows.ps1 -GodotPath "C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe"
```

全部测试通过后打开编辑器：

```powershell
godot --editor --path .
```

然后运行主场景，确认能看到横版战斗原型。

## 5. 恢复 Codex 对话上下文

当前 Codex 任务是本地主机任务；现有工具没有把正在运行的当前任务直接导出或自行迁移到另一台主机的能力。因此迁移不能只依赖任务列表是否同步。

可靠恢复方式：

1. 在新电脑安装 Codex 并登录同一个账号。
2. 如果任务列表中能看到原任务，可直接继续；看不到也不影响开发。
3. 在 Codex 中打开 `C:\dev\godotgame\idle-rift`。
4. 新建任务，把 [CODEX_HANDOFF.md](CODEX_HANDOFF.md) 最后一节的“新任务启动提示词”粘贴进去。
5. 要求 Codex 先读 `AGENTS.md`、`PRODUCT.md`、`DESIGN.md`、`docs/GDD.md`、`docs/TALENT_SYSTEM.md` 和 `docs/CODEX_HANDOFF.md`，再检查 Git 状态和测试。

`CODEX_HANDOFF.md` 是可公开的语义交接，不是包含工具输出、推理过程和登录步骤的逐字聊天记录。这样既能恢复全部玩法结论，也不会把本机信息或凭据推到公开仓库。

## 6. 日常同步

开始开发前：

```powershell
git switch zmj
git status --short --branch
git pull --ff-only origin zmj
```

完成并验证后：

```powershell
git add <本次修改的文件>
git commit -m "feat: describe the change"
git push origin zmj
```

如果 `git status` 显示未提交修改，先确认这些修改属于谁、是否需要保留，再拉取或切换分支；不要用 `git reset --hard` 清理协作者的工作。

## 7. 迁移验收清单

- `git branch --show-current` 输出 `zmj`。
- `git status --short --branch` 显示跟踪 `origin/zmj`。
- `godot --version` 为 4.7.x。
- `verify_windows.ps1` 全部通过。
- Godot 可以打开 `project.godot` 并运行主场景。
- GitHub 登录账号对仓库有写权限。
- Codex 新任务已经读取 `CODEX_HANDOFF.md`。
