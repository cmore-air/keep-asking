import type { Plugin } from "@opencode-ai/plugin";
import type { Part } from "@opencode-ai/sdk";
import { loadConfig } from "./config";

/**
 * prompt-appender 插件
 *
 * 每次用户发消息时，自动将配置的提示语追加到消息末尾。
 * 提示语以 synthetic text part 形式注入，模型可见但用户界面不显示。
 *
 * 配置文件查找顺序：
 * 1. 项目目录：prompt-appender.jsonc / .json
 * 2. 全局目录：~/.config/opencode/prompt-appender.jsonc / .json
 */
const PromptAppenderPlugin: Plugin = async (input) => {
  const config = loadConfig(input.directory);

  // 未启用或无提示语则返回空壳，不注册任何钩子
  if (!config.enabled) {
    return {};
  }

  // 预收集所有已启用的提示语内容，避免每次消息都重新过滤
  const activePrompts = config.prompts
    .filter((p) => p.enabled && p.content.trim().length > 0)
    .map((p) => p.content);

  if (activePrompts.length === 0) {
    return {};
  }

  // 预拼接为一段完整文本
  const appendText = activePrompts.join("\n\n");

  return {
    "chat.message": async (hookInput, output) => {
      try {
        const appendPart: Part = {
          id: `prt-prompt-appender-${Date.now()}`,
          sessionID: hookInput.sessionID,
          messageID: output.message.id,
          type: "text",
          text: appendText,
          synthetic: true,
        };

        // 追加到消息末尾
        output.parts.push(appendPart);
      } catch {
        // 静默失败，不影响正常对话
      }
    },
  };
};

export default PromptAppenderPlugin;
