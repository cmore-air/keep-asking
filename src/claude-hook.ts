#!/usr/bin/env node

/**
 * Claude Code UserPromptSubmit 钩子脚本
 *
 * 读取 prompt-appender 配置文件，输出所有已启用的提示语到 stdout。
 * Claude Code 会将 stdout 内容作为上下文注入到 Claude 的对话中。
 *
 * 配置文件查找顺序：
 * 1. 项目目录（从 stdin 的 cwd 字段获取）：prompt-appender.jsonc / .json
 * 2. 全局目录：~/.config/opencode/prompt-appender.jsonc / .json
 * 3. 全局目录：~/.claude/prompt-appender.jsonc / .json
 */

import { loadConfig } from "./config";

// ===== 类型定义 =====

interface HookInput {
  session_id: string;
  cwd: string;
  hook_event_name: string;
  prompt?: string;
  [key: string]: unknown;
}

// ===== 主逻辑 =====

async function main() {
  try {
    // 从 stdin 读取 Claude Code 传入的 JSON
    let stdinData = "";
    for await (const chunk of process.stdin) {
      stdinData += chunk;
    }

    let hookInput: HookInput | null = null;
    try {
      hookInput = JSON.parse(stdinData) as HookInput;
    } catch {
      // stdin 解析失败，使用当前目录
    }

    const projectDir = hookInput?.cwd ?? process.cwd();
    const config = loadConfig(projectDir);

    if (!config.enabled) {
      process.exit(0);
    }

    const activePrompts = config.prompts
      .filter((p) => p.enabled && p.content.trim().length > 0)
      .map((p) => p.content);

    if (activePrompts.length === 0) {
      process.exit(0);
    }

    // 输出到 stdout —— Claude Code 会将其作为上下文注入
    const output = activePrompts.join("\n\n");
    process.stdout.write(output);
    process.exit(0);
  } catch {
    // 静默失败，不影响正常对话
    process.exit(0);
  }
}

main();
