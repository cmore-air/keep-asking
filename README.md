# keep-asking

Forces AI assistants to always follow up with the user instead of silently ending the conversation. Supports **OpenCode** and **Claude Code**.

## What It Does

After every response, the AI is instructed:

> When the assistant has completed the current task, has no clear next action, or is about to end the response with a closing statement, it MUST proactively invoke the `askQuestions` tool to request further user instructions—never terminate the conversation on its own.

The prompt is injected automatically on every message — no configuration files needed.

## Quick Install

Give the following instruction to your AI assistant (Claude Code, GitHub Copilot CLI, OpenCode, Cursor, etc.):

```
Follow the installation instructions at https://github.com/cmore-air/keep-asking/blob/main/INSTALL.md
```

---

## Integration with OpenCode

### How It Works

Uses the `chat.message` hook from `@opencode-ai/plugin` SDK. The prompt is injected as a `synthetic` text part — visible to the model, hidden in the UI.

### Installation

**Step 1: Clone and build**

```bash
# Linux / macOS
git clone https://github.com/cmore-air/keep-asking ~/.local/share/keep-asking
cd ~/.local/share/keep-asking && npm install && npm run build

# Windows
git clone https://github.com/cmore-air/keep-asking %LOCALAPPDATA%\keep-asking
cd %LOCALAPPDATA%\keep-asking && npm install && npm run build
```

**Step 2: Register the plugin in OpenCode config**

Edit `~/.config/opencode/opencode.json` and add the plugin path to the `"plugin"` array:

```json
{
  "plugin": [
    "file:///absolute/path/to/keep-asking"
  ]
}
```

**Step 3: Restart OpenCode**

---

## Integration with Claude Code

### How It Works

Uses a `UserPromptSubmit` hook. The script outputs the prompt to stdout; Claude Code injects it as context on every message.

### Installation

**Step 1: Clone and build** (same as above)

**Step 2: Register the hook in `~/.claude/settings.json`**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/keep-asking/dist/claude-hook.js\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Step 3: Restart Claude Code**

```bash
claude
```

### Verify

Test the hook script directly:

```bash
node /path/to/keep-asking/dist/claude-hook.js
```

Expected output:

```
When the assistant has completed the current task, has no clear next action, or is about to end the response with a closing statement, it MUST proactively invoke the askQuestions tool to request further user instructions—never terminate the conversation on its own.
```

---

## Development

```bash
npm install
npm run build   # produces dist/index.js and dist/claude-hook.js
```

## License

MIT


