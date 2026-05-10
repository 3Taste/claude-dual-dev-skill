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

### 检测缺省配置

**触发 /dual-dev 后，首先检查当前 git 项目根目录下是否存在 `.claude/dual-dev-defaults.json`：**

```bash
# 用 Bash 工具执行，获取项目根目录
git rev-parse --show-toplevel
```

若文件存在，用 Read 工具读取内容，展示给用户：

> 检测到上次配置记录：
>
> - 开发模型：`<dev_model>`
> - 审查模型：`<reviewer_model>`
> - 终端：`<terminal>`
> - 提示词：`<dev_prompt_path 或 内置模板>`
> - 特殊要求：`<special_requirements>`
>
> 是否沿用以上配置？（只需回答 Q1 工作区路径和 Q2 功能需求）
> 1. **沿用**（推荐）— 只回答 Q1、Q2，其余配置自动复用
> 2. **重新配置** — 走完整 6 步流程

**若选 1（沿用）**：从 JSON 文件中提取 `DEV_MODEL`、`REVIEWER_MODEL`、`DEV_PROMPT_PATH`、`REVIEWER_PROMPT_PATH`、`SPECIAL_REQUIREMENTS`、`TERMINAL_APP`，跳过 Q3～Q6，只询问 Q1 和 Q2。

**若选 2 或文件不存在**：走完整流程（Q1～Q6）。

---

按顺序提问，收集所有答案后执行 bootstrap.sh。

---

### Q1：工作区路径 & 分支名

询问：

> 请提供以下信息（可一起回答）：
> 1. **worktree 路径**：新建工作区的绝对路径，例如 `~/git/myproject-feature`
> 2. **新建分支名**：例如 `feature/new-api`
> 3. **基础分支**：基于哪个分支创建，例如 `main` 或 `dev`
>
> 当前项目分支为：执行 `git branch --show-current` 获取。

等待用户回答，提取：`WORKTREE_PATH`、`BRANCH_NAME`、`BASE_BRANCH`。

---

### Q2：设计文档路径与内容校验

**2a. 询问来源：**

> 请选择功能需求的来源：
> 1. **已有设计文档** — 提供文件路径，skill 自动校验并整理模块清单
> 2. **直接描述需求** — 没有文档，我来描述功能需求，由 Claude 生成设计文档

---

**若选 1（已有文档）：**

询问路径：

> 请提供设计文档路径，可以是一个或多个，用空格分隔，例如：
> `doc/design.md doc/api-spec.md`

用 Read 工具逐个校验：
- 不存在 → 提示 `⚠️ 文件 <路径> 不存在`，重新询问
- 存在 → 读取内容，判断是否能提取**模块清单**

合规标准（满足其一即可）：
- 有"模块"、"功能点"、"任务"等章节标题
- 有编号列表（1. 2. 或一、二、）描述功能
- 有类似 `## 模块X` 的结构

**不合规时**，整理后请用户确认：

```
以下是从 <文件名> 中识别出的模块清单，请确认或修改：

模块 1：<模块名>
描述：<一句话功能描述>

模块 2：<模块名>
描述：<一句话功能描述>

...

如需调整（增删改顺序），请直接回复修改后的列表；确认无误请回复"确认"。
```

用户确认后存入 `DESIGN_DOCS_SUMMARY`，与原始路径一起注入提示词。

提取：`DESIGN_DOCS`（原始路径）、`DESIGN_DOCS_SUMMARY`（整理后清单，可为空）。

---

**若选 2（直接描述需求）：**

**2b. 收集需求：**

> 请描述你的功能需求，越详细越好。例如：
> - 需要实现哪些功能模块？
> - 各模块的核心逻辑是什么？
> - 有哪些关键接口或数据结构？
> - 技术栈和约束条件？

等待用户输入完整需求描述。

**2c. 生成设计文档（Plan 模式）：**

基于用户描述，生成结构化设计文档，格式如下：

```markdown
# 功能设计文档

## 背景与目标
<需求背景一句话总结>

## 模块清单

### 模块一：<模块名>
**功能描述**：<详细说明>
**接口/数据结构**：<关键设计点>
**实现要点**：<注意事项>

### 模块二：<模块名>
...
```

生成后展示给用户，询问：

> 以上是根据你的需求生成的设计文档草稿，请确认或提出修改意见：
> - 回复"确认"直接使用
> - 回复具体修改意见，我会更新后再次确认

**2d. 保存文档：**

用户确认后，将文档保存到当前目录：
- 路径：`doc/dual-dev-generated-design.md`（若 `doc/` 不存在则创建）
- 用 Write 工具写入

将该路径设为 `DESIGN_DOCS`，文档中的模块清单设为 `DESIGN_DOCS_SUMMARY`。

---

### Q3：Claude 模型选择

询问：

> 请选择 Claude 模型：
> 1. 两个窗口都使用默认模型（claude-sonnet-4-6）
> 2. 指定开发者窗口模型
> 3. 指定审查者窗口模型
> 4. 分别指定两个窗口的模型
>
> 请回复序号或直接输入模型名称。

根据回答提取 `DEV_MODEL` 和 `REVIEWER_MODEL`（未指定则均为 `claude-sonnet-4-6`）。

---

### Q4：提示词选择

询问：

> 请选择角色提示词来源：
> 1. **使用内置默认模板**（推荐）— skill 自动根据设计文档和参数渲染提示词
> 2. **使用自定义提示词** — 我已准备好自己的提示词文件
>
> 选 2 请分别提供开发者和审查者提示词的文件路径。

**若选 1**：`DEV_PROMPT_PATH=""` / `REVIEWER_PROMPT_PATH=""`（使用内置模板）

**若选 2**：
- 询问开发者提示词路径，用 Read 工具校验文件存在
- 询问审查者提示词路径，用 Read 工具校验文件存在
- 提取 `DEV_PROMPT_PATH` 和 `REVIEWER_PROMPT_PATH`

---

### Q5：特殊要求

询问：

> 有没有特殊要求？例如：
> - 代码风格限制
> - 测试覆盖率要求
> - 禁止使用某些库
> - 性能或安全约束
>
> 没有要求直接回复"无"或留空。

提取 `SPECIAL_REQUIREMENTS`（为空则设为空字符串）。

若有 `DESIGN_DOCS_SUMMARY`，将其拼接到 `SPECIAL_REQUIREMENTS` 末尾：

```
[整理后的模块清单]
---
<原有特殊要求>
```

---

### Q6：终端选择

询问：

> 请选择打开终端的方式（仅 macOS）：
> 1. **Ghostty**（推荐）— Claude Code 官方推荐终端，AppleScript 原生支持，体验更佳
>    未安装可前往：https://ghostty.org/download
> 2. **Terminal.app** — macOS 系统自带终端，无需额外安装
>
> 请回复 1 或 2（默认选 1）。

根据回答提取 `TERMINAL_APP`：
- 选 1 或留空 → `TERMINAL_APP="ghostty"`
- 选 2 → `TERMINAL_APP="terminal"`

> **注**：若选 Ghostty 但未安装，bootstrap.sh 会自动回退到 Terminal.app。

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
