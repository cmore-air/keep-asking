#!/usr/bin/env bash
# =============================================================================
# prompt-appender 一键安装脚本 (Linux / macOS)
#
# 用法:
#   bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/prompt-appender/main/install.sh)
#   或本地运行：bash install.sh
#
# 选项:
#   --dir <path>     指定安装目录 (默认: ~/.local/share/prompt-appender)
#   --no-opencode    跳过 OpenCode 集成配置
#   --no-claude      跳过 Claude Code 集成配置
#   --skip-config    跳过创建默认配置文件
#   --help           显示帮助
# =============================================================================

set -euo pipefail

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}"; }

# ── 默认参数 ──────────────────────────────────────────────────────────────────
INSTALL_DIR="${HOME}/.local/share/prompt-appender"
CONFIGURE_OPENCODE=true
CONFIGURE_CLAUDE=true
SKIP_CONFIG=false

REPO_URL="https://github.com/anomalyco/prompt-appender"
REPO_ARCHIVE_URL="https://github.com/anomalyco/prompt-appender/archive/refs/heads/main.tar.gz"

# ── 参数解析 ──────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)        INSTALL_DIR="$2"; shift 2 ;;
    --no-opencode) CONFIGURE_OPENCODE=false; shift ;;
    --no-claude)   CONFIGURE_CLAUDE=false; shift ;;
    --skip-config) SKIP_CONFIG=true; shift ;;
    --help)
      echo "用法: bash install.sh [选项]"
      echo ""
      echo "选项:"
      echo "  --dir <path>     指定安装目录 (默认: ~/.local/share/prompt-appender)"
      echo "  --no-opencode    跳过 OpenCode 集成配置"
      echo "  --no-claude      跳过 Claude Code 集成配置"
      echo "  --skip-config    跳过创建默认配置文件"
      echo "  --help           显示此帮助"
      exit 0
      ;;
    *) log_error "未知参数: $1"; exit 1 ;;
  esac
done

# ── 工具函数 ──────────────────────────────────────────────────────────────────

command_exists() { command -v "$1" &>/dev/null; }

