---
name: dual-dev
description: 双人开发工作流启动器 — 创建 git worktree，打开开发者与审查者两个终端窗口，注入角色提示词，建立信号文件协议
---

# /dual-dev — 双人开发工作流

## 触发

用户输入 `/dual-dev` 时触发此 skill。

## 步骤

按顺序向用户提问，收集所有答案后执行 bootstrap.sh。

---

### Q1：工作区路径 & 分支名

询问：

> 请提供以下信息（可一起回答）：
> 1. **worktree 路径**：新建工作区的绝对路径，例如 `~/git/myproject-feature`
> 2. **新建分支名**：例如 `feature/new-api`
> 3. **基础分支**：基于哪个分支创建，例如 `main` 或 `dev`
>
> 当前项目分支为：`$(git branch --show-current)`，可参考。

等待用户回答，提取三个值：`WORKTREE_PATH`、`BRANCH_NAME`、`BASE_BRANCH`。

---

### Q2：设计文档路径

询问：

> 请提供设计文档路径（用于注入到角色提示词中）。
> 可以是一个或多个路径，用空格分隔，例如：
> `doc/design.md doc/api-spec.md`
>
> 如果暂无设计文档，直接回复"无"或留空。

等待用户回答，提取 `DESIGN_DOCS`（为空则设为空字符串）。

---

### Q3：Claude 模型选择

询问：

> 请选择 Claude 模型：
> 1. 两个窗口都使用默认模型（claude-sonnet-4-6）
> 2. 指定开发者窗口模型
> 3. 指定审查者窗口模型
> 4. 分别指定两个窗口的模型
>
> 请回复序号或直接输入模型名称。

根据回答提取 `DEV_MODEL` 和 `REVIEWER_MODEL`（未指定则均为 `claude-sonnet-4-6`）。

---

### Q4：特殊要求

询问：

> 有没有特殊要求？例如：
> - 代码风格限制
> - 测试覆盖率要求
> - 禁止使用某些库
> - 性能或安全约束
>
> 没有要求直接回复"无"或留空。

提取 `SPECIAL_REQUIREMENTS`（为空则设为空字符串）。

---

## 执行

收集完所有回答后，在当前目录执行：

```bash
bash "$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")/scripts/bootstrap.sh" \
  --worktree-path "$WORKTREE_PATH" \
  --branch-name "$BRANCH_NAME" \
  --base-branch "$BASE_BRANCH" \
  --design-docs "$DESIGN_DOCS" \
  --dev-model "$DEV_MODEL" \
  --reviewer-model "$REVIEWER_MODEL" \
  --special-requirements "$SPECIAL_REQUIREMENTS"
```

实际调用时，将上述变量替换为用户提供的真实值，通过 Bash 工具执行。

---

## 执行方式说明

Claude 在执行此 skill 时：

1. 完成 4 步 Q&A 收集参数
2. 使用 Bash 工具调用 `scripts/bootstrap.sh`，传入所有参数
3. bootstrap.sh 路径基于此 SKILL.md 所在目录推导
4. 等待脚本输出，将结果反馈给用户
