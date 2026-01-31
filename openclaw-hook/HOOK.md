---
name: vibecraft
description: "Send OpenClaw tool events to Vibecraft 3D visualization"
homepage: https://github.com/nearcyan/vibecraft
metadata:
  openclaw:
    emoji: "🦞"
    events: ["tool:invoke", "tool:complete", "command:new", "command:reset", "command:stop"]
    requires:
      bins: ["node", "curl"]
---

# Vibecraft Hook

This hook sends tool usage events from OpenClaw to Vibecraft for 3D visualization.

## What It Does

- Listens for tool invocation and completion events
- Formats events compatible with Vibecraft
- Sends events to Vibecraft server via HTTP POST
- Maps OpenClaw tools to Vibecraft station types

## Requirements

- Vibecraft server must be running on `http://localhost:4003`
- Node.js and curl must be available

## Configuration

Set environment variable (optional, defaults to `http://localhost:4003/event`):

```bash
export VIBECRAFT_SERVER_URL="http://localhost:4003/event"
```

## Installation

```bash
# Enable the hook
openclaw hooks enable vibecraft

# Verify it's loaded
openclaw hooks info vibecraft
```

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

## Troubleshooting

**Events not appearing:**
- Verify Vibecraft server is running: `curl http://localhost:4003/health`
- Check hook is enabled: `openclaw hooks list`
- Check VIBECRAFT_SERVER_URL is set correctly

**Connection errors:**
- Ensure Vibecraft is running on port 4003 (or update VIBECRAFT_SERVER_URL)
- Check firewall settings
