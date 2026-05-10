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

**2a. 询问路径：**

> 请提供设计文档路径（用于注入到角色提示词中）。
> 可以是一个或多个路径，用空格分隔，例如：
> `doc/design.md doc/api-spec.md`
>
> 如果暂无设计文档，直接回复"无"或留空。

**2b. 文件存在性校验：**

对用户提供的每个路径，用 Read 工具检查文件是否存在：
- 不存在 → 告知用户：`⚠️ 文件 <路径> 不存在，请检查路径或重新提供`，重新询问
- 存在 → 继续

**2c. 内容合规性校验：**

读取每个文件内容，判断是否能提取出**模块清单**（即有明确的功能模块划分，每个模块有名称和功能描述）。

合规标准（满足其一即可）：
- 文件中有明确的"模块"、"功能点"、"任务"等章节标题
- 文件中有编号列表（1. 2. 3. 或一、二、三）描述功能
- 文件中有类似 `## 模块X` 的结构

**2d. 不合规时——整理模块列表请用户确认：**

若文件内容无法直接提取模块清单，则：
1. 理解文件内容，将其整理成以下格式：

```
以下是从 <文件名> 中识别出的模块清单，请确认或修改：

模块 1：<模块名>
描述：<一句话功能描述>

模块 2：<模块名>
描述：<一句话功能描述>

...

如需调整（增删改顺序），请直接回复修改后的列表；确认无误请回复"确认"。
```

2. 等待用户确认后，将整理好的模块列表存入 `DESIGN_DOCS_SUMMARY`
3. 该摘要会随原始文档路径一起注入开发者提示词

提取最终值：`DESIGN_DOCS`（原始路径）、`DESIGN_DOCS_SUMMARY`（整理后模块列表，可为空）。

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

### Q4：特殊要求

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
  --special-requirements "<SPECIAL_REQUIREMENTS>"
```

等待脚本输出，将结果反馈给用户。
