# claude-dual-dev-skill 设计文档

双窗口 Claude Code 协作开发流落地为 Claude Code Skill。固定短语 `/dual-dev` 触发，4 步问答收参，自动建 worktree、开两终端、注入开发/审查双 prompt。

## 文档导航

| # | 文档 | 内容 |
|---|------|------|
| 01 | [overview.md](01-overview.md) | 背景、目标、整体架构、非目标 |
| 02 | [skill-trigger.md](02-skill-trigger.md) | `/dual-dev` 触发机制、4 步问答交互 |
| 03 | [workflow.md](03-workflow.md) | 端到端工作流（问答→建 worktree→开终端→注入 prompt→握手） |
| 04 | [file-structure.md](04-file-structure.md) | skill 项目目录结构、文件清单、职责 |
| 05 | [terminal-automation.md](05-terminal-automation.md) | osascript 自动化、跨平台兼容方案 |
| 06 | [prompt-templates.md](06-prompt-templates.md) | prompt 文件命名、模板占位符、用户填充点 |
| 07 | [signaling-protocol.md](07-signaling-protocol.md) | `.claude/signals/` 握手协议 |
| 08 | [implementation-plan.md](08-implementation-plan.md) | 分阶段落地、里程碑、依赖 |

## 关键约定

- **触发**：固定 slash command `/dual-dev`，非关键词检索
- **项目名**：`claude-dual-dev-skill`（独立项目，与宿主项目解耦）
- **Prompt 文件名**：`dual-dev-developer-prompt.md` / `dual-dev-reviewer-prompt.md`（带 skill 名前缀，避免冲突）
- **Prompt 正文**：用户自行提供，本设计只定模板占位符规范
- **平台**：macOS 优先（osascript），Linux/Windows 后续

## 阅读顺序

新读者：01 → 02 → 03 → 04 → 06 → 07 → 05 → 08
实现者：04 → 02 → 03 → 05 → 06 → 07 → 08
