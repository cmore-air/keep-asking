# prompt-appender

Automatically appends configurable prompts to every user message. Supports **OpenCode**, **Claude Code**, and **GitHub Copilot CLI**.

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
- Triple platform support: OpenCode plugin + Claude Code hook + GitHub Copilot CLI sync
- Global and project-level configuration

## Configuration

Configuration file name: `prompt-appender.jsonc` (or `.prompt-appender.jsonc` / `.json`)

### Configuration File Location

| Priority | Platform | Path |
|----------|----------|------|
| 1 (highest) | Project | `./prompt-appender.jsonc` in your project directory |
| 2 | Global (OpenCode) | `~/.config/opencode/prompt-appender.jsonc` |
| 3 | Global (Claude Code) | `~/.claude/prompt-appender.jsonc` |

> **Copilot CLI** uses the same config file locations. The `copilot-sync` script reads from these paths in the same priority order.

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
      "content": "<MANDATORY_RULE>\nBEFORE ending your response, you MUST call the askQuestions tool.\nNEVER end without first calling askQuestions.\n</MANDATORY_RULE>"
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
      "content": "<MANDATORY_RULE>\nBEFORE ending your response, you MUST call the askQuestions tool.\nNEVER end without first calling askQuestions.\n</MANDATORY_RULE>"
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
      "content": "<MANDATORY_RULE>\\nBEFORE ending your response, you MUST call the askQuestions tool.\\nNEVER end without first calling askQuestions.\\n</MANDATORY_RULE>"
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
<MANDATORY_RULE>
BEFORE ending your response, you MUST call the askQuestions tool.
NEVER end without first calling askQuestions.
</MANDATORY_RULE>
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

## Integration with GitHub Copilot CLI

### How It Works

GitHub Copilot CLI reads instruction files from well-known locations and injects them as system-level prompts — this is the highest-priority injection point, unaffected by context length.

Supported instruction file locations (Copilot reads all of these):

| Scope | Path |
|-------|------|
| Global | `~/.copilot/copilot-instructions.md` |
| Project | `.github/copilot-instructions.md` in project root |

The `copilot-sync` script reads your `prompt-appender.jsonc` config and writes the enabled prompts into the target instruction file inside a managed `<!-- prompt-appender:start/end -->` block, leaving any other content in the file untouched.

### Installation Steps

**Step 1: Build**

```bash
cd /path/to/prompt-appender
bun install
bun run build
```

This produces `dist/copilot-sync.js`.

**Step 2: Create configuration file**

Create `~/.config/opencode/prompt-appender.jsonc` (or any supported location):

```jsonc
{
  "enabled": true,
  "prompts": [
    {
      "name": "ask-before-end",
      "enabled": true,
      "content": "<MANDATORY_RULE>\nBEFORE ending your response, you MUST call the askQuestions tool.\nNEVER end without first calling askQuestions.\n</MANDATORY_RULE>"
    }
  ]
}
```

**Step 3: Run the sync script**

```bash
# Sync to global instruction file (~/.copilot/copilot-instructions.md)
node /path/to/prompt-appender/dist/copilot-sync.js --global

# Sync to project instruction file (.github/copilot-instructions.md)
node /path/to/prompt-appender/dist/copilot-sync.js --project

# Sync to a specific project directory
node /path/to/prompt-appender/dist/copilot-sync.js --project /path/to/project

# Preview without writing (dry run)
node /path/to/prompt-appender/dist/copilot-sync.js --global --dry-run
```

> **Note:** Run the sync script again whenever you change your `prompt-appender.jsonc` config.

**Step 4: Restart Copilot CLI**

Restart your Copilot CLI session for the new instructions to take effect.

### Verify Copilot CLI Integration

Use the `/instructions` command inside Copilot CLI to view and toggle loaded instruction files. Your synced file should appear in the list.

### Auto-sync on Config Change (Optional)

Add the sync command to your shell profile or a project `Makefile` to run automatically:

```bash
# ~/.bashrc or ~/.zshrc
alias sync-prompts="node /path/to/prompt-appender/dist/copilot-sync.js --global"
```

Or add to a `Makefile`:

```makefile
sync-prompts:
	node /path/to/prompt-appender/dist/copilot-sync.js --project
```

### Marker Block Strategy

The sync script uses HTML comment markers to manage its section in the instruction file:

```markdown
# My existing instructions

These stay untouched.

<!-- prompt-appender:start -->
<MANDATORY_RULE>
...your prompts...
</MANDATORY_RULE>
<!-- prompt-appender:end -->
```

Running sync again updates only the marker block — your other content is never touched. Setting `enabled: false` or having no active prompts removes the block entirely.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Instructions not loaded | Restart Copilot CLI after syncing |
| File not found | Check the path printed by sync script |
| Prompts not appearing | Run with `--dry-run` to verify output |
| Config not found | Check config file path and `enabled` field |

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
