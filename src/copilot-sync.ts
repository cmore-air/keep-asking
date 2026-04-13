#!/usr/bin/env node

/**
 * GitHub Copilot CLI 指令同步脚本
 *
 * 将 prompt-appender 配置中的提示语同步写入 Copilot CLI 指令文件。
 * Copilot CLI 启动时会读取这些指令文件，作为系统级提示词注入对话中。
 *
 * 指令文件位置（按优先级）：
 * - 全局：~/.copilot/copilot-instructions.md
 * - 项目：.github/copilot-instructions.md（在项目根目录下）
 *
 * 使用方式：
 *   node dist/copilot-sync.js              # 同步到全局指令文件
 *   node dist/copilot-sync.js --global     # 同步到全局指令文件
 *   node dist/copilot-sync.js --project    # 同步到当前目录的项目指令文件
 *   node dist/copilot-sync.js --project /path/to/project  # 同步到指定项目
 *   node dist/copilot-sync.js --dry-run    # 仅预览，不写入文件
 *
 * 文件内容采用 marker 区块策略，只更新 prompt-appender 管理的区块，
 * 不破坏文件中的其他内容。
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";
import { loadConfig } from "./config";

// ===== 常量 =====

const MARKER_START = "<!-- prompt-appender:start -->";
const MARKER_END = "<!-- prompt-appender:end -->";

// ===== CLI 参数解析 =====

interface SyncOptions {
  mode: "global" | "project";
  projectDir: string;
  dryRun: boolean;
}

function parseArgs(args: string[]): SyncOptions {
  const opts: SyncOptions = {
    mode: "global",
    projectDir: process.cwd(),
    dryRun: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]!;
    if (arg === "--global") {
      opts.mode = "global";
    } else if (arg === "--project") {
      opts.mode = "project";
      const next = args[i + 1];
      if (next && !next.startsWith("--")) {
        opts.projectDir = next;
        i++;
      }
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    }
  }

  return opts;
}

// ===== 目标路径解析 =====

function resolveTargetPath(opts: SyncOptions): string {
  if (opts.mode === "global") {
    return join(homedir(), ".copilot", "copilot-instructions.md");
  }
  return join(opts.projectDir, ".github", "copilot-instructions.md");
}

// ===== Marker 区块写入 =====

/**
 * 将 content 插入/更新目标文件中的 prompt-appender 区块。
 * 若区块不存在则追加到文件末尾；若 content 为空则移除区块。
 */
function mergeIntoFile(filePath: string, content: string): string {
  let existing = "";
  if (existsSync(filePath)) {
    existing = readFileSync(filePath, "utf-8");
  }

  const startIdx = existing.indexOf(MARKER_START);
  const endIdx = existing.indexOf(MARKER_END);

  if (content.trim().length === 0) {
    // 无内容：移除区块（如果存在）
    if (startIdx !== -1 && endIdx !== -1) {
      const before = existing.slice(0, startIdx).trimEnd();
      const after = existing.slice(endIdx + MARKER_END.length).trimStart();
      return before + (before && after ? "\n\n" : before ? "\n" : "") + after;
    }
    return existing;
  }

  const block = `${MARKER_START}\n${content.trimEnd()}\n${MARKER_END}`;

  if (startIdx !== -1 && endIdx !== -1) {
    // 替换现有区块
    const before = existing.slice(0, startIdx);
    const after = existing.slice(endIdx + MARKER_END.length);
    return before + block + after;
  }

  // 追加到末尾
  const trimmed = existing.trimEnd();
  return trimmed ? `${trimmed}\n\n${block}\n` : `${block}\n`;
}

// ===== 主逻辑 =====

function main() {
  const args = process.argv.slice(2);
  const opts = parseArgs(args);
  const targetPath = resolveTargetPath(opts);

  // 加载配置（项目模式从项目目录读，全局模式从当前目录读）
  const configDir = opts.mode === "project" ? opts.projectDir : process.cwd();
  const config = loadConfig(configDir);

  let promptContent = "";

  if (config.enabled) {
    const activePrompts = config.prompts
      .filter((p) => p.enabled && p.content.trim().length > 0)
      .map((p) => p.content);

    if (activePrompts.length > 0) {
      promptContent = activePrompts.join("\n\n");
    }
  }

  const newFileContent = mergeIntoFile(targetPath, promptContent);

  if (opts.dryRun) {
    console.log(`[dry-run] Target: ${targetPath}`);
    console.log("─".repeat(60));
    console.log(newFileContent || "(empty file)");
    return;
  }

  // 确保目录存在
  const dir = dirname(targetPath);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  writeFileSync(targetPath, newFileContent, "utf-8");
  console.log(`✓ Synced to: ${targetPath}`);

  if (promptContent.trim().length === 0) {
    console.log("  (prompt-appender section removed — no active prompts)");
  } else {
    const lines = promptContent.split("\n").length;
    console.log(`  ${lines} line(s) written`);
  }
}

main();
