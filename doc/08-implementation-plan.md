# 08 落地实施计划

## 阶段划分

```
P0 设计冻结 ── P1 骨架搭建 ── P2 核心脚本 ── P3 装载验证 ── P4 跨平台扩展
```

P0–P3 为首版交付范围（macOS only），P4 二期。

## P0 设计冻结

**产出**：本 `/doc` 8 篇文档全部完成 + 用户签字。

**判据**：

- 8 篇编号 00–08 文件齐全
- 命名一致性表（04 文档）所有项无歧义
- 占位符列表（06 文档）与 bootstrap 需求对齐

**当前状态**：进行中。文档完成后请用户审阅一轮再开 P1。

## P1 骨架搭建

**产出**：仓库目录结构 + 空骨架文件。

**任务**：

1. `mkdir -p skill/scripts/lib skill/templates`
2. 占位文件：`skill/SKILL.md`（仅 frontmatter）、`bootstrap.sh`（含 usage）、`lib/*.sh`（空函数）、`rollback.sh`（空函数）
3. `templates/dual-dev-developer-prompt.md.tmpl` / `dual-dev-reviewer-prompt.md.tmpl` 空骨架（按 06 占位符段落）
4. `install.sh` / `uninstall.sh` 软链管理
5. 根 `README.md`（一段话简介 + 装载命令）
6. `LICENSE`、`.gitignore`

**判据**：`bash skill/scripts/bootstrap.sh --help` 能输出 usage；`./install.sh` 软链建成、`ls -l ~/.claude/skills/dual-dev` 验证。

## P2 核心脚本

**产出**：bootstrap 全流程可跑通。

**任务**（建议顺序，每步独立提交）：

| 步 | 文件 | 内容 |
|----|------|------|
| 2.1 | `lib/precheck.sh` | git repo 校验、worktree 路径占用检查、`claude` PATH 检查、macOS 平台判定 |
| 2.2 | `lib/worktree.sh` | `git worktree add -b` 封装 + 错误回传 |
| 2.3 | `lib/render.sh` | 占位符替换（envsubst 主、bash `${//}` 退化）+ 落地 worktree 根 |
| 2.4 | `lib/signals.sh` | `mkdir -p .claude/signals/` + 幂等追加 `.gitignore` 三行 |
| 2.5 | `lib/terminal.sh` | osascript Terminal.app `do script` + 标题设定 + 间隔 sleep |
| 2.6 | `bootstrap.sh` | 解析 7 个 `--` 参数、串联 lib、失败调 rollback、回显 ✓ 列表 |
| 2.7 | `rollback.sh` | 反序回滚（worktree remove --force、best-effort 关窗） |
| 2.8 | `SKILL.md` | frontmatter + 自然语言 4 步问答指令 + 调用 bootstrap.sh |

**判据**：

- 单步：每个 `lib/*.sh` 可独立调用（dry-run 标记）
- 集成：手动跑 `bootstrap.sh --worktree /tmp/test-dd --branch test/dd --base dev --docs "" --dev-model sonnet --reviewer-model sonnet --requirements ""`
  - 成功：worktree 建好、prompt 文件生成、双终端打开、signals 目录就位
  - 失败：rollback 干净，无残留

## P3 装载验证

**产出**：在真实宿主项目跑一遍 `/dual-dev`。

**任务**：

1. `./install.sh` 装载到 `~/.claude/skills/dual-dev`
2. 在 `digital-twin-scheduling-backend` 根敲 `/dual-dev`
3. 走完 4 步问答 → bootstrap → 双终端
4. 用户在两窗口首句 `@dual-dev-developer-prompt.md` / `@dual-dev-reviewer-prompt.md`
5. 跑一个最小 chunk（如改一行注释）走完 ready-1 / review-1 / ready-final / review-final 完整循环
6. `git worktree remove` 清理

**判据**：用户主观体验 ≤ 2 分钟从敲 `/dual-dev` 到双窗口就位；信号握手不卡壳。

