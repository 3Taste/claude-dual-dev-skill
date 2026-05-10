# 04 文件结构与职责

## 项目根目录

```
~/git/claude-dual-dev-skill/
├── README.md                      # 项目对外简介、装载方法
├── doc/                           # 本设计文档（8 篇）
│   ├── 00-README.md
│   ├── 01-overview.md
│   ├── 02-skill-trigger.md
│   ├── 03-workflow.md
│   ├── 04-file-structure.md       ← 本文
│   ├── 05-terminal-automation.md
│   ├── 06-prompt-templates.md
│   ├── 07-signaling-protocol.md
│   └── 08-implementation-plan.md
├── skill/                         # 待装载到 ~/.claude/skills/dual-dev/ 的内容
│   ├── SKILL.md                   # skill 定义（触发 + 4 步问答描述）
│   ├── scripts/
│   │   ├── bootstrap.sh           # 主入口：解析参数 → 串联 2.1–2.5
│   │   ├── lib/
│   │   │   ├── precheck.sh        # T2.1 前置校验
│   │   │   ├── worktree.sh        # T2.2 git worktree add 封装
│   │   │   ├── render.sh          # T2.3 模板渲染（envsubst 或纯 bash）
│   │   │   ├── signals.sh         # T2.4 信号目录初始化 + .gitignore 维护
│   │   │   └── terminal.sh        # T2.5 osascript 封装
│   │   └── rollback.sh            # 失败回滚（删 worktree、关半开终端）
│   └── templates/
│       ├── dual-dev-developer-prompt.md.tmpl
│       └── dual-dev-reviewer-prompt.md.tmpl
├── install.sh                     # 把 skill/ 内容软链到 ~/.claude/skills/dual-dev/
├── uninstall.sh                   # 移除软链
├── LICENSE
└── .gitignore
```

## skill 装载位置

`install.sh` 执行：

```bash
ln -sfn $(pwd)/skill ~/.claude/skills/dual-dev
```

软链而非复制，便于本仓库迭代后立即生效，不需要每次重装。

## 各文件职责

### `skill/SKILL.md`

skill 元数据 + 自然语言描述。Claude Code 读它注册 `/dual-dev`。
内容包含：
- frontmatter：`name: dual-dev`、`description`、`trigger: /dual-dev`
- 自然语言指令：调用 AskUserQuestion 串行问 4 题、把答复传 `bootstrap.sh`、回显结果
- 不含可执行代码（执行在 `scripts/bootstrap.sh`）

### `scripts/bootstrap.sh`

POSIX bash，外部依赖：`git`、`osascript`(macOS)、`mkdir`。
入参（命名参数）：

```
--worktree <path>
--branch <name>
--base <branch>
--docs "<doc1> <doc2> ..."
--dev-model <model>
--reviewer-model <model>
--requirements "<text>"
```

逐步调 `lib/` 下脚本。任一失败 → `rollback.sh`。退出码：0 成功，非 0 各步骤失败。

### `scripts/lib/precheck.sh`

校验 cwd 是 git repo、worktree 路径未占用、claude 在 PATH、平台是 macOS。

### `scripts/lib/worktree.sh`

封装 `git worktree add -b <branch> <path> <base>`。出错回 stderr 上抛。

### `scripts/lib/render.sh`

模板替换。占位符见 06。优先用 `envsubst`，不可用时退化为 sed/bash 字符串替换。
不引入 jinja/handlebars 等外部依赖（保持脚本可移植）。

### `scripts/lib/signals.sh`

`mkdir -p .claude/signals` + 在 worktree `.gitignore` 追加：

```
.claude/signals/
dual-dev-developer-prompt.md
dual-dev-reviewer-prompt.md
```

幂等（已存在的行不重复加）。

### `scripts/lib/terminal.sh`

osascript 拼装并 `osascript -e ...` 执行。两窗口逐个开（间隔 0.5s 避免 race）。详见 05。

### `scripts/rollback.sh`

按反序回滚：
1. `git worktree remove --force <path>` 若已建
2. 关 osascript 已开但未配置完成的窗口（best-effort，记录窗口 ID）
3. 不删 `.claude/signals/`（worktree 整体会随 worktree 删除被回收）

### `templates/*.tmpl`

模板正文用户自填（首版交付带占位骨架，详见 06）。文件落地时去掉 `.tmpl` 后缀。

### `install.sh` / `uninstall.sh`

软链管理。`install.sh` 检测 `~/.claude/skills/dual-dev` 已存在时报错（避免覆盖）。

## 装载后的运行时布局

宿主项目运行 `/dual-dev` 后，文件落点：

```
~/.claude/skills/dual-dev/      → 软链到本项目 skill/
<WORKTREE_PATH>/                ← 由 bootstrap 创建
├── (宿主项目的全部文件)
├── dual-dev-developer-prompt.md
├── dual-dev-reviewer-prompt.md
├── .claude/
│   └── signals/                ← 双窗口握手目录
└── .gitignore                  ← 追加 3 行忽略
```

宿主项目根目录无新增、无修改（worktree 隔离）。

## 不放在 skill 目录的内容

- 用户的设计文档（仍在宿主项目）
- 信号文件（仅在 worktree 内）
- 任务清单 / commit 历史（git 自身管）
- prompt 正文（用户自填到 `templates/*.tmpl`）

## 命名一致性

| 实体 | 名 |
|------|----|
| 项目仓库 | `claude-dual-dev-skill` |
| skill 注册名 | `dual-dev` |
| 触发 | `/dual-dev` |
| 主脚本 | `bootstrap.sh` |
| 开发 prompt | `dual-dev-developer-prompt.md` |
| 审查 prompt | `dual-dev-reviewer-prompt.md` |
| 信号目录 | `.claude/signals/` |
| ready 信号 | `ready-<n>.md` / `ready-final.md` |
| review 信号 | `review-<n>.md` / `review-final.md` |
