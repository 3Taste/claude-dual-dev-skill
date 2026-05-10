#!/usr/bin/env bash
set -euo pipefail

# ── Ghostty ──────────────────────────────────────────────────────────────────

_open_ghostty_window() {
  local title="$1"
  local cd_path="$2"
  local cmd="$3"

  # 用 initial input 在窗口创建时直接注入命令（最干净，无需 delay）
  osascript <<APPLESCRIPT 2>/dev/null
tell application "Ghostty"
  activate
  set cfg to new surface configuration
  set initial working directory of cfg to $(printf '"%s"' "$cd_path")
  set initial input of cfg to $(printf '"%s\n"' "$cmd")
  set win to new window with configuration cfg
end tell
APPLESCRIPT
}

open_ghostty_windows() {
  local worktree_path="$1"
  local dev_cmd="$2"
  local reviewer_cmd="$3"

  if ! command -v osascript > /dev/null 2>&1; then
    return 1
  fi

  # Ghostty 是否已安装
  if ! osascript -e 'tell application "Ghostty" to get version' > /dev/null 2>&1; then
    echo "[dual-dev] 警告：未找到 Ghostty，回退到系统终端" >&2
    return 1
  fi

  echo "[dual-dev] 使用 Ghostty 打开开发者窗口..."
  if ! _open_ghostty_window "dual-dev: Developer" "$worktree_path" "$dev_cmd"; then
    echo "[dual-dev] 警告：Ghostty 窗口打开失败（可能需要辅助功能授权）" >&2
    return 1
  fi

  sleep 0.5

  echo "[dual-dev] 使用 Ghostty 打开审查者窗口..."
  if ! _open_ghostty_window "dual-dev: Reviewer" "$worktree_path" "$reviewer_cmd"; then
    echo "[dual-dev] 警告：Ghostty 审查者窗口打开失败" >&2
    return 1
  fi

  return 0
}

# ── Terminal.app ──────────────────────────────────────────────────────────────

_open_terminal_app_window() {
  local title="$1"
  local cd_path="$2"
  local cmd="$3"

  osascript <<APPLESCRIPT 2>/dev/null
tell application "Terminal"
  activate
  set newTab to do script "cd $(printf '%q' "$cd_path") && $cmd"
  delay 0.3
  set custom title of front window to "$title"
end tell
APPLESCRIPT
}

open_terminal_app_windows() {
  local worktree_path="$1"
  local dev_cmd="$2"
  local reviewer_cmd="$3"

  if ! command -v osascript > /dev/null 2>&1; then
    return 1
  fi

  echo "[dual-dev] 使用 Terminal.app 打开开发者窗口..."
  if ! _open_terminal_app_window "dual-dev: Developer" "$worktree_path" "$dev_cmd"; then
    echo "[dual-dev] 警告：Terminal.app 窗口打开失败（可能需要辅助功能授权）" >&2
    return 1
  fi

  sleep 0.5

  echo "[dual-dev] 使用 Terminal.app 打开审查者窗口..."
  if ! _open_terminal_app_window "dual-dev: Reviewer" "$worktree_path" "$reviewer_cmd"; then
    echo "[dual-dev] 警告：Terminal.app 审查者窗口打开失败" >&2
    return 1
  fi

  return 0
}

# ── 统一入口 ──────────────────────────────────────────────────────────────────

open_dev_and_reviewer_windows() {
  local worktree_path="$1"
  local dev_model="$2"
  local reviewer_model="$3"
  local dev_prompt="$4"
  local reviewer_prompt="$5"
  local terminal_app="${6:-ghostty}"   # ghostty | terminal

  local dev_base reviewer_base dev_cmd reviewer_cmd

  # 模型指定时构建命令，启动失败自动降级到默认模型
  if [[ -n "$dev_model" && "$dev_model" != "default" ]]; then
    dev_base="claude --model $dev_model || claude"
  else
    dev_base="claude"
  fi

  if [[ -n "$reviewer_model" && "$reviewer_model" != "default" ]]; then
    reviewer_base="claude --model $reviewer_model || claude"
  else
    reviewer_base="claude"
  fi

  if [[ -n "$dev_prompt" && -f "$dev_prompt" ]]; then
    dev_cmd="$dev_base \"@$dev_prompt\""
  else
    dev_cmd="$dev_base"
  fi

  if [[ -n "$reviewer_prompt" && -f "$reviewer_prompt" ]]; then
    reviewer_cmd="$reviewer_base \"@$reviewer_prompt\""
  else
    reviewer_cmd="$reviewer_base"
  fi

  local opened=false

  if [[ "$terminal_app" == "ghostty" ]]; then
    if open_ghostty_windows "$worktree_path" "$dev_cmd" "$reviewer_cmd"; then
      opened=true
    else
      echo "[dual-dev] Ghostty 不可用，回退到 Terminal.app..." >&2
      if open_terminal_app_windows "$worktree_path" "$dev_cmd" "$reviewer_cmd"; then
        opened=true
      fi
    fi
  else
    if open_terminal_app_windows "$worktree_path" "$dev_cmd" "$reviewer_cmd"; then
      opened=true
    fi
  fi

  if [[ "$opened" == "true" ]]; then
    echo "[dual-dev] 两个终端窗口已打开，提示词自动注入"
  else
    echo "[dual-dev] 警告：自动打开终端失败，请手动执行：" >&2
    echo "  开发者: cd \"$worktree_path\" && $dev_cmd" >&2
    echo "  审查者: cd \"$worktree_path\" && $reviewer_cmd" >&2
  fi
}