# 安全地合并 JSON：将 key/value 注入到对象顶层
# 若 key 已存在则跳过（不覆盖用户配置）
json_set_if_absent() {
  local file="$1"
  local key="$2"
  local value="$3"  # 已是合法 JSON 值（字符串/数组/对象）

  if [[ ! -f "$file" ]]; then
    echo "{}" > "$file"
  fi

  # 判断 key 是否已存在
  if command_exists python3; then
    python3 - "$file" "$key" "$value" <<'PYEOF'
import json, sys
file, key, value_str = sys.argv[1], sys.argv[2], sys.argv[3]
with open(file, 'r', encoding='utf-8') as f:
    obj = json.load(f)
if key in obj:
    sys.exit(0)  # 已存在，不修改
import json as _json
obj[key] = _json.loads(value_str)
with open(file, 'w', encoding='utf-8') as f:
    json.dump(obj, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
  else
    log_warn "未找到 python3，无法自动修改 JSON 配置，请手动配置"
  fi
}

# 向 JSON 数组追加元素（若不存在）
json_array_append_if_absent() {
  local file="$1"
  local key="$2"
  local value="$3"  # 字符串值（不含引号）

  if [[ ! -f "$file" ]]; then
    echo "{}" > "$file"
  fi

  if command_exists python3; then
    python3 - "$file" "$key" "$value" <<'PYEOF'
import json, sys
file, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(file, 'r', encoding='utf-8') as f:
    obj = json.load(f)
arr = obj.get(key, [])
if not isinstance(arr, list):
    arr = [arr]
if value not in arr:
    arr.append(value)
    obj[key] = arr
    with open(file, 'w', encoding='utf-8') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write('\n')
PYEOF
  else
    log_warn "未找到 python3，无法自动修改 JSON 配置，请手动配置"
  fi
}

# ── 步骤 1：检查依赖 ──────────────────────────────────────────────────────────
log_section "检查依赖"

# 检查 git 或下载工具
HAS_GIT=false
HAS_CURL=false
HAS_WGET=false
command_exists git  && HAS_GIT=true
command_exists curl && HAS_CURL=true
command_exists wget && HAS_WGET=true

if ! $HAS_GIT && ! $HAS_CURL && ! $HAS_WGET; then
  log_error "需要 git、curl 或 wget 其中之一来下载项目"
  exit 1
fi

# 检查 bun
if ! command_exists bun; then
  log_warn "未找到 bun，尝试自动安装..."
  if $HAS_CURL; then
    curl -fsSL https://bun.sh/install | bash
    # 将 bun 加入当前 shell PATH
    export BUN_INSTALL="${HOME}/.bun"
    export PATH="${BUN_INSTALL}/bin:${PATH}"
  elif $HAS_WGET; then
    wget -qO- https://bun.sh/install | bash
    export BUN_INSTALL="${HOME}/.bun"
    export PATH="${BUN_INSTALL}/bin:${PATH}"
  else
    log_error "无法安装 bun（需要 curl 或 wget）。请手动安装 bun: https://bun.sh"
    exit 1
  fi

  if ! command_exists bun; then
    log_error "bun 安装失败，请手动安装后重试"
    exit 1
  fi
fi

BUN_VERSION=$(bun --version)
log_ok "bun 已就绪: ${BUN_VERSION}"

# 检查 node（用于 claude-hook.js 运行时）
if ! command_exists node; then
  log_warn "未找到 node。Claude Code 集成需要 node >= 18。"
  log_warn "请安装 Node.js: https://nodejs.org"
  CONFIGURE_CLAUDE=false
fi

# ── 步骤 2：下载源码 ──────────────────────────────────────────────────────────
log_section "下载 prompt-appender"

if [[ -d "$INSTALL_DIR" && -f "$INSTALL_DIR/package.json" ]]; then
  log_info "目录已存在: ${INSTALL_DIR}"
  if $HAS_GIT && [[ -d "$INSTALL_DIR/.git" ]]; then
    log_info "检测到 git 仓库，执行 git pull 更新..."
    git -C "$INSTALL_DIR" pull --ff-only || log_warn "git pull 失败，将使用现有代码继续"
  else
    log_info "跳过下载，使用现有代码"
  fi
else
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if $HAS_GIT; then
    log_info "使用 git clone 下载..."
    git clone --depth=1 "${REPO_URL}.git" "$INSTALL_DIR"
  elif $HAS_CURL; then
    log_info "使用 curl 下载压缩包..."
    TMPDIR_WORK=$(mktemp -d)
    trap 'rm -rf "$TMPDIR_WORK"' EXIT
    curl -fsSL "$REPO_ARCHIVE_URL" -o "${TMPDIR_WORK}/prompt-appender.tar.gz"
    tar -xzf "${TMPDIR_WORK}/prompt-appender.tar.gz" -C "$TMPDIR_WORK"
    EXTRACTED_DIR=$(find "$TMPDIR_WORK" -maxdepth 1 -mindepth 1 -type d | head -1)
    mv "$EXTRACTED_DIR" "$INSTALL_DIR"
  elif $HAS_WGET; then
    log_info "使用 wget 下载压缩包..."
    TMPDIR_WORK=$(mktemp -d)
    trap 'rm -rf "$TMPDIR_WORK"' EXIT
    wget -qO "${TMPDIR_WORK}/prompt-appender.tar.gz" "$REPO_ARCHIVE_URL"
    tar -xzf "${TMPDIR_WORK}/prompt-appender.tar.gz" -C "$TMPDIR_WORK"
    EXTRACTED_DIR=$(find "$TMPDIR_WORK" -maxdepth 1 -mindepth 1 -type d | head -1)
    mv "$EXTRACTED_DIR" "$INSTALL_DIR"
  fi
fi

log_ok "源码位置: ${INSTALL_DIR}"

# ── 步骤 3：构建 ──────────────────────────────────────────────────────────────
log_section "构建项目"

log_info "安装依赖..."
bun install --cwd "$INSTALL_DIR"

log_info "编译 TypeScript..."
bun run --cwd "$INSTALL_DIR" build

if [[ ! -f "${INSTALL_DIR}/dist/index.js" ]] || [[ ! -f "${INSTALL_DIR}/dist/claude-hook.js" ]]; then
  log_error "构建产物缺失，请检查构建输出"
  exit 1
fi

log_ok "构建成功: dist/index.js, dist/claude-hook.js"

# ── 步骤 4：配置 OpenCode ─────────────────────────────────────────────────────
if $CONFIGURE_OPENCODE; then
  log_section "配置 OpenCode 集成"

  OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
  OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG_DIR}/opencode.json"
  mkdir -p "$OPENCODE_CONFIG_DIR"

  if [[ ! -f "$OPENCODE_CONFIG_FILE" ]]; then
    echo "{}" > "$OPENCODE_CONFIG_FILE"
  fi

  PLUGIN_PATH="file://${INSTALL_DIR}"
  json_array_append_if_absent "$OPENCODE_CONFIG_FILE" "plugin" "$PLUGIN_PATH"
  log_ok "已注册插件到 ${OPENCODE_CONFIG_FILE}"

  # 创建 OpenCode 全局配置文件
  if ! $SKIP_CONFIG; then
    OC_PROMPT_CONFIG="${OPENCODE_CONFIG_DIR}/prompt-appender.jsonc"
    if [[ ! -f "$OC_PROMPT_CONFIG" ]]; then
      cat > "$OC_PROMPT_CONFIG" << 'JSONEOF'
{
  // 是否启用插件（全局开关）
  "enabled": true,

  // 提示语列表（每条可单独开关）
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。\nWhen you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation."
    }
  ]
}
JSONEOF
      log_ok "已创建配置文件: ${OC_PROMPT_CONFIG}"
    else
      log_info "配置文件已存在，跳过: ${OC_PROMPT_CONFIG}"
    fi
  fi
