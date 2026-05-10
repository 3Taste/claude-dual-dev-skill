---
name: dual-dev
version: "1.0.0"
description: >
  双人开发工作流启动器：创建 git worktree，打开开发者与审查者两个终端窗口，
  注入角色提示词，建立信号文件协议，驱动逐模块开发→审查→合并循环。
  适用于需要严格代码审查、模块化交付的团队开发场景。
when_to_use: >
  用户想启动双窗口开发审查流程、需要为某个功能分支配置开发者+审查者协作环境时触发。
  关键词：双窗口、双人开发、开发审查、worktree 协作。
argument-hint: "[设计文档路径]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# /dual-dev — 双人开发工作流

**【语言约束】本 skill 执行过程中，主窗口（当前 Claude Code 会话）及自动打开的开发者/审查者终端窗口，全程必须使用中文进行对话和说明。代码、命令、文件路径保持原样，其余所有输出必须是中文。**

---

## 安全约束（执行前必读）

**以下操作在整个 skill 执行过程中绝对禁止，无需用户额外确认：**

| 禁止操作 | 原因 |
|---------|------|
| `git branch -D` / `git branch -d` | 删除分支不可逆 |
| `git push --force` / `git push -f` | 覆盖远端历史 |
| `git reset --hard` | 丢失本地提交 |
| `rm -rf` / `rm -f` 对项目目录 | 文件删除不可逆 |
| `git clean -fd` / `git checkout -- .` | 丢失未提交修改 |
| 修改 `.git/config` 或远端 URL | 破坏仓库配置 |

**例外（仅限以下场景可执行）：**
- `rm` 只允许删除 `.claude/signals/review-*.md`（审查信号文件，读取后清理）
- `git worktree remove` 只在 bootstrap 回滚时执行，且 worktree 为本次新建

违反约束时必须停下，向用户说明原因并请求明确授权。

---

## 步骤

**所有提问必须使用 `AskUserQuestion` 工具，不得以纯文本方式输出问题让用户手动输入。**

---

### 检测缺省配置

先用 Bash 工具获取项目根目录：
```bash
git rev-parse --show-toplevel
```

检查该目录下 `.claude/dual-dev-defaults.json` 是否存在。

**若存在**，用 Read 工具读取，解析出上次配置，然后调用 `AskUserQuestion`：

```
问题：检测到本项目上次的配置记录（模型: <dev_model> / 终端: <terminal> / 提示词: <内置或自定义>），是否沿用？
选项：
  1. 沿用上次配置（只回答工作区路径和功能需求）[推荐]
  2. 重新配置（走完整 6 步流程）
```

- 选 1：从 JSON 提取 `DEV_MODEL`、`REVIEWER_MODEL`、`DEV_PROMPT_PATH`、`REVIEWER_PROMPT_PATH`、`SPECIAL_REQUIREMENTS`、`TERMINAL_APP`，跳过 Q3～Q6
- 选 2 / 文件不存在：走完整流程

---

### Q1：工作区路径 & 分支名

先用 Bash 获取当前分支名：`git branch --show-current`

用 `AskUserQuestion` 询问（自由文本，用户在 Other 中输入）：

```
问题：请填写工作区信息（三项用换行或空格分隔均可）：
  1. worktree 路径（示例：~/git/<项目名>-feature）
  2. 新建分支名（示例：feature/new-api）
  3. 基础分支（当前分支：<current_branch>）
选项：
  Other（用户自行输入）
```

解析用户输入，提取 `WORKTREE_PATH`、`BRANCH_NAME`、`BASE_BRANCH`。

---

### Q2：功能需求来源

用 `AskUserQuestion` 询问：

```
问题：功能需求从哪里来？
选项：
  1. 已有设计文档 — 提供文件路径，自动校验并整理模块清单
  2. 直接描述需求 — 由 Claude 生成设计文档后确认
```

---

**若选 1（已有文档）：**

用 `AskUserQuestion` 询问路径（Other 输入）：

```
问题：请输入设计文档路径（多个文件用空格分隔）
选项：
  Other（用户输入路径）
```

逐个用 Read 工具校验：
- 不存在 → 重新用 `AskUserQuestion` 询问
- 存在 → 读取内容，判断能否提取模块清单

**不合规时**，用 `AskUserQuestion` 展示整理后的模块清单并确认：

