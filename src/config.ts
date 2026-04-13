import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

/**
 * 单条提示语配置
 */
export interface PromptItem {
  /** 提示语名称（用于标识） */
  name: string;
  /** 是否启用该条提示语 */
  enabled: boolean;
  /** 提示语内容 */
  content: string;
}

/**
 * 插件完整配置
 */
export interface PromptAppenderConfig {
  /** 是否启用插件（全局开关） */
  enabled: boolean;
  /** 提示语列表 */
  prompts: PromptItem[];
}

/** 默认配置 */
const DEFAULT_CONFIG: PromptAppenderConfig = {
  enabled: true,
  prompts: [],
};

/** 项目级配置文件名（按优先级排序） */
const PROJECT_CONFIG_FILES = [
  "prompt-appender.jsonc",
  "prompt-appender.json",
  ".prompt-appender.jsonc",
  ".prompt-appender.json",
];

/** 全局配置目录（按优先级排序） */
const GLOBAL_CONFIG_DIRS = [
  join(homedir(), ".config", "opencode"),
  join(homedir(), ".claude"),
];

/** 全局配置文件名（按优先级排序） */
const GLOBAL_CONFIG_FILES = [
  "prompt-appender.jsonc",
  "prompt-appender.json",
];

/**
 * 剥离 JSONC 注释，返回纯 JSON 字符串
 *
 * NOTE: 简化版 JSONC 解析器，支持 // 和 /* 注释，
 * 正确处理字符串内的注释字符和转义引号，移除尾随逗号。
 */
function stripJsoncComments(text: string): string {
  let result = "";
  let inString = false;
  let i = 0;

  while (i < text.length) {
    const char = text[i]!;
    const nextChar = text[i + 1];

    // 处理字符串内的转义引号
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

    // 进入字符串
    if (char === '"') {
      inString = true;
      result += char;
      i++;
      continue;
    }

    // 单行注释
    if (char === "/" && nextChar === "/") {
      while (i < text.length && text[i] !== "\n") {
        i++;
      }
      continue;
    }

    // 多行注释
    if (char === "/" && nextChar === "*") {
      i += 2;
      while (i < text.length - 1 && !(text[i] === "*" && text[i + 1] === "/")) {
        i++;
      }
      i += 2; // 跳过 */
      continue;
    }

    result += char;
    i++;
  }

  // 移除尾随逗号（] 或 } 前的逗号）
  return result.replace(/,(\s*[}\]])/g, "$1");
}

/**
 * 安全解析 JSONC 文件内容
 */
function parseJsonc<T>(content: string): T | null {
  try {
    const stripped = stripJsoncComments(content);
    return JSON.parse(stripped) as T;
  } catch {
    return null;
  }
}

/**
 * 在指定目录中查找配置文件
 */
function findConfigFile(directory: string, fileNames: string[]): string | null {
  for (const fileName of fileNames) {
    const filePath = join(directory, fileName);
    if (existsSync(filePath)) {
      return filePath;
    }
  }
  return null;
}

/**
 * 从文件路径加载配置
 */
function loadConfigFromFile(filePath: string): PromptAppenderConfig | null {
  try {
    const content = readFileSync(filePath, "utf-8");
    const parsed = parseJsonc<Partial<PromptAppenderConfig>>(content);
    if (!parsed) return null;

    return {
      enabled: parsed.enabled ?? DEFAULT_CONFIG.enabled,
      prompts: Array.isArray(parsed.prompts)
        ? parsed.prompts.map((p) => ({
            name: p.name ?? "unnamed",
            enabled: p.enabled ?? true,
            content: p.content ?? "",
          }))
        : DEFAULT_CONFIG.prompts,
    };
  } catch {
    return null;
  }
}

/**
 * 加载配置（项目级优先，全局兜底）
 *
 * 查找顺序：
 * 1. 项目目录：prompt-appender.jsonc / .json / .prompt-appender.jsonc / .json
 * 2. 全局目录：~/.config/opencode/prompt-appender.jsonc / .json
 *
 * 项目级配置完全覆盖全局配置（不做字段级合并）。
 */
export function loadConfig(projectDirectory: string): PromptAppenderConfig {
  // 1. 先查找项目级配置
  const projectConfigPath = findConfigFile(projectDirectory, PROJECT_CONFIG_FILES);
  if (projectConfigPath) {
    const config = loadConfigFromFile(projectConfigPath);
    if (config) return config;
  }

  // 2. 查找全局配置（多个目录）
  for (const dir of GLOBAL_CONFIG_DIRS) {
    const globalConfigPath = findConfigFile(dir, GLOBAL_CONFIG_FILES);
    if (globalConfigPath) {
      const config = loadConfigFromFile(globalConfigPath);
      if (config) return config;
    }
  }

  // 3. 返回默认配置（空提示语列表，插件虽启用但无效果）
  return { ...DEFAULT_CONFIG };
}