**回归项清单**：

- 路径含空格（如 `~/git/has space/...`）
- 分支名含 `/`（`feature/abc`）
- DESIGN_DOCS 多个文档（空格分隔）
- SPECIAL_REQUIREMENTS 空 / 含中文标点
- 模型 4 选 1 + "两窗口分别指定"分支
- 幂等：同 worktree 路径已存在时的提示
- cancel 中断：4 步问答任意一步取消，无副作用

## P4 跨平台扩展（二期）

**产出**：Linux + Windows 兼容。

**任务**：

1. `lib/terminal.sh` 拆 `terminal-macos.sh` / `terminal-linux.sh` / `terminal-windows.sh`，主入口按平台分派
2. Linux：检测 `$XDG_CURRENT_DESKTOP` + 已装 binary，按 gnome-terminal > konsole > xterm > tmux 优先级降级
3. Windows：Windows Terminal `wt` 主选，PowerShell `Start-Process` 备选；WSL 环境走 Linux 分支
4. iTerm2：在 macOS 内按 `$TERM_PROGRAM=iTerm.app` 分支选 iTerm AppleScript
5. `precheck.sh` 加平台分支，移除"非 macOS 即报错"逻辑

**判据**：在三平台至少各一台机上完成 P3 回归项。

## 风险登记

| 风险 | 影响 | 缓解 |
|------|------|------|
| osascript 首次需辅助功能授权 | 用户首次 `/dual-dev` 卡在权限弹窗 | README 装载步骤末尾提示用户预先打开 Terminal.app 一次 |
| `claude` CLI 版本变更导致 `--model` 参数不兼容 | bootstrap 开窗成功但 claude 启动失败 | precheck 阶段 `claude --help` 探测一次，失败提前抛 |
| worktree 路径与 IDE 索引冲突 | IDE 卡顿 | 文档建议默认放 `~/git/<proj>-feature/`，不放在原项目子目录 |
| 用户在错误目录敲 `/dual-dev`（非 git repo） | 报错但易困惑 | precheck 报错文案明确指引："请 cd 到 git 项目根目录" |
| 信号文件被误 commit | 历史污染 | `.gitignore` 自动追加 + ready/reviewer prompt 中再强调 |
| 模板渲染时占位符值含特殊字符 | sed 命令爆炸 | render.sh 优先纯 bash `${//}`；写测试用例覆盖 `&` `/` `\` `"` `'` `` ` `` |
| 双终端启动竞态 | 第二个窗口 cd 失败 | `sleep 0.5` 间隔，仍失败时让用户手工 cd |

## 不在范围

- CI / GitHub Actions
- 自动化测试套件（脚本太薄，靠手动 P3 回归）
- 多 worktree 并行开发（单次 `/dual-dev` 只建一个）
- 信号文件结构化解析（保持 markdown 自由文本）
- 自动 commit / PR 创建（用户手工走常规流程）
- prompt 正文（用户自填）

## 里程碑

| 里程碑 | 内容 | 阻塞下一步 |
|-------|------|----------|
| M0 | P0 完成（8 文档） | 是，未冻结不开 P1 |
| M1 | P1 完成（骨架可装载） | 是 |
| M2 | P2.1–2.5 完成（lib 单测） | 否，可与 2.6 并行 |
| M3 | P2 完成（bootstrap 串通） | 是 |
| M4 | P3 完成（真实项目跑通 + 回归） | 首版交付节点 |
| M5 | P4 完成（跨平台） | 二期收尾 |

## 提交节奏

每个 P2 子任务一个 commit，messages 用 conventional commits（`feat:` / `fix:` / `docs:` / `chore:`）。P3 回归发现的 bug 单独 `fix:` 提交，不混入 P2。

## 验收

P3 通过后，本仓库主分支打 `v0.1.0` tag，README 标"首版可用，macOS only"。P4 完成后打 `v0.2.0`。
