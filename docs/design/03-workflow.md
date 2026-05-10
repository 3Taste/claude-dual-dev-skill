# 03 端到端工作流

## 阶段总览

```
[T0] 用户在宿主项目根敲 /dual-dev
  │
  ▼
[T1] SKILL.md 加载，串行 4 步问答（Q1→Q4）
  │
  ▼
[T2] bootstrap.sh 收齐参数，开始执行
  ├── 2.1 校验前置条件
  ├── 2.2 git worktree add
  ├── 2.3 渲染 prompt 模板写入 worktree
  ├── 2.4 mkdir .claude/signals/
  └── 2.5 osascript 开两终端
  │
  ▼
[T3] 用户在两窗口分别首句 @<prompt 文件> 注入角色
  │
  ▼
[T4] 双窗口信号握手循环（开发 ↔ 审查）
  │
  ▼
[T5] 终止：审查通过 → 用户手工 commit/push/PR → 清理 worktree
```

## T1 问答阶段

详见 02-skill-trigger.md。结束态：内存中持有 7 个变量
`WORKTREE_PATH` / `BRANCH_NAME` / `BASE_BRANCH` / `DESIGN_DOCS` / `DEV_MODEL` / `REVIEWER_MODEL` / `SPECIAL_REQUIREMENTS`。

## T2 bootstrap 执行序列

### 2.1 前置校验

- 当前 cwd 是 git 仓库根（否则报错退出）
- `WORKTREE_PATH` 不存在或为空目录（否则按幂等策略问用户）
- `BRANCH_NAME` 不与远端/本地分支冲突（冲突则提示）
- macOS 平台（非 macOS 走 05 中的兼容分支或报错）
- `claude` CLI 在 PATH 中（否则报错）

任一失败 → 退出码非 0，回显原因，不修改文件系统。

### 2.2 创建 worktree

```bash
git worktree add -b <BRANCH_NAME> <WORKTREE_PATH> <BASE_BRANCH>
```

成功后 `<WORKTREE_PATH>` 是工作目录，HEAD 指向 `<BRANCH_NAME>`。

### 2.3 渲染并写入 prompt 模板

读 `~/.claude/skills/dual-dev/templates/dual-dev-developer-prompt.md.tmpl` 与 `dual-dev-reviewer-prompt.md.tmpl`，
按 06 中的占位符规范替换，输出到：

```
<WORKTREE_PATH>/dual-dev-developer-prompt.md
<WORKTREE_PATH>/dual-dev-reviewer-prompt.md
```

文件落 worktree 根目录原因：
- 用户首句 `@dual-dev-developer-prompt.md` 路径短
- 不污染宿主仓库（worktree 是独立 checkout）
- 用 `.gitignore` 同步忽略两文件，避免误 commit（bootstrap 追加忽略行）

### 2.4 初始化信号目录

```bash
mkdir -p <WORKTREE_PATH>/.claude/signals
```

并在 `.gitignore` 追加 `.claude/signals/`。详见 07。

### 2.5 开两终端

osascript 打开 Terminal.app 两个新窗口，分别执行：

```bash
# 窗口 A（开发）
cd <WORKTREE_PATH> && claude --model <DEV_MODEL>

# 窗口 B（审查）
cd <WORKTREE_PATH> && claude --model <REVIEWER_MODEL>
```

bootstrap 不向 claude 传任何首句（`-p` 非交互不适用）。具体见 05。

bootstrap 结束回显：

```
✓ worktree 已建：<WORKTREE_PATH>
✓ 分支：<BRANCH_NAME> (基于 <BASE_BRANCH>)
✓ prompt 文件已写入：dual-dev-developer-prompt.md / dual-dev-reviewer-prompt.md
✓ 信号目录：<WORKTREE_PATH>/.claude/signals/
✓ 两终端已开启
请在两窗口分别首句输入：
  开发窗口: @dual-dev-developer-prompt.md
  审查窗口: @dual-dev-reviewer-prompt.md
```

## T3 角色注入

用户手动在两窗口分别敲首句：

- 开发窗口：`@dual-dev-developer-prompt.md`
- 审查窗口：`@dual-dev-reviewer-prompt.md`

`@` 引用让 Claude Code 把整份 prompt 文件当首条上下文加载。两份 prompt 内含：

- 角色定位（开发者 / 审查者）
- 任务描述（替换自 `DESIGN_DOCS` / `SPECIAL_REQUIREMENTS`）
- 信号握手协议（指向 07）
- 完成判据

## T4 信号握手循环

握手单轮：

```
开发者完成一个 chunk
  └──> 写 .claude/signals/ready-<n>.md
        包含：实现要点、文件清单、自测结果、待审查问题
        │
        ▼
审查者扫 .claude/signals/ready-*.md
  └──> 阅读代码 + ready 文件
        ├── 通过 → 写 review-<n>.md，标 PASS
        └── 不通过 → 写 review-<n>.md，标 CHANGES，列改动点
        │
        ▼
开发者扫 review-*.md
  ├── PASS → 进下一 chunk
  └── CHANGES → 修改后再写 ready-<n+1>.md
```

文件命名 `ready-<n>.md` / `review-<n>.md`，n 单调递增。详见 07。

## T5 终止与清理

判定终止：所有 chunk 的 review-*.md 均 PASS，且开发者写 `ready-final.md` 标"全部完成"，审查者写 `review-final.md` 标 PASS。

之后由用户在 worktree 内手工：

```bash
git add -A
git commit -m "..."
git push -u origin <BRANCH_NAME>
gh pr create ...
```

PR 合并后清理：

```bash
git worktree remove <WORKTREE_PATH>
git branch -d <BRANCH_NAME>   # 已 merge 才能 -d，否则用户判断是否 -D
```

skill 不自动清理（避免误删未 push 工作）。

## 异常路径

| 阶段 | 异常 | 处理 |
|------|------|------|
| T2.1 | 前置校验失败 | 退出，回显原因 |
| T2.2 | worktree 创建失败 | 退出，回滚（无残留） |
| T2.3 | 模板渲染失败 | 删除已建 worktree，回滚 |
| T2.5 | 终端开启失败 | 保留 worktree（用户可手工 cd 进入），回显提示 |
| T3 | 用户忘记首句 `@` | 窗口里 claude 无角色，无害；用户随时补 |
| T4 | 信号文件冲突（同名） | 命名带递增编号，不会冲突 |
| T5 | worktree 有未提交改动 | `git worktree remove` 自动拒绝，提示用户先处理 |
