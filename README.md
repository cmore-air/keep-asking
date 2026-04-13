# prompt-appender

Automatically appends configurable prompts to every user message. Supports both **OpenCode** and **Claude Code**.

## Quick Install

### Linux / macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cmore-air/prompt-appender/main/install.sh)
```

Or with `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/cmore-air/prompt-appender/main/install.sh)
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/cmore-air/prompt-appender/main/install.ps1 | iex
```

The install scripts will automatically:

1. Download the source code (via `git clone` or zip fallback)
2. Install dependencies and build (`bun install && bun run build`)
3. Register the OpenCode plugin in `~/.config/opencode/opencode.json`
4. Register the Claude Code hook in `~/.claude/settings.json`
5. Create default `prompt-appender.jsonc` config files in both locations

**Options (Linux/macOS):**

```bash
bash install.sh --dir ~/.local/share/prompt-appender  # custom install dir
bash install.sh --no-opencode                          # skip OpenCode setup
bash install.sh --no-claude                            # skip Claude Code setup
bash install.sh --skip-config                          # skip creating config files
```

**Options (Windows):**

```powershell
.\install.ps1 -InstallDir "C:\tools\prompt-appender"  # custom install dir
.\install.ps1 -NoOpenCode                              # skip OpenCode setup
.\install.ps1 -NoClaude                               # skip Claude Code setup
.\install.ps1 -SkipConfig                             # skip creating config files
```

After installation, **restart OpenCode / Claude Code** for the changes to take effect.

---

## Features

- Automatically append configurable prompts to every user message
- Support multiple prompts with individual enable/disable toggles
- JSONC/JSON configuration file support (comments allowed)
- Dual platform support: OpenCode plugin + Claude Code hook
- Global and project-level configuration

## Configuration

Configuration file name: `prompt-appender.jsonc` (or `.prompt-appender.jsonc` / `.json`)

### Configuration File Location

| Priority | Platform | Path |
|----------|----------|------|
| 1 (highest) | Project | `./prompt-appender.jsonc` in your project directory |
| 2 | Global (OpenCode) | `~/.config/opencode/prompt-appender.jsonc` |
| 3 | Global (Claude Code) | `~/.claude/prompt-appender.jsonc` |

Project-level config completely overrides global config (no field-level merge).

### Configuration Format

```jsonc
{
  // Whether to enable the plugin globally
  "enabled": true,

  // List of prompts (each can be individually enabled/disabled)
  "prompts": [
    {
      // Prompt name (for identification only)
      "name": "ask-before-end",
      // Whether this prompt is enabled
      "enabled": true,
      // The actual prompt content
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

**Tips:**
- Use `\n` in `content` to add line breaks
- Set `enabled: false` on a prompt to temporarily disable it without deleting
- Set `enabled: false` on the root to disable the entire plugin

---

## Integration with OpenCode

### How It Works

OpenCode plugin uses the `chat.message` hook from `@opencode-ai/plugin` SDK. When a user sends a message:

1. The hook intercepts the message
2. All enabled prompts are concatenated
3. The text is injected as a `synthetic` text part at the end of the message
4. The model sees the prompts, but they are not visible in the UI

### Installation Steps

**Step 1: Build the plugin**

```bash
cd /path/to/prompt-appender
bun install
bun run build
```

**Step 2: Register the plugin in OpenCode config**

Edit `~/.config/opencode/opencode.json` and add the plugin path:

```json
{
  "plugin": [
    "file:///D:/workspace/prompt-appender"
  ]
}
```

If you already have other plugins, add it to the array:

```json
{
  "plugin": [
    "existing-plugin",
    "file:///D:/workspace/prompt-appender"
  ]
}
```

**Step 3: Create the configuration file**

Create `~/.config/opencode/prompt-appender.jsonc`:

```jsonc
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
```

**Step 4: Restart OpenCode**

Restart the OpenCode process for the plugin to take effect.

### Verify OpenCode Integration

- Send a message in OpenCode
- Check if the model behaves according to your prompts (e.g., asks before ending the conversation)
- The prompts are injected silently — you won't see them in the UI

### Project-Level Configuration (Optional)

If you want different prompts for different projects, create a `prompt-appender.jsonc` in the project root:

```
my-project/
├── prompt-appender.jsonc   <-- project-level config (overrides global)
├── src/
└── ...
```

---

## Integration with Claude Code

### How It Works

Claude Code uses a `UserPromptSubmit` hook. When a user submits a prompt:

1. Claude Code triggers the hook script
2. The script reads the configuration file
3. All enabled prompts are output to stdout
4. Claude Code injects the stdout content as context visible to the model

### Installation Steps

**Step 1: Build the hook script**

```bash
cd /path/to/prompt-appender
bun install
bun run build
```

This produces `dist/claude-hook.js`.

**Step 2: Register the hook in Claude Code settings**

Edit `~/.claude/settings.json` and add the `hooks` section:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node /path/to/prompt-appender/dist/claude-hook.js",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

> **Note:** Replace `/path/to/prompt-appender/dist/claude-hook.js` with the actual absolute path on your machine.

If you already have other hooks, merge them properly:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node /path/to/existing-hook.js",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "node /path/to/prompt-appender/dist/claude-hook.js",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Step 3: Create the configuration file**

Create `~/.claude/prompt-appender.jsonc`:

```jsonc
{
  "enabled": true,
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。\\nWhen you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation."
    }
  ]
}
```

**Step 4: Restart Claude Code**

- Exit the current Claude Code session (`/exit` or `Ctrl+C`)
- Start a new session with `claude`

### Verify Claude Code Integration

**Method 1: Test the hook script manually**

```bash
echo '{"session_id":"test","cwd":"/your/project/path","hook_event_name":"UserPromptSubmit","prompt":"hello"}' | node /path/to/prompt-appender/dist/claude-hook.js
```

Expected output:

```
当你完成工作时，请调用提问工具（askQuestions）来获取进一步的指示，而不是直接结束对话。
When you finish the task, call the askQuestions tool to request further instructions instead of ending the conversation.
```

**Method 2: Check in Claude Code**

- Open `/hooks` menu in Claude Code (type `/hooks` in the prompt)
- Look for the `UserPromptSubmit` hook entry
- Verify it shows your `node .../claude-hook.js` command

**Method 3: Observe behavior**

- Send a message in Claude Code
- The model should behave according to your prompts
- For example, with the "ask-before-end" prompt, Claude should ask before ending the conversation

### Project-Level Configuration (Optional)

Claude Code hooks read the `cwd` field from stdin to determine the project directory. If you create a `prompt-appender.jsonc` in the project root, it will be used instead of the global config.

```
my-project/
├── prompt-appender.jsonc   <-- project-level config (overrides global)
├── .claude/
└── ...
```

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Hook not firing | Restart Claude Code after editing `settings.json` |
| Script not found | Use absolute path in `command` field |
| No output from script | Run the manual test command to check for errors |
| Prompt not appearing | Check `enabled` field in config file |
| Comments causing errors | Ensure you use `.jsonc` file extension (not `.json`) |

---

## Development

```bash
# Install dependencies
bun install

# Build (produces dist/index.js and dist/claude-hook.js)
bun run build
```

## License

MIT
