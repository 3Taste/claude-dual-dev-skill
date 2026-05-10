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

write_worktree_settings() {
  local worktree_path="$1"
  local settings_file="$worktree_path/.claude/settings.json"
  local signals_dir="$worktree_path/.claude/signals"

  # 预授权 signals 目录的 rm 操作，避免每次都弹确认框
  python3 - "$settings_file" "$signals_dir" <<'PYEOF'
import json, sys, os

settings_file = sys.argv[1]
signals_dir = sys.argv[2]

if os.path.exists(settings_file):
    with open(settings_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
else:
    data = {}

permissions = data.setdefault("permissions", {})
allow_list = permissions.setdefault("allow", [])

rule = f"Bash(rm {signals_dir}/review-*.md)"
if rule not in allow_list:
    allow_list.append(rule)

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF

  echo "[dual-dev] 已写入 worktree settings，signals 目录 rm 操作已预授权"
}
