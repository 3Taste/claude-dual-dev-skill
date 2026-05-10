# dual-dev

**Claude Code Skill** — 双人开发工作流启动器。

为单人主机上的**开发者 + 审查者**双窗口协作模式提供一键启动能力：自动创建 git worktree、打开两个终端窗口并注入角色提示词、建立基于信号文件的逐模块审查协议。

---

## 快速开始

### 🤖 通过 AI Agent 安装（推荐）

最简单的方式 — 把这段话发给 Claude Code 或其他 AI 编码 Agent，它会交互式地完成整个安装和配置过程：

```
请参考 https://raw.githubusercontent.com/3Taste/claude-dual-dev-skill/main/INSTALL.md 帮我安装 dual-dev skill
```

### 📦 手动安装

```bash
# 全局安装（所有项目可用）
git clone --depth 1 https://github.com/3Taste/claude-dual-dev-skill.git ~/.claude/skills/dual-dev

# 项目级安装（仅当前项目可用）
git clone --depth 1 https://github.com/3Taste/claude-dual-dev-skill.git .claude/skills/dual-dev
```

---

## 工作原理

```
主仓库 (main/dev)
    │
    ├── [开发者窗口] claude --model <dev-model>
    │       worktree: ~/git/myproject-feature
    │       分支: feature/xxx
    │       读提示词 → 逐模块实现 → 写 ready 信号 → 等待审查
    │
    └── [审查者窗口] claude --model <reviewer-model>
            worktree: 同上（只读+运行）
            CronCreate 每分钟轮询 → 检测 ready 信号 → 审查 → 写 review 信号
```

信号文件目录：`<worktree>/.claude/signals/`

| 文件 | 写入方 | 含义 |
|------|--------|------|
| `ready-<模块>.md` | 开发者 | 某模块已实现并提交，请求审查 |
| `review-<模块>.md` | 审查者 | 审查结论（PASS / FAIL + 问题列表） |

---

## 系统要求

| 依赖 | 最低版本 | 说明 |
|------|---------|------|
| macOS | 12 (Monterey) | 终端自动化依赖 `osascript`，Linux/Windows 需手动打开窗口 |
| git | 2.5+ | `git worktree` 支持 |
| Claude Code CLI | 最新版 | `claude` 命令需在 PATH 中 |
| bash | 3.2+ | macOS 自带满足要求 |
| Ghostty | 1.3+（推荐）| AppleScript 原生支持，[下载地址](https://ghostty.org/download)；未安装自动回退到 Terminal.app |

> **Linux / Windows 用户**：bootstrap.sh 会跳过 `osascript` 步骤并提示手动打开终端，其余功能（worktree、信号文件、提示词渲染）完全可用。

---

## 安装

> 详见 [INSTALL.md](INSTALL.md) — 包含 AI Agent 自动安装引导、环境检查和常见问题。

### 全局安装（推荐）

```bash
git clone --depth 1 https://github.com/3Taste/claude-dual-dev-skill.git ~/.claude/skills/dual-dev
```

### 一键脚本

```bash
curl -fsSL https://raw.githubusercontent.com/3Taste/claude-dual-dev-skill/main/install.sh | bash
```

### 项目级安装

```bash
git clone --depth 1 https://github.com/3Taste/claude-dual-dev-skill.git .claude/skills/dual-dev
```

---

## 安装验证

```bash
# 检查文件是否就位
ls ~/.claude/skills/dual-dev/SKILL.md

# 在 Claude Code 中验证（在任意 git 项目中运行）
/dual-dev
```

---

## 使用方法

1. 进入任意 git 项目根目录
2. 在 Claude Code 中输入 `/dual-dev`
3. 按提示完成 6 步配置：
   - Q1：worktree 路径、分支名、基础分支
   - Q2：设计文档路径（skill 会自动校验并整理模块清单；或直接描述需求由 Claude 生成）
   - Q3：Claude 模型选择
   - Q4：提示词来源（内置默认模板 或 自定义文件）
   - Q5：特殊要求
   - Q6：终端选择（Ghostty 推荐 / Terminal.app）
4. 两个终端窗口自动打开，**提示词自动注入 Claude，无需手动操作**

### 提示词加载行为

**默认模板**（Q4 选 1）：bootstrap.sh 将 `templates/` 下的模板渲染（替换所有占位符）后存入 worktree，启动 Claude 时以 `@<path>` 方式自动加载。

**自定义提示词**（Q4 选 2）：直接使用用户指定的文件，原样复制到 worktree，同样自动加载。

两种方式下终端窗口启动命令均为：

```bash
# 开发者窗口（bootstrap.sh 自动执行）
claude --model <dev-model> "@<worktree>/.claude/dual-dev-developer-prompt.md"

# 审查者窗口（bootstrap.sh 自动执行）
claude --model <reviewer-model> "@<worktree>/.claude/dual-dev-reviewer-prompt.md"
```

> **Linux / Windows 用户**：osascript 不可用时，bootstrap.sh 会打印上述命令，手动在两个终端中执行即可。

### 完成后清理

```bash
git worktree remove "<worktree-path>"
git branch -d "<branch-name>"
```

---

## 安全约束

skill 执行期间**禁止**以下操作（无论是 Claude 自动执行还是脚本调用）：

- `git branch -D` / `git branch -d`（删除分支）
- `git push --force`（强推）
- `git reset --hard`（丢弃提交）
- `rm -rf` 对项目目录（批量删除文件）
- `git clean -fd`（清除未追踪文件）

仅允许删除 `.claude/signals/review-*.md`（审查信号文件读取后清理）。

---

## 目录结构

```
dual-dev/
├── SKILL.md                              # skill 定义与 Q&A 流程
├── README.md                             # 本文档
├── install.sh                            # 一键安装脚本
├── scripts/
│   └── bootstrap.sh                      # 主入口：解析参数、链式执行、ERR 回滚
├── lib/
│   ├── precheck.sh                       # 环境校验（git/claude/macOS/路径）
│   ├── worktree.sh                       # git worktree 封装
│   ├── render.sh                         # 模板占位符替换
│   ├── signals.sh                        # 信号目录 + .gitignore 管理
│   ├── terminal.sh                       # osascript 终端自动化
│   └── rollback.sh                       # 失败回滚
└── templates/
    ├── dual-dev-developer-prompt.md      # 开发者角色提示词模板
    └── dual-dev-reviewer-prompt.md       # 审查者角色提示词模板
```

---

## 自定义提示词

`templates/` 下的提示词为默认模板，支持以下占位符：

| 占位符 | 说明 |
|--------|------|
| `{{WORKTREE_PATH}}` | worktree 绝对路径 |
| `{{BRANCH_NAME}}` | 工作分支名 |
| `{{BASE_BRANCH}}` | 基础分支名 |
| `{{DESIGN_DOCS}}` | 设计文档路径 |
| `{{DEV_MODEL}}` | 开发者窗口模型 |
| `{{REVIEWER_MODEL}}` | 审查者窗口模型 |
| `{{SPECIAL_REQUIREMENTS}}` | 特殊要求 |
| `{{SIGNALS_DIR}}` | 信号文件目录路径 |
| `{{COUNTERPART_PROMPT}}` | 对方角色提示词路径 |

直接编辑 `templates/` 下的文件即可替换为自己的提示词内容。

---

## License

MIT
