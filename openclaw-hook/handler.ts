import type { HookHandler } from 'openclaw';

interface VibecraftEvent {
  id: string;
  timestamp: number;
  type: string;
  sessionId: string;
  cwd: string;
  tool?: string;
  toolInput?: Record<string, unknown>;
  toolResponse?: Record<string, unknown>;
  success?: boolean;
  response?: string;
  prompt?: string;
  reason?: string;
}

const toolMap: Record<string, string> = {
  'read_file': 'Read',
  'write_file': 'Write',
  'edit_file': 'Edit',
  'exec': 'Bash',
  'bash': 'Bash',
  'shell': 'Bash',
  'web_search': 'WebSearch',
  'web_fetch': 'WebFetch',
  'browser_search': 'WebSearch',
  'browser_fetch': 'WebFetch',
  'grep': 'Grep',
  'glob': 'Glob',
  'find_files': 'Glob',
  'task': 'Task',
  'subagent': 'Task',
  'todo': 'TodoWrite',
  'add_todo': 'TodoWrite',
};

function getVibecraftToolName(toolName: string): string {
  return toolMap[toolName] || toolName;
}

function generateEventId(sessionKey: string): string {
  return `openclaw-${sessionKey}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

async function sendToVibecraft(event: VibecraftEvent): Promise<void> {
  const VIBECRAFT_URL = process.env.VIBECRAFT_SERVER_URL || 'http://localhost:4003/event';

  try {
    const response = await fetch(VIBECRAFT_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(event),
    });

    if (!response.ok) {
      console.error('[vibecraft-hook] Failed to send event:', response.statusText);
    }
  } catch (error) {
    console.error('[vibecraft-hook] Error sending event:', error);
  }
}

const vibecraftHandler: HookHandler = async (event) => {
  const { type, action, sessionKey, data } = event;

  const cwd = data?.cwd || process.cwd();

  if (type === 'tool') {
    if (action === 'invoke') {
      const vibecraftEvent: VibecraftEvent = {
        id: generateEventId(sessionKey),
        timestamp: Date.now(),
        type: 'pre_tool_use',
        sessionId: sessionKey,
        cwd,
        tool: getVibecraftToolName(data.toolName),
        toolInput: data.input || {},
        toolUseId: data.toolId || generateEventId(sessionKey),
      };
      await sendToVibecraft(vibecraftEvent);
    } else if (action === 'complete') {
      const vibecraftEvent: VibecraftEvent = {
        id: generateEventId(sessionKey),
        timestamp: Date.now(),
        type: 'post_tool_use',
        sessionId: sessionKey,
        cwd,
        tool: getVibecraftToolName(data.toolName),
        toolInput: data.input || {},
        toolResponse: data.output || {},
        toolUseId: data.toolId || generateEventId(sessionKey),
        success: data.success !== false,
      };
      await sendToVibecraft(vibecraftEvent);
    }
  } else if (type === 'command') {
    if (action === 'new') {
      const vibecraftEvent: VibecraftEvent = {
        id: generateEventId(sessionKey),
        timestamp: Date.now(),
        type: 'session_start',
        sessionId: sessionKey,
        cwd,
        prompt: data?.prompt || '',
      };
      await sendToVibecraft(vibecraftEvent);
    } else if (action === 'reset' || action === 'stop') {
      const vibecraftEvent: VibecraftEvent = {
        id: generateEventId(sessionKey),
        timestamp: Date.now(),
        type: 'session_end',
        sessionId: sessionKey,
        cwd,
        reason: action,
        response: data?.response || '',
      };
      await sendToVibecraft(vibecraftEvent);
    }
  } else if (type === 'message' && action === 'submit') {
    const vibecraftEvent: VibecraftEvent = {
      id: generateEventId(sessionKey),
      timestamp: Date.now(),
      type: 'user_prompt_submit',
      sessionId: sessionKey,
      cwd,
      prompt: data?.message || data?.prompt || '',
    };
    await sendToVibecraft(vibecraftEvent);
  }
};

export default vibecraftHandler;
