---
name: dual-dev
version: "1.0.0"
description: >
  单机双 Agent 开发审查工作流：开发者 Agent 逐模块实现代码并提交，
  审查者 Agent 异步轮询每次提交、输出审查结论，
  基于信号文件驱动完整的开发→审查→合并循环。
when_to_use: >
  用户想在单机上启动双 Agent 开发审查流程、为功能分支配置自动化审查协作时触发。
  关键词：双 Agent、开发审查、worktree、自动审查、逐模块开发。
argument-hint: "[设计文档路径 | cleanup]"
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
- `git worktree remove` 只在 bootstrap 回滚或清理流程中执行
- `git branch -d`（非强制删除）只在清理流程中执行，有未合并提交时会报错保护

违反约束时必须停下，向用户说明原因并请求明确授权。

---

## 步骤

**所有提问必须使用 `AskUserQuestion` 工具，不得以纯文本方式输出问题让用户手动输入。**

---

### 参数路由

检测 skill 参数（即 `/dual-dev` 后面的文本）：

- 若参数为 `cleanup` 或 `清理` → **跳转到末尾「清理流程」章节**，不执行后续新建流程
- 否则（空参数 / 设计文档路径 / 其他）→ 继续执行下方正常新建流程

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

- 选 1：从 JSON 提取 `DEV_MODEL`、`REVIEWER_MODEL`、`DEV_PROMPT_PATH`、`REVIEWER_PROMPT_PATH`、`SPECIAL_REQUIREMENTS`、`TERMINAL_APP`、`BUILD_COMMAND`，跳过 Q3～Q6
- 选 2 / 文件不存在：走完整流程

---

### Q1：工作区路径 & 分支名

先用 Bash 获取以下信息并计算推荐默认值：

```bash
git branch --show-current        # 当前分支名 → BASE_BRANCH 默认值
basename $(git rev-parse --show-toplevel)  # 项目名 → worktree 路径推荐
```

根据项目名和当前分支推算推荐值：
- 推荐 worktree 路径：`~/git/<项目名>-dev`
- 推荐分支名：`feature/dev`（或 `dev/<当前分支名>`）
- 推荐基础分支：当前分支名

用 `AskUserQuestion` 询问，**选项中直接列出推荐值**，用户可直接选或自定义：

```
问题：请确认工作区配置（推荐值已预填，可直接选或在输入框中自定义）：
选项：
  1. 使用推荐配置：
     路径: ~/git/<项目名>-dev
     分支: feature/dev
     基于: <current_branch>
  2. 自定义（在输入框中按格式填写：路径 分支名 基础分支）
```

- 选 1 → 直接使用推荐值
- 选 2（用户输入）→ 解析用户输入，按空格或换行分割提取三个值

提取 `WORKTREE_PATH`、`BRANCH_NAME`、`BASE_BRANCH`。

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

用 `AskUserQuestion` 询问路径（用户在输入框填写）：

```
问题：请输入设计文档路径（多个文件用空格分隔，直接在输入框填写）
选项：
  1. doc/design.md（常见路径示例）
  2. 在输入框中填写实际路径
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
  2. 需要修改（在输入框中填写修改后的列表）
```

用户确认后存入 `DESIGN_DOCS_SUMMARY`。

---

**若选 2（直接描述需求）：**

用 `AskUserQuestion` 收集需求（用户在输入框填写）：

```
问题：请描述功能需求（模块、接口、技术栈、约束等，直接在输入框填写）
选项：
  1. 简单功能（单模块，无复杂依赖）
  2. 复杂功能（多模块，在输入框中详细描述）
```

基于描述生成结构化设计文档，再用 `AskUserQuestion` 确认：

```
问题：以上是生成的设计文档草稿，请选择：
选项：
  1. 确认，保存并使用
  2. 需要修改（在输入框中填写修改意见）
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
  3. 分别为两个窗口指定模型（在输入框中填写，格式：开发模型,审查模型）
```

