# 06 Prompt 模板规范

## 文件命名

| 角色 | 模板文件 | 渲染落地文件 |
|------|---------|------------|
| 开发者 | `templates/dual-dev-developer-prompt.md.tmpl` | `<WORKTREE_PATH>/dual-dev-developer-prompt.md` |
| 审查者 | `templates/dual-dev-reviewer-prompt.md.tmpl` | `<WORKTREE_PATH>/dual-dev-reviewer-prompt.md` |

`.tmpl` 后缀仅模板源用；渲染输出去后缀。落 worktree 根而非子目录，方便用户首句 `@dual-dev-developer-prompt.md` 路径短。

## 占位符规范

bootstrap 渲染时替换。所有占位符用 `{{NAME}}` 包裹（避开 shell `$VAR` 与 markdown `${...}` 歧义），渲染脚本用 sed/envsubst 适配。

| 占位符 | 来源 | 用途 |
|-------|------|-----|
| `{{ROLE}}` | bootstrap 内置（`developer` / `reviewer`） | 角色标识，prompt 首段固定文案引用 |
| `{{BASE_BRANCH}}` | Q1 | 基线分支名 |
| `{{BRANCH_NAME}}` | Q1 | 当前工作分支 |
| `{{WORKTREE_PATH}}` | Q1 | 隔离工作区绝对路径 |
| `{{DESIGN_DOCS}}` | Q2 | 设计文档路径列表（空格分隔，可空） |
| `{{DEV_MODEL}}` | Q3 | 开发窗口模型 |
| `{{REVIEWER_MODEL}}` | Q3 | 审查窗口模型 |
| `{{SPECIAL_REQUIREMENTS}}` | Q4 | 用户特殊要求（可空） |
| `{{SIGNALS_DIR}}` | bootstrap 固定 `.claude/signals` | 信号目录相对路径 |
| `{{COUNTERPART_PROMPT}}` | bootstrap 内置 | 对端 prompt 文件名（开发引审查、反之亦然） |

空值处理：`{{DESIGN_DOCS}}` / `{{SPECIAL_REQUIREMENTS}}` 为空时替换为字面 `（无）`，不留空字符串避免段落塌缩。

## 渲染策略

`scripts/lib/render.sh` 顺序：

1. 优先 `envsubst`：先把 `{{NAME}}` 转 `${NAME}`，再 envsubst → 输出
2. 退化 sed：逐占位符 `sed -e "s|{{NAME}}|$VALUE|g"`，VALUE 含特殊字符先 escape
3. 渲染失败抛错 → bootstrap 触发 rollback（删 worktree）

值含 `|` / 换行 / 反斜杠时优先纯 bash 字符串替换（`${var//pat/repl}`），避免 sed 分隔符冲突。

## 用户填充点 vs 自动渲染

模板分两类内容：

- **用户自填**（首版仓库交付占位骨架，用户日后改）：角色定位段、任务分解策略、完成判据、代码风格约束、TDD 偏好等业务正文
- **自动渲染**（bootstrap 替换）：仅占位符所在行 / 段落

模板内用 HTML 注释标注：

```markdown
<!-- USER-FILL: 角色定位 -->
你是本仓库的{{ROLE}}...
<!-- /USER-FILL -->

<!-- AUTO-RENDER -->
基线分支：{{BASE_BRANCH}}
工作分支：{{BRANCH_NAME}}
设计文档：{{DESIGN_DOCS}}
特殊要求：{{SPECIAL_REQUIREMENTS}}
<!-- /AUTO-RENDER -->
```

注释保留在落地文件中无害（markdown 渲染忽略），方便用户回看哪段可改。

## 开发者 prompt 骨架

```markdown
<!-- AUTO-RENDER -->
# Dual-Dev 开发者角色

- 工作分支：{{BRANCH_NAME}}（基于 {{BASE_BRANCH}}）
- 工作目录：{{WORKTREE_PATH}}
- 设计文档：{{DESIGN_DOCS}}
- 特殊要求：{{SPECIAL_REQUIREMENTS}}
- 信号目录：{{SIGNALS_DIR}}
- 对端 prompt：{{COUNTERPART_PROMPT}}
<!-- /AUTO-RENDER -->

<!-- USER-FILL: 角色与任务 -->
（用户填：开发者人设、任务边界、TDD 偏好、commit 粒度...）
<!-- /USER-FILL -->

<!-- USER-FILL: 协作协议 -->
完成一个 chunk 后，写 {{SIGNALS_DIR}}/ready-<n>.md，详见 07-signaling-protocol.md。
扫 {{SIGNALS_DIR}}/review-*.md 取审查反馈，PASS 则进下一 chunk，CHANGES 则修后再写 ready-<n+1>.md。
全部完成时写 ready-final.md。
<!-- /USER-FILL -->

<!-- USER-FILL: 完成判据 -->
（用户填：何为"完成"——例如所有测试通过 / 设计文档覆盖率 / lint 0 warning 等）
<!-- /USER-FILL -->
```

## 审查者 prompt 骨架

```markdown
<!-- AUTO-RENDER -->
# Dual-Dev 审查者角色

- 工作分支：{{BRANCH_NAME}}（基于 {{BASE_BRANCH}}）
- 工作目录：{{WORKTREE_PATH}}
- 设计文档：{{DESIGN_DOCS}}
- 特殊要求：{{SPECIAL_REQUIREMENTS}}
- 信号目录：{{SIGNALS_DIR}}
- 对端 prompt：{{COUNTERPART_PROMPT}}
<!-- /AUTO-RENDER -->

<!-- USER-FILL: 角色与立场 -->
（用户填：审查者人设、关注维度——安全 / 性能 / 可维护性 / 测试覆盖...）
<!-- /USER-FILL -->

<!-- USER-FILL: 协作协议 -->
扫 {{SIGNALS_DIR}}/ready-*.md，按编号顺序处理。
读对应代码 + ready 内容 → 写 {{SIGNALS_DIR}}/review-<n>.md，标 PASS 或 CHANGES。
CHANGES 必列具体改动点 + 理由。
全部 PASS 后写 review-final.md。
<!-- /USER-FILL -->

<!-- USER-FILL: 通过判据 -->
（用户填：何为 PASS——例如无 CRITICAL/HIGH 风险 + 测试覆盖 ≥80% + 命名清晰...）
<!-- /USER-FILL -->
```

## 反例

- 不要把占位符放在代码块（``` 围栏内）：sed 替换无差别命中，可能误改用户示例
- 不要嵌套 `{{ {{X}} }}`：渲染顺序不定
- 不要在占位符值里塞引号未转义：sed 容易被分隔符吞掉

## 版本演进

模板正文用户改，本仓库提供初版骨架。日后若占位符增减：

- 在本文档表格新增行
- 同步改 `lib/render.sh` 替换列表
- 模板 `.tmpl` 加新占位符 + AUTO-RENDER 注释
- 用户已落地的 prompt 文件不自动迁移（worktree 一次性产物，下次 `/dual-dev` 重新渲染）
