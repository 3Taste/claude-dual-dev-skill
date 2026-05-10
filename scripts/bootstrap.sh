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
  --dev-prompt-path PATH       开发者自定义提示词路径（可为空，默认用内置模板）
  --reviewer-prompt-path PATH  审查者自定义提示词路径（可为空，默认用内置模板）
  --terminal ghostty|terminal  终端选择（可为空，默认 ghostty；不可用时自动回退）
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
  DEV_PROMPT_PATH=""
  REVIEWER_PROMPT_PATH=""
  TERMINAL_APP="ghostty"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --worktree-path)        WORKTREE_PATH="$2";          shift 2 ;;
      --branch-name)          BRANCH_NAME="$2";             shift 2 ;;
      --base-branch)          BASE_BRANCH="$2";             shift 2 ;;
      --design-docs)          DESIGN_DOCS="$2";             shift 2 ;;
      --dev-model)            DEV_MODEL="$2";               shift 2 ;;
      --reviewer-model)       REVIEWER_MODEL="$2";          shift 2 ;;
      --special-requirements) SPECIAL_REQUIREMENTS="$2";    shift 2 ;;
      --dev-prompt-path)      DEV_PROMPT_PATH="$2";         shift 2 ;;
      --reviewer-prompt-path) REVIEWER_PROMPT_PATH="$2";    shift 2 ;;
      --terminal)             TERMINAL_APP="$2";            shift 2 ;;
      -h|--help)              usage ;;
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

  WORKTREE_PATH="${WORKTREE_PATH/#\~/$HOME}"
  [[ -n "$DEV_PROMPT_PATH" ]]      && DEV_PROMPT_PATH="${DEV_PROMPT_PATH/#\~/$HOME}"
  [[ -n "$REVIEWER_PROMPT_PATH" ]] && REVIEWER_PROMPT_PATH="${REVIEWER_PROMPT_PATH/#\~/$HOME}"
  [[ -z "$DEV_MODEL" ]]      && DEV_MODEL="claude-sonnet-4-6"
  [[ -z "$REVIEWER_MODEL" ]] && REVIEWER_MODEL="claude-sonnet-4-6"
  [[ -z "$TERMINAL_APP" ]]   && TERMINAL_APP="ghostty"

  if [[ "$TERMINAL_APP" != "ghostty" && "$TERMINAL_APP" != "terminal" ]]; then
    echo "[dual-dev] 错误：--terminal 只接受 ghostty 或 terminal" >&2
    usage
  fi
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
  fi

  parse_args "$@"

  local signals_dir="$WORKTREE_PATH/.claude/signals"
  local dev_prompt="$WORKTREE_PATH/.claude/dual-dev-developer-prompt.md"
  local reviewer_prompt="$WORKTREE_PATH/.claude/dual-dev-reviewer-prompt.md"

  local worktree_created=false
  trap '[[ "$worktree_created" == "true" ]] && rollback "$WORKTREE_PATH" "$BRANCH_NAME"' ERR

  echo ""
  echo "====== dual-dev 启动 ======"
  echo "  worktree  : $WORKTREE_PATH"
  echo "  分支      : $BRANCH_NAME (基于 $BASE_BRANCH)"
  echo "  开发模型  : $DEV_MODEL"
  echo "  审查模型  : $REVIEWER_MODEL"
  echo "  终端      : $TERMINAL_APP"
  [[ -n "$DESIGN_DOCS" ]]          && echo "  设计文档  : $DESIGN_DOCS"
  [[ -n "$DEV_PROMPT_PATH" ]]      && echo "  开发提示词: $DEV_PROMPT_PATH (自定义)"
  [[ -n "$REVIEWER_PROMPT_PATH" ]] && echo "  审查提示词: $REVIEWER_PROMPT_PATH (自定义)"
  [[ -n "$SPECIAL_REQUIREMENTS" ]] && echo "  特殊要求  : $SPECIAL_REQUIREMENTS"
  echo "==========================="
  echo ""

  run_prechecks "$WORKTREE_PATH" "$BRANCH_NAME"

  create_worktree "$WORKTREE_PATH" "$BRANCH_NAME" "$BASE_BRANCH"
  worktree_created=true

  setup_claude_dir "$WORKTREE_PATH"
  setup_signals "$WORKTREE_PATH"
  add_gitignore "$WORKTREE_PATH"

  # 开发者提示词：用自定义路径或内置模板
  if [[ -n "$DEV_PROMPT_PATH" ]]; then
    if [[ ! -f "$DEV_PROMPT_PATH" ]]; then
      echo "[dual-dev] 错误：自定义开发者提示词不存在：$DEV_PROMPT_PATH" >&2
      exit 1
    fi
    cp "$DEV_PROMPT_PATH" "$dev_prompt"
    echo "[dual-dev] 使用自定义开发者提示词：$DEV_PROMPT_PATH"
  else
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
  fi

  # 审查者提示词：用自定义路径或内置模板
  if [[ -n "$REVIEWER_PROMPT_PATH" ]]; then
    if [[ ! -f "$REVIEWER_PROMPT_PATH" ]]; then
      echo "[dual-dev] 错误：自定义审查者提示词不存在：$REVIEWER_PROMPT_PATH" >&2
      exit 1
    fi
    cp "$REVIEWER_PROMPT_PATH" "$reviewer_prompt"
    echo "[dual-dev] 使用自定义审查者提示词：$REVIEWER_PROMPT_PATH"
  else
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
  fi

  local is_macos=true
  check_macos || is_macos=false

  if [[ "$is_macos" == "true" ]]; then
    open_dev_and_reviewer_windows \
      "$WORKTREE_PATH" \
      "$DEV_MODEL" \
      "$REVIEWER_MODEL" \
      "$dev_prompt" \
      "$reviewer_prompt" \
      "$TERMINAL_APP"
  fi

  echo ""
  echo "====== dual-dev 启动成功 ======"
  echo ""
  if [[ "$is_macos" == "true" ]]; then
    echo "两个终端窗口已自动打开，提示词已注入，Claude 正在初始化。"
  else
    echo "请手动打开两个终端，cd 到 $WORKTREE_PATH，分别运行："
    echo "  开发者: claude \"@$dev_prompt\""
    echo "  审查者: claude \"@$reviewer_prompt\""
  fi
  echo ""
  echo "信号文件目录：$signals_dir"
  echo ""
  echo "清理 worktree（完成后）："
  echo "  git worktree remove \"$WORKTREE_PATH\" && git branch -d \"$BRANCH_NAME\""
  echo "================================"
}

main "$@"
