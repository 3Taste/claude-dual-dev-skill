#!/usr/bin/env bash
set -euo pipefail

setup_signals() {
  local worktree_path="$1"
  local signals_dir="$worktree_path/.claude/signals"

  echo "[dual-dev] 创建信号目录: $signals_dir"
  mkdir -p "$signals_dir"
  echo "[dual-dev] 信号目录创建成功"
}

add_gitignore() {
  local worktree_path="$1"
  local gitignore="$worktree_path/.gitignore"
  local entry=".claude/signals/"

  if [[ -f "$gitignore" ]]; then
    if ! grep -qF "$entry" "$gitignore"; then
      printf "\n# dual-dev 信号文件（自动生成，勿提交）\n%s\n" "$entry" >> "$gitignore"
      echo "[dual-dev] 已将 $entry 追加到 .gitignore"
    else
      echo "[dual-dev] .gitignore 中已存在 $entry，跳过"
    fi
  else
    printf "# dual-dev 信号文件（自动生成，勿提交）\n%s\n" "$entry" > "$gitignore"
    echo "[dual-dev] 已创建 .gitignore 并写入 $entry"
  fi
}

setup_claude_dir() {
  local worktree_path="$1"
  mkdir -p "$worktree_path/.claude"
}
