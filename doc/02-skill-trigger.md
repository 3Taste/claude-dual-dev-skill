# 02 触发机制与问答交互

## 触发：固定 slash command

**`/dual-dev`** 是唯一入口。不做关键词检索（如 "双窗口"/"协作开发"），原因：

- 关键词触发存在歧义，可能被误激活
- slash command 在 Claude Code 中是一等公民，UI 提示明确
- 固定短语便于记忆和文档化

技术实现：在 `~/.claude/skills/dual-dev/SKILL.md` 中声明 skill 名为 `dual-dev`，Claude Code 自动注册 `/dual-dev` 入口。

## 4 步问答

按序串行问，每步用 AskUserQuestion 提供候选 + 自由输入。每步收到答复后再问下一题，避免一次性大表单。

### Q1: worktree 路径 + 分支名

**目的**：确定隔离工作区位置和新分支名。

**推荐策略**（基于当前 cwd 和 branch 自动生成候选）：

- 当前项目目录名 `<proj>`，当前分支 `<base>`
- worktree 路径默认 `~/git/<proj>-feature/`
- 分支名默认 `feature/module-dev`

**问法**：

```
Q: 工作区路径和分支名？
候选:
  1) ~/git/<proj>-feature/  +  feature/module-dev   (推荐)
  2) ~/git/<proj>-wt/       +  feature/<custom>
  3) 自定义两者
```

**输出**：`WORKTREE_PATH`、`BRANCH_NAME`、`BASE_BRANCH`（取自当前分支）。

### Q2: 设计文档路径

**目的**：开发 prompt 注入设计文档引用，开发者据此实现。

**问法**：

```
Q: 模块设计文档路径？(相对项目根，可多个用空格分隔)
候选:
  1) doc/<最近修改的设计文档>
  2) 不指定（开发者自行探索）
  3) 自定义
```

候选 1 自动扫 `doc/**/*.md` 取最近 mtime 的 1-3 个。

**输出**：`DESIGN_DOCS`（数组，可空）。

### Q3: Claude 模型

**目的**：决定两窗口启动 `claude` 时的 `--model` 参数。

**问法**：

```
Q: Claude 模型？
候选:
  1) sonnet 4.6 (默认，平衡)
  2) opus 4.7 (深度推理)
  3) haiku 4.5 (快速、低成本)
  4) 两窗口分别指定
```

候选 4 进入子问答，开发窗口和审查窗口各选一次。

**输出**：`DEV_MODEL`、`REVIEWER_MODEL`。

### Q4: 特殊要求

**目的**：传递任务级约束（如"不要改测试"、"必须用 TDD"、"避开模块 X"）。

**问法**：

```
Q: 特殊要求？(回车跳过)
[自由文本]
```

**输出**：`SPECIAL_REQUIREMENTS`（字符串，可空）。

## 参数收齐后

把 4 步答复合成一个参数对象，调用 `scripts/bootstrap.sh`：

```
bootstrap.sh \
  --worktree <WORKTREE_PATH> \
  --branch <BRANCH_NAME> \
  --base <BASE_BRANCH> \
  --docs "<DESIGN_DOCS>" \
  --dev-model <DEV_MODEL> \
  --reviewer-model <REVIEWER_MODEL> \
  --requirements "<SPECIAL_REQUIREMENTS>"
```

bootstrap 完成后向用户回显两窗口已开启 + 信号目录路径。

## 中断与重试

- 任意问答步骤用户输入 `cancel` / `取消` → 终止整个 skill，不创建 worktree
- bootstrap 中途失败（worktree 已存在、终端打不开）→ 回滚（删 worktree、关半开的终端），向用户报错并提示重试

## 幂等

同一 worktree 路径已存在时：

- 提示用户：复用 / 删除重建 / 换名
- 默认拒绝复用（避免污染先前会话）
