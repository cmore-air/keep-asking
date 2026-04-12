# prompt-appender

A plugin that automatically appends configurable prompts to every user message. Supports both **OpenCode** and **Claude Code**.

## Features

- Automatically append configurable prompts to every user message
- Support multiple prompts with individual enable/disable toggles
- JSONC/JSON configuration file support
- Dual platform support: OpenCode plugin + Claude Code hook
- Global and project-level configuration

## How It Works

### OpenCode
Uses the `chat.message` hook via `@opencode-ai/plugin` SDK to inject prompts as synthetic text parts. The prompts are visible to the model but not shown in the UI.

### Claude Code
Uses the `UserPromptSubmit` hook to output prompts to stdout, which Claude Code injects into the context.

## Configuration

Configuration file name: `prompt-appender.jsonc` (or `.json`)

### File Lookup Order
1. Project directory: `./prompt-appender.jsonc`
2. Global OpenCode: `~/.config/opencode/prompt-appender.jsonc`
3. Global Claude Code: `~/.claude/prompt-appender.jsonc`

### Example Configuration
```jsonc
{
  // Global switch
  "enabled": true,
  
  // Prompt list
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。\nWhen you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation."
    },
    {
      "name": "think-step-by-step",
      "enabled": false,
      "content": "请逐步思考，不要跳步。"
    }
  ]
}
```

## Installation

### For OpenCode

Add the plugin to your `~/.config/opencode/opencode.json`:

```json
{
  "plugin": ["file:///path/to/prompt-appender"]
}
```

### For Claude Code

The plugin hooks are already configured in `~/.claude/settings.json`. Just make sure `node` is available in your PATH.

## Development

```bash
# Install dependencies
bun install

# Build
bun run build
```

## License

MIT
