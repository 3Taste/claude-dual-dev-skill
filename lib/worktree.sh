#!/usr/bin/env bash
set -euo pipefail

create_worktree() {
  local path="$1"
  local branch="$2"
  local base="$3"

  echo "[dual-dev] 创建 worktree: $path (分支: $branch, 基于: $base)"
  git worktree add -b "$branch" "$path" "$base"
  echo "[dual-dev] worktree 创建成功"
}

remove_worktree() {
  local path="$1"

  if [[ -d "$path" ]]; then
    echo "[dual-dev] 清理 worktree: $path"
    git worktree remove --force "$path" 2>/dev/null || rm -rf "$path"
    git worktree prune 2>/dev/null || true
    echo "[dual-dev] worktree 已清理"
  fi
}

remove_branch() {
  local branch="$1"

  if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    echo "[dual-dev] 删除分支: $branch"
    git branch -D "$branch" 2>/dev/null || true
  fi
}
