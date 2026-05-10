#!/usr/bin/env bash
set -euo pipefail

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

    _replace_placeholder "$dst" "$key" "$raw_value"
  done

  echo "[dual-dev] 模板渲染完成: $dst"
}

# 用 python3 做占位符替换，支持多行值、任意特殊字符
_replace_placeholder() {
  local file="$1"
  local key="$2"
  local value="$3"
  local placeholder="{{${key}}}"

  if command -v python3 > /dev/null 2>&1; then
    python3 - "$file" "$placeholder" "$value" <<'PYEOF'
import sys

file_path = sys.argv[1]
placeholder = sys.argv[2]
value = sys.argv[3]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(placeholder, value)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
  else
    # fallback: awk（支持多行，但值中的 \ 需要额外转义）
    local escaped_value
    escaped_value=$(printf '%s' "$value" | awk '{gsub(/\\/, "\\\\"); gsub(/&/, "\\&"); printf "%s\\n", $0}' | head -c -2)
    awk -v key="{{${key}}}" -v val="$escaped_value" '{ gsub(key, val); print }' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
}
