#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/YOUR_USERNAME/claude-dual-dev-skill.git"
INSTALL_DIR="${HOME}/.claude/skills/dual-dev"

echo "=== dual-dev skill 安装程序 ==="
echo ""

check_deps() {
  local missing=()

  if ! command -v git > /dev/null 2>&1; then
    missing+=("git")
  fi

  if ! command -v claude > /dev/null 2>&1; then
    echo "⚠️  未检测到 claude 命令，请先安装 Claude Code CLI："
    echo "   https://claude.ai/download"
    echo ""
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "❌ 缺少必要依赖：${missing[*]}"
    echo "   请先安装后重新运行"
    exit 1
  fi
}

check_macos_version() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local ver
    ver=$(sw_vers -productVersion 2>/dev/null || echo "0")
    local major
    major=$(echo "$ver" | cut -d. -f1)
    if [[ "$major" -lt 12 ]]; then
      echo "⚠️  macOS 版本 $ver 可能不支持自动打开终端（建议 12+）"
    fi
  else
    echo "ℹ️  非 macOS 系统：终端自动打开功能不可用，其余功能正常"
  fi
}

install() {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo "⚠️  已存在安装目录：$INSTALL_DIR"
    read -r -p "是否覆盖更新？[y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "已取消"
      exit 0
    fi
    rm -rf "$INSTALL_DIR"
  fi

  mkdir -p "$(dirname "$INSTALL_DIR")"
  echo "📦 克隆 skill 到：$INSTALL_DIR"
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
}

verify() {
  if [[ -f "$INSTALL_DIR/SKILL.md" ]]; then
    echo ""
    echo "✅ 安装成功！"
    echo ""
    echo "使用方式："
    echo "  1. 进入任意 git 项目根目录"
    echo "  2. 打开 Claude Code，输入 /dual-dev"
  else
    echo "❌ 安装验证失败，SKILL.md 不存在"
    exit 1
  fi
}

check_deps
check_macos_version
install
verify