- 选 1 → `DEV_MODEL="claude-sonnet-4-6"` / `REVIEWER_MODEL="claude-sonnet-4-6"`
- 选 2 → `DEV_MODEL="claude-opus-4-5"` / `REVIEWER_MODEL="claude-opus-4-5"`
- 选 3（用户输入）→ 解析用户输入，分别赋值

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
- 选 2 → 分别用 `AskUserQuestion`（输入框）询问两个路径，Read 工具校验存在性

---

### Q5：特殊要求

用 `AskUserQuestion` 询问：

```
问题：是否有特殊要求？（代码风格、测试覆盖率、禁用库、性能约束等）
选项：
  1. 无特殊要求
  2. 有（在输入框中填写）
```

- 选 1 → `SPECIAL_REQUIREMENTS=""`
- 选 2（用户输入）→ 提取用户输入为 `SPECIAL_REQUIREMENTS`

若有 `DESIGN_DOCS_SUMMARY`，拼接到 `SPECIAL_REQUIREMENTS` 末尾。

---

### Q5.5：编译命令

用 `AskUserQuestion` 询问：

```
问题：项目的编译/构建命令是什么？（用于开发者编译验证和审查者构建校验）
选项：
  1. 无（纯脚本/解释型语言项目，跳过编译步骤）
  2. Maven：mvn clean compile -P dev
  3. Gradle：./gradlew build
  4. 其他（在输入框中填写完整命令）
```

- 选 1 → `BUILD_COMMAND=""`
- 选 2 → `BUILD_COMMAND="mvn clean compile -P dev"`
- 选 3 → `BUILD_COMMAND="./gradlew build"`
- 选 4（用户输入）→ 提取用户输入

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
  --terminal "<TERMINAL_APP>" \
  --build-command "<BUILD_COMMAND>"
```

`DEV_PROMPT_PATH` 和 `REVIEWER_PROMPT_PATH` 为空时省略对应参数。

等待脚本输出，将结果反馈给用户。

---

## 清理流程

当参数路由判定为 `cleanup` / `清理` 时，执行以下步骤。

### 安全约束（清理专用）

- `git branch -d`（非强制删除）可执行；有未合并提交时会报错保护，**不用 `-D`**
- 不删除主仓库文件，只清理 worktree 目录
- 任何删除操作前均需用户确认

---

### Step 1：发现 dual-dev worktree

执行：
```bash
git worktree list
```

列出所有 worktree，排除主仓库（第一行）。

对每个非主仓库 worktree，用 Bash 工具检查标记文件：
```bash
test -f "<worktree_path>/.claude/dual-dev-developer-prompt.md" && echo "dual-dev"
```

只保留存在标记文件的 worktree（即由 `/dual-dev` 创建的工作区）。

- 若无 dual-dev worktree → 输出"未发现由 dual-dev 创建的工作区，无需清理。"并结束
- 若有 → 继续下一步

---

### Step 2：选择清理目标

用 `AskUserQuestion` 询问：

```
问题：请选择要清理的 dual-dev 工作区：
选项：
  <逐个列出 dual-dev worktree 路径 + 分支名>
  全部清理
```

---

### Step 3：确认清理范围

用 `AskUserQuestion` 确认：

```
问题：即将清理以下内容，确认继续？
  - worktree 目录：<路径>（将被删除）
  - 本地分支：<分支名>（将尝试删除，有未合并提交会跳过）
选项：
  1. 确认，开始清理
  2. 取消
```

---

### Step 4：执行清理

```bash
# 删除 worktree
git worktree remove "<worktree_path>"

# 清理悬空引用
git worktree prune

# 尝试删除本地分支（非强制，有保护）
git branch -d "<branch_name>"
```

若 `git branch -d` 失败（未合并提交），用 `AskUserQuestion` 询问：

```
问题：分支 <branch_name> 有未合并提交，如何处理？
选项：
  1. 保留分支（推荐）
  2. 强制删除（会丢失未合并提交）
```

选 2 时执行 `git branch -D "<branch_name>"`。

若选择"全部清理"，对每个 worktree 重复 Step 3-4。

---

### Step 5：完成提示

输出清理结果摘要：
- 已删除的 worktree
- 已删除/保留的分支
- 建议：若已完成开发，记得合并分支到主线
