# OpenClaw Hook for Vibecraft

This directory contains the OpenClaw hook that integrates Vibecraft's 3D visualization with OpenClaw's universal AI gateway.

## What is OpenClaw?

[OpenClaw](https://github.com/openclaw/openclaw) is a universal AI gateway that provides a unified interface for working with multiple AI models (Claude, OpenAI, and others). It features a powerful hook system for event-driven automation.

## How This Hook Works

1. **Event Listening**: The hook subscribes to OpenClaw events:
   - `tool:invoke` - When a tool is called
   - `tool:complete` - When a tool finishes
   - `command:new` - When a new agent session starts
   - `command:reset` / `command:stop` - When sessions end
   - `message:submit` - When user messages are sent

2. **Event Transformation**: Converts OpenClaw's event format to Vibecraft's format

3. **Event Forwarding**: Sends events to Vibecraft server via HTTP POST

## Installation

### Option 1: Install from Git (Recommended)

```bash
# Navigate to OpenClaw hooks directory
cd ~/.openclaw/hooks

# Clone this repository
git clone https://github.com/nearcyan/vibecraft vibecraft

# Enable the hook
openclaw hooks enable vibecraft

# Verify it's loaded
openclaw hooks info vibecraft
```

### Option 2: Manual Installation

```bash
# Copy this directory to your OpenClaw hooks folder
cp -r /path/to/vibecraft/openclaw-hook ~/.openclaw/hooks/vibecraft

# Enable the hook
openclaw hooks enable vibecraft
```

## Configuration

Set the Vibecraft server URL via environment variable:

```bash
# Linux/macOS
export VIBECRAFT_SERVER_URL="http://localhost:4003/event"

# Windows PowerShell
$env:VIBECRAFT_SERVER_URL="http://localhost:4003/event"

# Windows CMD
set VIBECRAFT_SERVER_URL=http://localhost:4003/event
```

**Default**: `http://localhost:4003/event`

## Usage

1. Start Vibecraft server:
   ```bash
   npx vibecraft
   ```

2. Use OpenClaw normally:
   ```bash
   openclaw agent --message "Read the package.json file"
   ```

3. Watch the 3D visualization update in real-time!

## Development

### Building the Hook

```bash
npm install
npm run build
```

### Development Mode

```bash
npm run dev
```

### File Structure

```
openclaw-hook/
├── HOOK.md          # Hook metadata and documentation
├── handler.ts       # Main hook implementation
├── package.json     # Dependencies
├── tsconfig.json    # TypeScript configuration
└── README.md        # This file
```

## Troubleshooting

### Events not appearing in Vibecraft

1. Verify Vibecraft server is running:
   ```bash
   curl http://localhost:4003/health
   ```

2. Check the hook is enabled:
   ```bash
   openclaw hooks list
   ```

3. Check VIBECRAFT_SERVER_URL is set correctly:
   ```bash
   echo $VIBECRAFT_SERVER_URL  # Linux/macOS
   echo $env:VIBECRAFT_SERVER_URL  # PowerShell
   ```

4. Check hook logs for errors:
   ```bash
   # OpenClaw logs hook errors to stderr
   openclaw agent --message "test" 2>&1 | grep vibecraft
   ```

### Connection errors

- Ensure Vibecraft is running on port 4003 (or update VIBECRAFT_SERVER_URL)
- Check firewall settings
- Verify OpenClaw can reach the Vibecraft server

### Hook not loading

1. Verify the hook directory structure:
   ```bash
   ls -la ~/.openclaw/hooks/vibecraft/
   ```

2. Check HOOK.md has valid YAML frontmatter:
   ```bash
   head -20 ~/.openclaw/hooks/vibecraft/HOOK.md
   ```

3. Verify handler.ts compiles:
   ```bash
   cd ~/.openclaw/hooks/vibecraft
   npm run build
   ```

## Supported Events

| Event Type | Action | Vibecraft Type |
|------------|--------|----------------|
| `tool` | `invoke` | `pre_tool_use` |
| `tool` | `complete` | `post_tool_use` |
| `command` | `new` | `session_start` |
| `command` | `reset` / `stop` | `session_end` |
| `message` | `submit` | `user_prompt_submit` |

## Tool Mapping

| OpenClaw Tool | Vibecraft Tool | Station |
|---------------|----------------|---------|
| `read_file` | `Read` | Bookshelf |
| `write_file` | `Write` | Desk |
| `edit_file` | `Edit` | Workbench |
| `exec` / `bash` | `Bash` | Terminal |
| `web_search` | `WebSearch` | Antenna |
| `web_fetch` | `WebFetch` | Antenna |
| `grep` | `Grep` | Scanner |
| `glob` | `Glob` | Scanner |
| `task` | `Task` | Portal |
| `todo` | `TodoWrite` | Taskboard |

## Contributing

To add support for additional tools, edit the `toolMap` object in `handler.ts`:

```typescript
const toolMap: Record<string, string> = {
  'existing_tool': 'VibecraftTool',
  'new_tool': 'NewVibecraftTool',
};
```

## License

MIT - Same as Vibecraft
