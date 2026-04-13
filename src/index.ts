import type { Plugin } from "@opencode-ai/plugin";
import type { Part } from "@opencode-ai/sdk";

const PROMPT =
  "When the assistant has completed the current task, has no clear next action, or is about to end the response with a closing statement, it MUST proactively invoke the askQuestions tool to request further user instructions—never terminate the conversation on its own.";

const PromptAppenderPlugin: Plugin = async (_input) => {
  return {
    "chat.message": async (hookInput, output) => {
      try {
        const appendPart: Part = {
          id: `prt-prompt-appender-${Date.now()}`,
          sessionID: hookInput.sessionID,
          messageID: output.message.id,
          type: "text",
          text: PROMPT,
          synthetic: true,
        };
        output.parts.push(appendPart);
      } catch {
        // 静默失败，不影响正常对话
      }
    },
  };
};

export default PromptAppenderPlugin;
