# Installation Guide

## Quick Install (AI-Powered)

Copy the prompt below and paste it into your AI assistant (Claude Code, GitHub Copilot CLI, OpenCode, Cursor, etc.). The AI will handle the entire installation for you.

```
<INSTALL_KEEP_ASKING>
You MUST install the keep-asking tool by following ALL steps below exactly.
You MUST adapt file paths for the current operating system (Windows / Linux / macOS).
Do NOT skip any step. Do NOT ask for confirmation between steps. Execute everything in sequence.

<STEP_1>
<title>Clone the repository</title>

Clone https://github.com/cmore-air/keep-asking to a permanent location:
- Linux / macOS:  ~/.local/share/keep-asking
- Windows:        %LOCALAPPDATA%\keep-asking

If the target directory already exists with a .git folder, run `git pull` to update instead of cloning.
You MUST verify the clone succeeded before proceeding.
</STEP_1>

<STEP_2>
<title>Install dependencies and build</title>

cd into the installation directory. You MUST run these commands:
  npm install
  npm run build

After build, you MUST verify ALL of the following files exist:
  - dist/index.js
  - dist/claude-hook.js

If any file is missing, the build FAILED — do NOT proceed. Report the error.
</STEP_2>

<STEP_3>
<title>Configure OpenCode integration</title>

Only execute this step if OpenCode is installed on this machine. Skip otherwise.

Edit ~/.config/opencode/opencode.json.
If the file does not exist, create it with content: {}
You MUST add the following entry to the "plugin" array (create the array if it does not exist):
  "file:///<absolute-path-to-install-dir>"
  Windows example:   "file:///C:/Users/me/AppData/Local/keep-asking"
  Linux/macOS example: "file:///home/me/.local/share/keep-asking"

IMPORTANT: Do NOT overwrite existing plugin entries. APPEND only.
</STEP_3>

<STEP_4>
<title>Configure Claude Code integration</title>

Only execute this step if Claude Code is installed on this machine. Skip otherwise.

Edit ~/.claude/settings.json.
If the file does not exist, create it with content: {}
You MUST merge the following JSON into the existing content. NEVER delete existing keys:

{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node \"<absolute-path-to-install-dir>/dist/claude-hook.js\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}

CRITICAL merge rules:
- If hooks.UserPromptSubmit already has a group with "matcher": "", APPEND the new hook object to that group's hooks array.
- If no such group exists, ADD the entire new group.
- NEVER duplicate — check by command string before adding.

Windows example command:   node "C:\Users\me\AppData\Local\keep-asking\dist\claude-hook.js"
Linux/macOS example command: node "/home/me/.local/share/keep-asking/dist/claude-hook.js"
</STEP_4>

<STEP_5>
<title>Report results</title>

After ALL steps are done, you MUST report:
1. The installation directory path
2. Every file you created or modified (full paths)
3. A reminder to the user: "Restart your AI tool for changes to take effect."
</STEP_5>

</INSTALL_KEEP_ASKING>
```

> **Tip:** You can also ask your AI to fetch the raw prompt directly:
> `curl -fsSL https://raw.githubusercontent.com/cmore-air/keep-asking/main/INSTALL.md`
> Then tell it to find the "Quick Install" section and follow the instructions.


