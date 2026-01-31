# Add OpenClaw Integration

## Summary

This PR adds native support for **OpenClaw** - a universal AI gateway that works with Claude, OpenAI, and other models. This enables:

- **Windows users** to use Vibecraft (previously macOS/Linux only due to bash hook requirements)
- **Unified interface** for multiple AI models with 3D visualization
- **Event-driven integration** using OpenClaw's hook system

## What Changed

### New Files

- `openclaw-hook/HOOK.md` - OpenClaw hook metadata and documentation
- `openclaw-hook/handler.ts` - Main hook implementation for event transformation
- `openclaw-hook/package.json` - Hook dependencies and scripts
- `openclaw-hook/tsconfig.json` - TypeScript configuration
- `openclaw-hook/README.md` - Detailed hook documentation
- `openclaw-hook/.gitignore` - Ignore node_modules and build artifacts

### Modified Files

- `README.md` - Added OpenClaw integration section with quick start guide

## How It Works

The OpenClaw hook:

1. **Listens to events**: Subscribes to `tool:invoke`, `tool:complete`, `command:new`, `command:reset`, `command:stop`, and `message:submit` events from OpenClaw

2. **Transforms events**: Converts OpenClaw's event format to Vibecraft's format

3. **Forwards events**: Sends events to Vibecraft server via HTTP POST to `/event` endpoint

### Tool Mapping

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

## Installation for Users

### Prerequisites

- Node.js 18+
- OpenClaw installed (`npm install -g openclaw`)
- Vibecraft server running (`npx vibecraft`)

### Setup

```bash
# Install and enable the hook
cd ~/.openclaw/hooks
git clone https://github.com/nearcyan/vibecraft vibecraft
cd vibecraft
openclaw hooks enable vibecraft

# Set Vibecraft server URL (optional, defaults to localhost:4003)
export VIBECRAFT_SERVER_URL="http://localhost:4003/event"

# Use OpenClaw normally
openclaw agent --message "Read the package.json file"
```

## Testing

1. Start Vibecraft server:
   ```bash
   npx vibecraft
   ```

2. Enable the hook:
   ```bash
   cd ~/.openclaw/hooks/vibecraft
   openclaw hooks enable vibecraft
   ```

3. Send a message with OpenClaw:
   ```bash
   openclaw agent --message "Read the README.md file"
   ```

4. Verify events appear in the 3D visualization at http://localhost:4003

## Benefits

- **Cross-platform support**: Windows users can now use Vibecraft via OpenClaw
- **Model flexibility**: Works with Claude, OpenAI, and other models through OpenClaw
- **Minimal changes**: No modifications to Vibecraft core required
- **Clean architecture**: Uses OpenClaw's standard hook system
- **Extensible**: Easy to add support for additional OpenClaw tools

## Breaking Changes

None. This is a pure addition that doesn't affect existing Claude Code hook functionality.

## Related

- [OpenClaw repository](https://github.com/openclaw/openclaw)
- [OpenClaw documentation](https://docs.openclaw.ai)

## Checklist

- [x] Code follows project style guidelines
- [x] Documentation updated
- [x] Tested locally
- [x] No breaking changes to existing functionality
