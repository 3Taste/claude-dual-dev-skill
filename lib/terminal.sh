#!/usr/bin/env bash
set -euo pipefail

# ── Ghostty ──────────────────────────────────────────────────────────────────

_open_ghostty_window() {
  local title="$1"
  local cd_path="$2"
  local cmd="$3"

  # AppleScript 字符串中，双引号须转义为 \"
  local escaped_cmd="${cmd//\"/\\\"}"
  local escaped_path="${cd_path//\"/\\\"}"

  osascript <<APPLESCRIPT 2>/dev/null
tell application "Ghostty"
  activate
  set cfg to new surface configuration
  set initial working directory of cfg to "${escaped_path}"
  set initial input of cfg to "${escaped_cmd}\n"
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

  # 生成包装脚本：先验证模型可用性再启动，fallback 到默认模型
  local dev_script="$worktree_path/.claude/launch-developer.sh"
  local reviewer_script="$worktree_path/.claude/launch-reviewer.sh"

  _write_launch_script "$dev_script" "$dev_model" "$dev_prompt"
  _write_launch_script "$reviewer_script" "$reviewer_model" "$reviewer_prompt"
  chmod +x "$dev_script" "$reviewer_script"

  local dev_cmd="bash \"$dev_script\""
  local reviewer_cmd="bash \"$reviewer_script\""

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
    return 0
  else
    return 1
  fi
}

_write_launch_script() {
  local script_path="$1"
  local model="$2"
  local prompt="$3"

  local prompt_arg=""
  [[ -n "$prompt" ]] && prompt_arg="\"@$prompt\""

  cat > "$script_path" <<SCRIPT
#!/usr/bin/env bash
# 由 dual-dev bootstrap 自动生成，勿手动修改
PROMPT_ARG=${prompt_arg}

if [[ -n "$model" && "$model" != "default" ]]; then
  # 探测模型是否可用（--print 模式无副作用）
  if echo "" | claude --model "$model" --print 2>/dev/null | head -1 > /dev/null 2>&1; then
    exec claude --model "$model" \$PROMPT_ARG
  else
    echo "[dual-dev] 模型 $model 不可用，使用默认模型"
    exec claude \$PROMPT_ARG
  fi
else
  exec claude \$PROMPT_ARG
fi
SCRIPT
}
