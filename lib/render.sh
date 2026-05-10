#!/usr/bin/env bash
set -euo pipefail

_escape_sed_value() {
  local value="$1"
  # 转义 sed 替换字符串中的特殊字符：& / \（使用 bash 替换，避免 macOS head -c -1 不兼容）
  local v="${value//\\/\\\\}"   # \ → \\
  v="${v//&/\\&}"               # & → \&
  v="${v//|/\\|}"               # | → \| (我们用 | 作 sed 分隔符)
  printf '%s' "$v"
}

render_template() {
  local src="$1"
  local dst="$2"
  shift 2

  if [[ ! -f "$src" ]]; then
    echo "[dual-dev] 错误：模板文件不存在：$src" >&2
    exit 1
  fi

  cp "$src" "$dst"

  while [[ $# -ge 2 ]]; do
    local key="$1"
    local raw_value="$2"
    shift 2

    local escaped
    escaped=$(_escape_sed_value "$raw_value")
    sed -i '' "s|{{${key}}}|${escaped}|g" "$dst"
  done

  echo "[dual-dev] 模板渲染完成: $dst"
}
