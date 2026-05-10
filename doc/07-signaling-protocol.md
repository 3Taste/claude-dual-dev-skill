# 07 信号握手协议

## 目录与文件

```
<WORKTREE_PATH>/.claude/signals/
├── ready-1.md
├── review-1.md
├── ready-2.md
├── review-2.md
├── ...
├── ready-final.md
└── review-final.md
```

- 单一目录，平铺存放（不分子目录），扫描简单
- 编号 `<n>` 从 1 起单调递增；不复用、不回填
- `final` 是字面量，不是数字，单独识别
- 全程 git ignore（bootstrap 已加 `.claude/signals/` 到 `.gitignore`）

## 命名规则

| 名 | 写者 | 触发 |
|----|------|------|
| `ready-<n>.md` | 开发者 | 完成第 n 个 chunk |
| `review-<n>.md` | 审查者 | 审完 ready-<n>.md |
| `ready-final.md` | 开发者 | 全部 chunk 都过审 + 自检完毕 |
| `review-final.md` | 审查者 | 通读所有变更后整体放行 |

`<n>` 由开发者维持。审查者写 review 时编号必须与对应 ready 一致。

## ready-<n>.md 结构

```markdown
# ready-<n>: <一句话标题>

## 实现要点
- 做了什么
- 为什么这么做（关键决策）

## 文件清单
- path/to/file1 — 新增/修改/删除
- path/to/file2 — ...

## 自测
- 跑了哪些测试 / 命令
- 输出关键截取（pass / 报错）

## 待审查问题
- 不确定的设计选择
- 已知 trade-off
- 希望审查者重点看的地方
```

字段强制全填；无内容写 `（无）`。审查者据此快速定位变更范围。

## review-<n>.md 结构

```markdown
# review-<n>: PASS | CHANGES

## 结论
PASS（或 CHANGES）

## 审查覆盖
- 看了哪些文件
- 跑了哪些验证（如有）

## 改动点（仅 CHANGES 时）
1. path:line — 问题描述 — 建议改法 — 严重度 [CRITICAL|HIGH|MEDIUM|LOW]
2. ...

## 备注
- 通过/不通过的关键理由
- 表扬点（可选，鼓励有效模式）
```

PASS 时省略"改动点"段；CHANGES 时必填。严重度按 `~/.claude/rules/common/code-review.md` 标准：CRITICAL/HIGH 必修，MEDIUM 建议修，LOW 可选。

## ready-final.md / review-final.md

`ready-final.md`：

```markdown
# ready-final

## 总览
- chunk 数：N
- 全部状态：all PASS

## 整体自检
- 全量测试结果
- 编译/lint 结果
- 设计文档覆盖核对

## 移交说明
- commit 切分建议
- PR 标题与 body 草稿
- 已知遗留（应该没有，否则不该 final）
```

`review-final.md`：

```markdown
# review-final: PASS | CHANGES

## 结论
PASS（或 CHANGES）

## 通读发现
- 跨 chunk 的问题（仅本轮通读时新发现的，非单 chunk 已记录的）
- 集成层风险

## 放行说明（PASS 时）
- 可 commit / push / PR
```

review-final 若 CHANGES，回到 chunk 级循环：开发者写新一轮 ready-<n+1>.md 修复，再走流程。

## 扫描策略

**开发者侧**：

- 启动后 / 写完 ready 后，扫 `review-<n>.md` 是否存在（n = 自己刚写的 ready 编号）
- 等待时不轮询，靠用户提示或主动 `ls .claude/signals/` 检查
- 找到 review-<n>.md 后读结论：PASS → 进 chunk n+1；CHANGES → 修后写 ready-<n+1>.md

**审查者侧**：

- 启动后扫 `ready-*.md`，按编号升序找最大 ready-<n>.md 但 review-<n>.md 不存在的 n
- 若都已审过，等待新 ready 出现
- ready-final.md 出现 → 触发 final 通读

不引入文件 watch / inotify，避免依赖。两侧靠用户在窗口间切换提示"已写入"，或自然通过对话节奏感知。

## 并发与冲突

- 单工作区单分支，开发者审查者各只写自己命名空间，不会写同一文件
- 文件命名带编号天然避撞
- 极端情况两侧同名编号撞车（开发者错过 review，先写 ready-<n+1>），审查者按编号顺序处理仍正确，无数据丢失

## 状态机视角

```
[开发] ready-1.md
   │
   ▼
[审查] review-1.md ── PASS ──┐
   │                          │
 CHANGES                      ▼
   │                       [开发] ready-2.md
   ▼                          │
[开发] ready-2.md             ▼
   │                       [审查] review-2.md
   ▼                          │
[审查] review-2.md           ...
   ...                        │
                              ▼
                         [开发] ready-final.md
                              │
                              ▼
                         [审查] review-final.md
                              │
                            PASS
                              │
                              ▼
                          (用户 commit/push/PR)
```

## 内容自由度

字段框架固定，正文 markdown 自由。允许：

- 代码片段、diff、表格
- 链接到 worktree 内文件（相对路径）
- 中文 / 英文混用

禁止：

- 二进制附件
- 路径外引用（`../../...` 跳出 worktree）
- 把整段实现代码贴进 ready / review（用文件路径 + 关键行号即可）

## 维护

worktree 删除时信号目录随之消失，无需主动清理。若同一 worktree 多轮 `/dual-dev` 复用（不推荐），bootstrap 检测到已存在的 ready/review 文件应警告用户，由用户决定保留或清空。

## 与 git 的关系

- `.claude/signals/` 在 `.gitignore` 中，不入仓
- 信号是协作过程产物，不是制品
- 终态判据是 `review-final.md` 的 PASS，不是 commit
- 用户在所有 PASS 后再做 commit/push（信号文件不参与）
