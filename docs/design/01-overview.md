# 01 概览

## 背景

单窗口 Claude Code 开发流痛点：

- 同窗口边写边审，上下文混淆，审查者人格被开发者污染
- 跨分支切换打断思路，stash/checkout 频繁
- 开发与审查无强制握手，容易跳过审查直接 commit
- 双人协作靠口头同步，签字过程无痕迹

已验证手工方案：

1. `git worktree add` 拉独立工作区 + 新分支
2. 开两个 Claude Code 终端，各自 cd 不同目录
3. 窗口 A 注入开发 prompt，窗口 B 注入审查 prompt
4. 通过 `.claude/signals/ready-*.md` / `review-*.md` 文件握手

手工跑一次需 5-10 分钟，记不住参数、容易打错路径。

## 目标

把上述手工流程封装成 Claude Code Skill，达到：

- 一条 `/dual-dev` 触发整套流程
- 4 步问答收齐参数（worktree+分支名、设计文档路径、模型、特殊要求）
- 自动建 worktree、开两终端、注入 prompt、初始化信号目录
- 用户在两窗口直接进入开发/审查角色，无需手动 cd / 复制 prompt
- 跨项目复用：宿主项目无侵入，skill 装在 `~/.claude/skills/dual-dev/` 全局可用

## 整体架构

```
用户输入 /dual-dev
        │
        ▼
  ~/.claude/skills/dual-dev/SKILL.md
        │
        ▼
  4 步问答 (AskUserQuestion)
   ├── Q1 worktree 路径 + 分支名
   ├── Q2 设计文档路径
   ├── Q3 Claude 模型 (默认 sonnet 4.6)
   └── Q4 特殊要求 (可空)
        │
        ▼
  scripts/bootstrap.sh <参数...>
   ├── git worktree add
   ├── 渲染 prompt 模板 → 写入 worktree
   ├── mkdir .claude/signals/
   └── osascript 开两终端
        │
        ▼
  窗口 A (开发)            窗口 B (审查)
   cd <worktree>           cd <worktree>
   claude                  claude
   首句: @<dev-prompt>     首句: @<reviewer-prompt>
        │                       │
        └──── 文件信号握手 ─────┘
              .claude/signals/
```

## 非目标

首版**不做**：

- 非 macOS 平台（Linux / Windows 留接口，二期）
- 单人模式（已有原生 Claude Code 即可）
- 跨机器协作（worktree 仅限本机）
- 自动 PR / 自动 merge（审查通过后用户手工走常规 git 流程）
- prompt 正文设计（用户自行编写两份 prompt 模板，本 skill 只搭骨架）
- 信号文件结构化解析（保持 markdown 自由文本，靠人 + AI 阅读）

## 成功判据

- 用户在任意 git 项目根目录敲 `/dual-dev`，2 分钟内两窗口就位
- 两窗口分别能识别自身角色，按 prompt 进入工作
- 审查未通过前开发窗口能感知（信号文件可见）
- 流程结束后 worktree 可一键清理（`git worktree remove`）
