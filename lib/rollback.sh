#!/usr/bin/env bash
set -euo pipefail

rollback() {
  local worktree_path="$1"
  local branch_name="${2:-}"

  echo "[dual-dev] 回滚中..."

  # 删除渲染后的提示词文件
  local dev_prompt="$worktree_path/.claude/dual-dev-developer-prompt.md"
  local reviewer_prompt="$worktree_path/.claude/dual-dev-reviewer-prompt.md"
  [[ -f "$dev_prompt" ]] && rm -f "$dev_prompt" && echo "[dual-dev] 已删除开发者提示词"
  [[ -f "$reviewer_prompt" ]] && rm -f "$reviewer_prompt" && echo "[dual-dev] 已删除审查者提示词"

  # 删除信号目录
  local signals_dir="$worktree_path/.claude/signals"
  [[ -d "$signals_dir" ]] && rm -rf "$signals_dir" && echo "[dual-dev] 已删除信号目录"

  # 删除 worktree（需要在主仓库目录执行 git 命令）
  if [[ -d "$worktree_path" ]]; then
    git worktree remove --force "$worktree_path" 2>/dev/null || rm -rf "$worktree_path"
    git worktree prune 2>/dev/null || true
    echo "[dual-dev] 已删除 worktree: $worktree_path"
  fi

  # 删除分支
  if [[ -n "$branch_name" ]] && git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    git branch -D "$branch_name" 2>/dev/null || true
    echo "[dual-dev] 已删除分支: $branch_name"
  fi

  echo "[dual-dev] 回滚完成"
}
