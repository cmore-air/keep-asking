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

import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// ===== 类型定义 =====

interface PromptItem {
  name: string;
  enabled: boolean;
  content: string;
}

interface PromptAppenderConfig {
  enabled: boolean;
  prompts: PromptItem[];
}

interface HookInput {
  session_id: string;
  cwd: string;
  hook_event_name: string;
  prompt?: string;
  [key: string]: unknown;
}

// ===== JSONC 解析 =====

function stripJsoncComments(text: string): string {
  let result = "";
  let inString = false;
  let i = 0;

  while (i < text.length) {
    const char = text[i]!;
    const nextChar = text[i + 1];

    if (inString) {
      if (char === "\\" && i + 1 < text.length) {
        result += char + (nextChar ?? "");
        i += 2;
        continue;
      }
      if (char === '"') {
        inString = false;
      }
      result += char;
      i++;
      continue;
    }

    if (char === '"') {
      inString = true;
      result += char;
      i++;
      continue;
    }

    if (char === "/" && nextChar === "/") {
      while (i < text.length && text[i] !== "\n") {
        i++;
      }
      continue;
    }

    if (char === "/" && nextChar === "*") {
      i += 2;
      while (i < text.length - 1 && !(text[i] === "*" && text[i + 1] === "/")) {
        i++;
      }
      i += 2;
      continue;
    }

    result += char;
    i++;
  }

  return result.replace(/,(\s*[}\]])/g, "$1");
}

function parseJsonc<T>(content: string): T | null {
  try {
    return JSON.parse(stripJsoncComments(content)) as T;
  } catch {
    return null;
  }
}

// ===== 配置加载 =====

const PROJECT_CONFIG_FILES = [
  "prompt-appender.jsonc",
  "prompt-appender.json",
  ".prompt-appender.jsonc",
  ".prompt-appender.json",
];

const GLOBAL_CONFIG_DIRS = [
  join(homedir(), ".config", "opencode"),
  join(homedir(), ".claude"),
];

const GLOBAL_CONFIG_FILES = [
  "prompt-appender.jsonc",
  "prompt-appender.json",
];

function findConfigFile(directory: string, fileNames: string[]): string | null {
  for (const fileName of fileNames) {
    const filePath = join(directory, fileName);
    if (existsSync(filePath)) {
      return filePath;
    }
  }
  return null;
}

function loadConfigFromFile(filePath: string): PromptAppenderConfig | null {
  try {
    const content = readFileSync(filePath, "utf-8");
    const parsed = parseJsonc<Partial<PromptAppenderConfig>>(content);
    if (!parsed) return null;

    return {
      enabled: parsed.enabled ?? true,
      prompts: Array.isArray(parsed.prompts)
        ? parsed.prompts.map((p) => ({
            name: p.name ?? "unnamed",
            enabled: p.enabled ?? true,
            content: p.content ?? "",
          }))
        : [],
    };
  } catch {
    return null;
  }
}

function loadConfig(projectDirectory?: string): PromptAppenderConfig {
  // 1. 项目级配置
  if (projectDirectory) {
    const configPath = findConfigFile(projectDirectory, PROJECT_CONFIG_FILES);
    if (configPath) {
      const config = loadConfigFromFile(configPath);
      if (config) return config;
    }
  }

  // 2. 全局配置（多个目录）
  for (const dir of GLOBAL_CONFIG_DIRS) {
    const configPath = findConfigFile(dir, GLOBAL_CONFIG_FILES);
    if (configPath) {
      const config = loadConfigFromFile(configPath);
      if (config) return config;
    }
  }

  return { enabled: true, prompts: [] };
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
