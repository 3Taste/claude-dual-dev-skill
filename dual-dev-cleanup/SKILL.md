---
name: dual-dev-cleanup
version: "1.0.0"
description: >
  dual-dev 工作流清理工具：清除 worktree、删除本地分支、归档信号文件。
  在开发审查流程结束后使用，一键还原干净状态。
when_to_use: >
  用户完成 dual-dev 工作流后，想清理 worktree 和分支时触发。
  关键词：清理 worktree、删除分支、dual-dev 清理、结束工作流。
allowed-tools: Bash, Read, AskUserQuestion
---

# /dual-dev-cleanup — 工作流清理

**【语言约束】全程中文。**

---

## 安全约束

- `git branch -d`（非强制删除）可执行；若有未合并提交会报错保护，**不用 `-D`**
- 不删除主仓库文件，只清理 worktree 目录和信号文件
- 任何删除操作前均需用户确认

---

## 步骤

### Step 1：发现 worktree

执行：
```bash
git worktree list
```

列出所有 worktree，排除主仓库（第一行），展示给用户选择。

用 `AskUserQuestion` 询问：

```
问题：请选择要清理的 worktree：
选项：
  <逐个列出非主仓库的 worktree 路径 + 分支名>
  全部清理
```

### Step 2：确认清理范围

用 `AskUserQuestion` 确认：

```
问题：即将清理以下内容，确认继续？
  - worktree 目录：<路径>（将被删除）
  - 本地分支：<分支名>（将尝试删除，有未合并提交会跳过）
  - 信号文件：<路径>/.claude/signals/（将被删除）
选项：
  1. 确认，开始清理
  2. 取消
```

### Step 3：执行清理

```bash
# 删除 worktree
git worktree remove "<worktree_path>"

# 清理悬空引用
git worktree prune

# 尝试删除本地分支（非强制，有保护）
git branch -d "<branch_name>"
```

若 `git branch -d` 失败（未合并提交），告知用户并询问：

```
问题：分支 <branch_name> 有未合并提交，如何处理？
选项：
  1. 保留分支（推荐）
  2. 强制删除（会丢失未合并提交）
```

### Step 4：完成提示

输出清理结果摘要：
- 已删除的 worktree
- 已删除/保留的分支
- 建议：若已完成开发，记得合并分支到主线
