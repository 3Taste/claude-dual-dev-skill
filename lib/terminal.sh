#!/usr/bin/env bash
set -euo pipefail

open_terminal_window() {
  local title="$1"
  local cd_path="$2"
  local cmd="$3"

  if ! osascript <<APPLESCRIPT 2>/dev/null
tell application "Terminal"
  activate
  set newTab to do script "cd $(printf '%q' "$cd_path") && $cmd"
  delay 0.3
  set custom title of front window to "$title"
end tell
APPLESCRIPT
  then
    echo "[dual-dev] 警告：无法通过 osascript 打开终端窗口（可能需要辅助功能授权）" >&2
    echo "[dual-dev] 请手动打开终端，cd 到 $cd_path，然后运行：$cmd" >&2
    return 0
  fi
}

open_dev_and_reviewer_windows() {
  local worktree_path="$1"
  local dev_model="$2"
  local reviewer_model="$3"
  local dev_prompt="$4"
  local reviewer_prompt="$5"

  local dev_cmd reviewer_cmd

  if [[ -n "$dev_model" && "$dev_model" != "default" ]]; then
    dev_cmd="claude --model $dev_model"
  else
    dev_cmd="claude"
  fi

  if [[ -n "$reviewer_model" && "$reviewer_model" != "default" ]]; then
    reviewer_cmd="claude --model $reviewer_model"
  else
    reviewer_cmd="claude"
  fi

  echo "[dual-dev] 打开开发者终端窗口..."
  open_terminal_window "dual-dev: Developer" "$worktree_path" "$dev_cmd"

  sleep 0.5

  echo "[dual-dev] 打开审查者终端窗口..."
  open_terminal_window "dual-dev: Reviewer" "$worktree_path" "$reviewer_cmd"

  echo "[dual-dev] 两个终端窗口已打开"
}