```
问题：以下是识别出的模块清单，请确认或选择操作：
  模块 1：<模块名> — <描述>
  模块 2：<模块名> — <描述>
  ...
选项：
  1. 确认，直接使用
  2. 需要修改（请在 Other 中输入修改后的列表）
```

用户确认后存入 `DESIGN_DOCS_SUMMARY`。

---

**若选 2（直接描述需求）：**

用 `AskUserQuestion` 收集需求（Other 输入）：

```
问题：请描述功能需求（模块、接口、技术栈、约束等）
选项：
  Other（用户输入需求描述）
```

基于描述生成结构化设计文档，再用 `AskUserQuestion` 确认：

```
问题：以上是生成的设计文档草稿，请选择：
选项：
  1. 确认，保存并使用
  2. 需要修改（请在 Other 中输入修改意见）
```

确认后用 Write 工具保存到 `doc/dual-dev-generated-design.md`，设为 `DESIGN_DOCS`。

---

### Q3：Claude 模型选择

用 `AskUserQuestion` 询问：

```
问题：请选择 Claude 模型：
选项：
  1. 两个窗口均使用默认模型 claude-sonnet-4-6 [推荐]
  2. 两个窗口均使用 claude-opus-4-5
  3. 分别为两个窗口指定模型（请在 Other 中输入，格式：开发模型,审查模型）
```

- 选 1 → `DEV_MODEL="claude-sonnet-4-6"` / `REVIEWER_MODEL="claude-sonnet-4-6"`
- 选 2 → `DEV_MODEL="claude-opus-4-5"` / `REVIEWER_MODEL="claude-opus-4-5"`
- 选 3（Other）→ 解析用户输入，分别赋值

---

### Q4：提示词选择

用 `AskUserQuestion` 询问：

```
问题：请选择角色提示词来源：
选项：
  1. 使用内置默认模板（推荐）— 自动根据参数渲染
  2. 使用自定义提示词文件 — 需分别提供开发者和审查者的文件路径
```

- 选 1 → `DEV_PROMPT_PATH=""` / `REVIEWER_PROMPT_PATH=""`
- 选 2 → 分别用 `AskUserQuestion`（Other）询问两个路径，Read 工具校验存在性

---

### Q5：特殊要求

用 `AskUserQuestion` 询问：

```
问题：是否有特殊要求？（代码风格、测试覆盖率、禁用库、性能约束等）
选项：
  1. 无特殊要求
  2. 有（请在 Other 中输入）
```

- 选 1 → `SPECIAL_REQUIREMENTS=""`
- 选 2（Other）→ 提取用户输入为 `SPECIAL_REQUIREMENTS`

若有 `DESIGN_DOCS_SUMMARY`，拼接到 `SPECIAL_REQUIREMENTS` 末尾。

---

### Q6：终端选择

用 `AskUserQuestion` 询问：

```
问题：请选择打开终端的方式（仅 macOS）：
选项：
  1. Ghostty（推荐）— Claude Code 官方推荐，AppleScript 原生支持；未安装自动回退 Terminal.app
  2. Terminal.app — macOS 系统自带，无需额外安装
```

- 选 1 → `TERMINAL_APP="ghostty"`
- 选 2 → `TERMINAL_APP="terminal"`

---

## 执行

收集完所有回答后，用 Bash 工具在当前目录执行（将变量替换为实际值）：

```bash
SKILL_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
bash "$SKILL_DIR/scripts/bootstrap.sh" \
  --worktree-path "<WORKTREE_PATH>" \
  --branch-name "<BRANCH_NAME>" \
  --base-branch "<BASE_BRANCH>" \
  --design-docs "<DESIGN_DOCS>" \
  --dev-model "<DEV_MODEL>" \
  --reviewer-model "<REVIEWER_MODEL>" \
  --special-requirements "<SPECIAL_REQUIREMENTS>" \
  --dev-prompt-path "<DEV_PROMPT_PATH>" \
  --reviewer-prompt-path "<REVIEWER_PROMPT_PATH>" \
  --terminal "<TERMINAL_APP>"
```

`DEV_PROMPT_PATH` 和 `REVIEWER_PROMPT_PATH` 为空时省略对应参数。

等待脚本输出，将结果反馈给用户。
