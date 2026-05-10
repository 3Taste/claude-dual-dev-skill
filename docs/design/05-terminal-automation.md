# 05 终端自动化

## macOS 优先方案：osascript + Terminal.app

### 选型理由

- macOS 自带，无需安装额外依赖
- AppleScript 控制 Terminal.app 成熟、文档丰富
- 比 iTerm2 通用（不假设用户装 iTerm2）

### 核心命令

开新窗口并执行命令：

```bash
osascript <<EOF
tell application "Terminal"
    activate
    do script "cd '<WORKTREE_PATH>' && claude --model <DEV_MODEL>"
end tell
EOF
```

`do script` 默认在新窗口里执行命令。两窗口顺序调用即可。

### 完整封装（terminal.sh 伪代码）

```bash
open_terminal() {
    local cwd="$1"
    local cmd="$2"
    local title="$3"
    osascript <<EOF
tell application "Terminal"
    activate
    set newWin to do script "cd '$cwd' && $cmd"
    set custom title of front window to "$title"
end tell
EOF
}

open_terminal "$WORKTREE_PATH" "claude --model $DEV_MODEL"      "dual-dev: developer"
sleep 0.5
open_terminal "$WORKTREE_PATH" "claude --model $REVIEWER_MODEL" "dual-dev: reviewer"
```

`sleep 0.5` 避免两次 osascript 调用太近导致窗口未完全初始化。

### 窗口标题

带 `dual-dev:` 前缀 + 角色，便于用户多窗口辨认。

### 已知坑

- 路径含空格：用单引号包路径
- Terminal.app 首次启动需授权访问辅助功能 → 首次运行 osascript 弹权限框，用户授权后续无感
- `do script` 不带 window 参数时，行为受 Terminal 偏好"在标签页打开"影响 → 强制新窗口可用 `do script ... in window` 配合 AppleScript 创建空 window，或先 `tell application "System Events" to keystroke "n" using command down`

## iTerm2 备选

若用户主用 iTerm2（环境变量 `TERM_PROGRAM=iTerm.app`）：

```bash
osascript <<EOF
tell application "iTerm"
    create window with default profile
    tell current session of current window
        write text "cd '$WORKTREE_PATH' && claude --model $DEV_MODEL"
    end tell
end tell
EOF
```

terminal.sh 用 `$TERM_PROGRAM` 分支选择。首版可只支持 Terminal.app，二期补 iTerm2。

## Linux（二期）

候选：

| 终端 | 命令 |
|------|------|
| gnome-terminal | `gnome-terminal --working-directory=<path> -- bash -c "claude --model X; exec bash"` |
| konsole | `konsole --workdir <path> -e bash -c "claude --model X; exec bash"` |
| xterm | `xterm -e "cd <path> && claude --model X" &` |
| tmux | `tmux new-window -c <path> "claude --model X"` |

策略：探测 `$XDG_CURRENT_DESKTOP` / 已安装 binary，按优先级选。terminal.sh 抽象出 `open_terminal()` 接口，平台分支内部各自实现。

## Windows（二期）

候选：

- Windows Terminal：`wt -d <path> -- claude --model X; new-tab -d <path> -- claude --model X`
- PowerShell：`Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd <path>; claude --model X"`

WSL 用户走 Linux 分支。

## claude CLI 启动模式辨析

| 模式 | 命令 | 是否交互 | 是否可作 prompt 注入 |
|------|------|---------|------------------|
| 默认 | `claude` | 交互 | 用户首句 `@file.md` |
| 非交互 | `claude -p "..."` | 一次性 | 不适合长会话 |
| 续会 | `claude --continue` | 交互 | 不适用首次启动 |

本 skill 选默认交互模式 + 用户首句 `@file` 触发。理由：

- `-p` 一次性退出，无法承载长开发会话
- `@file` 引用让 prompt 文件成为首条上下文，等价于"启动时注入"
- 用户保留 ESC 中断、上下翻历史等所有交互能力

## 不直接 stdin 输入的原因

理论上 `osascript do script "cd X && claude <<<'@dev.md'"` 可注入首句，但：

- claude CLI 把 stdin 当一次性输入，非交互模式行为
- 多行 here-doc 在 AppleScript 嵌套引号中转义复杂、易出 bug
- 用户失去对首句的可见控制

→ 选择"开窗 + 用户手动 @"是简单可靠的折中。

## 失败检测

osascript 退出码非 0 视为失败。bootstrap 捕获后调 rollback。窗口已开但 cd 失败的情况无法可靠检测（osascript 不回 do script 的执行结果），靠用户肉眼发现。

## 跨项目复用前提

osascript 只依赖系统 Terminal.app 和 PATH 中的 `claude`，不读宿主项目任何配置 → 跨项目无侵入。
