# claude-dual-dev-skill 安装配置指南

> **本文档面向 AI 编码 Agent（Claude Code 等）读取，引导用户完成 dual-dev skill 的安装与配置。**
> 将本文档地址发给 AI Agent，它会交互式地完成安装流程。

GitHub：https://github.com/3Taste/claude-dual-dev-skill

**如果你是正在帮助用户安装的 AI Agent，请遵循以下原则：**
- 用交互工具（如 AskUserQuestion）询问用户的选择和偏好
- 不要猜测路径或配置，始终向用户确认
- 执行每一步前先说明要做什么
- 遇到错误时给出具体的解决建议

---

## 第一步：环境检查

依次检查以下依赖，缺失时给出安装指引：

### 检查 git

```bash
git --version
```

要求版本 ≥ 2.5（支持 `git worktree`）。未安装时：

```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt-get install git
```

### 检查 Claude Code CLI

```bash
claude --version
```

未找到时提示用户：

> 请先安装 Claude Code CLI，参考：https://claude.ai/download
> 安装后重新运行安装流程。

### 检查操作系统

```bash
uname -s
```

- **Darwin（macOS）**：全功能支持，终端窗口自动打开
- **Linux / Windows**：worktree、信号文件、提示词渲染均正常，**终端自动打开不可用**，需手动执行启动命令

---

## 第二步：选择安装位置

询问用户：

> 请选择安装方式：
> 1. **全局安装**（推荐）— 安装到 `~/.claude/skills/dual-dev/`，所有项目均可使用 `/dual-dev`
> 2. **项目级安装** — 安装到当前项目的 `.claude/skills/dual-dev/`，仅当前项目可用

---

## 第三步：执行安装

### 全局安装

```bash
git clone --depth 1 https://github.com/3Taste/claude-dual-dev-skill.git ~/.claude/skills/dual-dev
```

### 项目级安装

```bash
mkdir -p .claude/skills
git clone --depth 1 https://github.com/3Taste/claude-dual-dev-skill.git .claude/skills/dual-dev
```

---

## 第四步：验证安装

```bash
ls ~/.claude/skills/dual-dev/SKILL.md
# 或项目级：
ls .claude/skills/dual-dev/SKILL.md
```

文件存在即安装成功。

---

## 第五步：首次使用

安装完成后，进入任意 git 项目根目录，在 Claude Code 中输入：

```
/dual-dev
```

skill 会引导你完成 5 步配置：

| 步骤 | 内容 |
|------|------|
| Q1 | worktree 路径、新建分支名、基础分支 |
| Q2 | 功能需求来源（已有设计文档 或 直接描述需求） |
| Q3 | Claude 模型选择 |
| Q4 | 提示词来源（内置默认模板 或 自定义文件） |
| Q5 | 特殊要求 |

配置完成后，两个终端窗口自动打开，提示词自动注入 Claude，无需额外操作。

---

## 升级

```bash
# 全局安装
cd ~/.claude/skills/dual-dev && git pull

# 项目级安装
cd .claude/skills/dual-dev && git pull
```

---

## 卸载

```bash
# 全局安装
rm -rf ~/.claude/skills/dual-dev

# 项目级安装
rm -rf .claude/skills/dual-dev
```

---

## 常见问题

**Q：终端窗口没有自动打开？**
macOS 需要授予终端辅助功能权限：系统设置 → 隐私与安全性 → 辅助功能 → 勾选 Terminal。

**Q：`/dual-dev` 命令找不到？**
重启 Claude Code 后重试，或确认 SKILL.md 路径正确。

**Q：提示词没有自动加载？**
确认 `claude` 版本支持 `@file` 启动参数（最新版 Claude Code CLI 均支持）。
