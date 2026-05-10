#!/usr/bin/env bash
set -euo pipefail

check_git_repo() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "[dual-dev] 错误：请在 git 项目根目录下运行 /dual-dev" >&2
    exit 1
  fi
}

check_claude_bin() {
  if ! command -v claude > /dev/null 2>&1; then
    echo "[dual-dev] 警告：未找到 claude 命令，终端窗口启动后需手动运行 claude" >&2
  fi
}

check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "[dual-dev] 警告：当前系统非 macOS，自动打开终端窗口功能不可用，请手动打开两个终端" >&2
    return 1
  fi
  return 0
}

check_worktree_available() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "[dual-dev] 错误：路径已存在：$path" >&2
    echo "[dual-dev] 请选择其他 worktree 路径，或先删除该目录" >&2
    exit 1
  fi
}

check_branch_available() {
  local branch="$1"
  if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    echo "[dual-dev] 错误：分支 '$branch' 已存在，请使用其他分支名" >&2
    exit 1
  fi
}

run_prechecks() {
  local worktree_path="$1"
  local branch_name="$2"

  check_git_repo
  check_claude_bin
  check_worktree_available "$worktree_path"
  check_branch_available "$branch_name"
}
