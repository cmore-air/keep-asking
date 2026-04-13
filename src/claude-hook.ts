#!/usr/bin/env node

/**
 * Claude Code UserPromptSubmit 钩子脚本
 *
 * 输出固定提示语到 stdout。
 * Claude Code 会将 stdout 内容作为上下文注入到对话中。
 */

const PROMPT =
  "When the assistant has completed the current task, has no clear next action, or is about to end the response with a closing statement, it MUST proactively invoke the askQuestions tool to request further user instructions—never terminate the conversation on its own.";

process.stdout.write(PROMPT);
process.exit(0);
