#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"

source "$LIB_DIR/precheck.sh"
source "$LIB_DIR/worktree.sh"
source "$LIB_DIR/render.sh"
source "$LIB_DIR/signals.sh"
source "$LIB_DIR/terminal.sh"
source "$LIB_DIR/rollback.sh"

usage() {
  cat >&2 <<EOF
用法: bootstrap.sh [选项]

选项:
  --worktree-path PATH         worktree 目录路径（必填）
  --branch-name BRANCH         新建分支名（必填）
  --base-branch BASE           基础分支（必填）
  --design-docs "DOC1 DOC2"    设计文档路径，空格分隔（可为空）
  --dev-model MODEL            开发者窗口模型（可为空，默认 claude-sonnet-4-6）
  --reviewer-model MODEL       审查者窗口模型（可为空，默认 claude-sonnet-4-6）
  --special-requirements TEXT  特殊要求（可为空）
  -h, --help                   显示此帮助

示例:
  bootstrap.sh \\
    --worktree-path ~/git/myproject-feature \\
    --branch-name feature/new-api \\
    --base-branch main \\
    --design-docs "doc/design.md doc/api.md" \\
    --dev-model claude-sonnet-4-6 \\
    --reviewer-model claude-sonnet-4-6 \\
    --special-requirements "优先考虑性能"
EOF
  exit 1
}

parse_args() {
  WORKTREE_PATH=""
  BRANCH_NAME=""
  BASE_BRANCH=""
  DESIGN_DOCS=""
  DEV_MODEL="claude-sonnet-4-6"
  REVIEWER_MODEL="claude-sonnet-4-6"
  SPECIAL_REQUIREMENTS=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --worktree-path)   WORKTREE_PATH="$2";          shift 2 ;;
      --branch-name)     BRANCH_NAME="$2";             shift 2 ;;
      --base-branch)     BASE_BRANCH="$2";             shift 2 ;;
      --design-docs)     DESIGN_DOCS="$2";             shift 2 ;;
      --dev-model)       DEV_MODEL="$2";               shift 2 ;;
      --reviewer-model)  REVIEWER_MODEL="$2";          shift 2 ;;
      --special-requirements) SPECIAL_REQUIREMENTS="$2"; shift 2 ;;
      -h|--help)         usage ;;
      *)
        echo "[dual-dev] 未知参数: $1" >&2
        usage
        ;;
    esac
  done

  if [[ -z "$WORKTREE_PATH" || -z "$BRANCH_NAME" || -z "$BASE_BRANCH" ]]; then
    echo "[dual-dev] 错误：--worktree-path、--branch-name、--base-branch 为必填项" >&2
    usage
  fi

  # 展开 ~ 路径
  WORKTREE_PATH="${WORKTREE_PATH/#\~/$HOME}"

  # 模型为空时使用默认值
  [[ -z "$DEV_MODEL" ]] && DEV_MODEL="claude-sonnet-4-6"
  [[ -z "$REVIEWER_MODEL" ]] && REVIEWER_MODEL="claude-sonnet-4-6"
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
  fi

  parse_args "$@"

  local signals_dir="$WORKTREE_PATH/.claude/signals"
  local dev_prompt="$WORKTREE_PATH/.claude/dual-dev-developer-prompt.md"
  local reviewer_prompt="$WORKTREE_PATH/.claude/dual-dev-reviewer-prompt.md"

  # 回滚处理：任意步骤失败时清理
  local worktree_created=false
  trap '[[ "$worktree_created" == "true" ]] && rollback "$WORKTREE_PATH" "$BRANCH_NAME"' ERR

  echo ""
  echo "====== dual-dev 启动 ======"
  echo "  worktree  : $WORKTREE_PATH"
  echo "  分支      : $BRANCH_NAME (基于 $BASE_BRANCH)"
  echo "  开发模型  : $DEV_MODEL"
  echo "  审查模型  : $REVIEWER_MODEL"
  [[ -n "$DESIGN_DOCS" ]] && echo "  设计文档  : $DESIGN_DOCS"
  [[ -n "$SPECIAL_REQUIREMENTS" ]] && echo "  特殊要求  : $SPECIAL_REQUIREMENTS"
  echo "==========================="
  echo ""

  # Step 1: 预检
  run_prechecks "$WORKTREE_PATH" "$BRANCH_NAME"

  # Step 2: 创建 worktree
  create_worktree "$WORKTREE_PATH" "$BRANCH_NAME" "$BASE_BRANCH"
  worktree_created=true

  # Step 3: 创建 .claude 目录和信号目录
  setup_claude_dir "$WORKTREE_PATH"
  setup_signals "$WORKTREE_PATH"
  add_gitignore "$WORKTREE_PATH"

  # Step 4: 渲染提示词模板
  render_template \
    "$TEMPLATES_DIR/dual-dev-developer-prompt.md" \
    "$dev_prompt" \
    "ROLE"                 "developer" \
    "BASE_BRANCH"          "$BASE_BRANCH" \
    "BRANCH_NAME"          "$BRANCH_NAME" \
    "WORKTREE_PATH"        "$WORKTREE_PATH" \
    "DESIGN_DOCS"          "$DESIGN_DOCS" \
    "DEV_MODEL"            "$DEV_MODEL" \
    "REVIEWER_MODEL"       "$REVIEWER_MODEL" \
    "SPECIAL_REQUIREMENTS" "$SPECIAL_REQUIREMENTS" \
    "SIGNALS_DIR"          "$signals_dir" \
    "COUNTERPART_PROMPT"   "$reviewer_prompt"

  render_template \
    "$TEMPLATES_DIR/dual-dev-reviewer-prompt.md" \
    "$reviewer_prompt" \
    "ROLE"                 "reviewer" \
    "BASE_BRANCH"          "$BASE_BRANCH" \
    "BRANCH_NAME"          "$BRANCH_NAME" \
    "WORKTREE_PATH"        "$WORKTREE_PATH" \
    "DESIGN_DOCS"          "$DESIGN_DOCS" \
    "DEV_MODEL"            "$DEV_MODEL" \
    "REVIEWER_MODEL"       "$REVIEWER_MODEL" \
    "SPECIAL_REQUIREMENTS" "$SPECIAL_REQUIREMENTS" \
    "SIGNALS_DIR"          "$signals_dir" \
    "COUNTERPART_PROMPT"   "$dev_prompt"

  # Step 5: 打开终端窗口（macOS only）
  local is_macos=true
  check_macos || is_macos=false

  if [[ "$is_macos" == "true" ]]; then
    open_dev_and_reviewer_windows \
      "$WORKTREE_PATH" \
      "$DEV_MODEL" \
      "$REVIEWER_MODEL" \
      "$dev_prompt" \
      "$reviewer_prompt"
  fi

  # 成功提示
  echo ""
  echo "====== dual-dev 启动成功 ======"
  echo ""
  echo "下一步："
  echo "  1. 开发者窗口：在 Claude 中执行 @$dev_prompt 加载提示词"
  echo "  2. 审查者窗口：在 Claude 中执行 @$reviewer_prompt 加载提示词"
  echo ""
  echo "信号文件目录：$signals_dir"
  echo ""
  echo "清理 worktree（完成后）："
  echo "  git worktree remove \"$WORKTREE_PATH\" && git branch -d \"$BRANCH_NAME\""
  echo "================================"
}

main "$@"