fi

# ── 步骤 5：配置 Claude Code ──────────────────────────────────────────────────
if $CONFIGURE_CLAUDE; then
  log_section "配置 Claude Code 集成"

  CLAUDE_CONFIG_DIR="${HOME}/.claude"
  CLAUDE_SETTINGS_FILE="${CLAUDE_CONFIG_DIR}/settings.json"
  mkdir -p "$CLAUDE_CONFIG_DIR"

  HOOK_COMMAND="node ${INSTALL_DIR}/dist/claude-hook.js"

  if [[ ! -f "$CLAUDE_SETTINGS_FILE" ]]; then
    echo "{}" > "$CLAUDE_SETTINGS_FILE"
  fi

  # 使用 python3 合并 hooks 配置
  if command_exists python3; then
    python3 - "$CLAUDE_SETTINGS_FILE" "$HOOK_COMMAND" <<'PYEOF'
import json, sys
file, hook_command = sys.argv[1], sys.argv[2]

with open(file, 'r', encoding='utf-8') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
submit_hooks = hooks.setdefault('UserPromptSubmit', [])

new_hook_entry = {
    "type": "command",
    "command": hook_command,
    "timeout": 5
}

# 检查是否已注册（通过 command 字段判断）
for group in submit_hooks:
    if isinstance(group, dict):
        for h in group.get('hooks', []):
            if isinstance(h, dict) and h.get('command') == hook_command:
                sys.exit(0)  # 已存在

# 找到 matcher="" 的组，若无则新建
target_group = None
for group in submit_hooks:
    if isinstance(group, dict) and group.get('matcher', None) == '':
        target_group = group
        break

if target_group is None:
    target_group = {'matcher': '', 'hooks': []}
    submit_hooks.append(target_group)

target_group.setdefault('hooks', []).append(new_hook_entry)

with open(file, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
    log_ok "已注册 Claude Code hook 到 ${CLAUDE_SETTINGS_FILE}"
  else
    log_warn "未找到 python3，请手动将以下内容添加到 ${CLAUDE_SETTINGS_FILE}:"
    echo ""
    echo '  "hooks": {'
    echo '    "UserPromptSubmit": [{'
    echo '      "matcher": "",'
    echo '      "hooks": [{'
    echo '        "type": "command",'
    echo "        \"command\": \"${HOOK_COMMAND}\","
    echo '        "timeout": 5'
    echo '      }]'
    echo '    }]'
    echo '  }'
    echo ""
  fi

  # 创建 Claude Code 全局配置文件
  if ! $SKIP_CONFIG; then
    CC_PROMPT_CONFIG="${CLAUDE_CONFIG_DIR}/prompt-appender.jsonc"
    if [[ ! -f "$CC_PROMPT_CONFIG" ]]; then
      cat > "$CC_PROMPT_CONFIG" << 'JSONEOF'
{
  "enabled": true,
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。\nWhen you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation."
    }
  ]
}
JSONEOF
      log_ok "已创建配置文件: ${CC_PROMPT_CONFIG}"
    else
      log_info "配置文件已存在，跳过: ${CC_PROMPT_CONFIG}"
    fi
  fi
fi

# ── 完成 ──────────────────────────────────────────────────────────────────────
log_section "安装完成"

echo ""
echo -e "${GREEN}${BOLD}prompt-appender 安装成功！${NC}"
echo ""
echo -e "  安装目录: ${CYAN}${INSTALL_DIR}${NC}"

if $CONFIGURE_OPENCODE; then
  echo -e "  OpenCode 配置: ${CYAN}${HOME}/.config/opencode/opencode.json${NC}"
  echo -e "  OpenCode 提示语配置: ${CYAN}${HOME}/.config/opencode/prompt-appender.jsonc${NC}"
fi

if $CONFIGURE_CLAUDE; then
  echo -e "  Claude Code 配置: ${CYAN}${HOME}/.claude/settings.json${NC}"
  echo -e "  Claude Code 提示语配置: ${CYAN}${HOME}/.claude/prompt-appender.jsonc${NC}"
fi

echo ""
echo -e "${YELLOW}后续步骤:${NC}"
echo "  1. 编辑提示语配置文件，添加你想自动注入的提示"
echo "  2. 重启 OpenCode / Claude Code 使配置生效"
if $CONFIGURE_CLAUDE; then
  echo ""
  echo "  验证 Claude Code hook（可选）:"
  echo -e "  ${CYAN}echo '{\"session_id\":\"test\",\"cwd\":\"${PWD}\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"hello\"}' | node ${INSTALL_DIR}/dist/claude-hook.js${NC}"
fi
echo ""
