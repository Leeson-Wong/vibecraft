# Vibecraft 通用 Agent 可视化平台架构方案

> **目标**: 将 Vibecraft 从 Claude Code 专属工具升级为支持多 Agent 框架的统一可视化平台

---

## 问题分析

### 当前限制
- **仅支持 Claude Code**: 依赖 Claude Code 官方 Hook 系统
- **数据存储简陋**: JSONL 文件而非正式数据库
- **无扩展性**: 难以接入其他 Agent 框架

### 用户需求
- 统一监控多个 Agent (Claude, CrewAI, OpenAI, LangGraph 等)
- Agent 间协作可视化
- 历史数据查询和回放
- 生产级稳定性

---

## 核心架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                    统一 Agent 交互架构                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │  Claude    │  │  CrewAI    │  │  LangGraph │  │  AutoGPT   │   │
│  │    Code    │  │            │  │            │  │            │   │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘   │
│        │                │                │                │         │
│        ▼                ▼                ▼                ▹         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Universal Agent SDK (统一抽象层)                │   │
│  │  ┌──────────────────────────────────────────────────────┐  │   │
│  │  │  interface AgentEvent {                              │  │   │
│  │  │    type: EventType      // tool_use, message, etc   │  │   │
│  │  │    agentType: AgentType // claude, crewai, etc       │  │   │
│  │  │    agentId: string      // agent instance ID         │  │   │
│  │  │    sessionId: string    // user session              │  │   │
│  │  │    timestamp: number    // unix ms                   │  │   │
│  │  │    data: unknown        // agent-specific payload    │  │   │
│  │  │  }                                                  │  │   │
│  │  └──────────────────────────────────────────────────────┘  │   │
│  │                                                              │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │   │
│  │  │Claude       │ │CrewAI       │ │LangGraph    │           │   │
│  │  │Adapter      │ │Adapter      │ │Adapter      │           │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                           │                                         │
│                           ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Event Bus (消息总线)                      │   │
│  │  - Redis Pub/Sub (实时事件)                                  │   │
│  │  - 持久化队列                                                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                           │                                         │
│                           ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Vibecraft Server (统一消费端)                   │   │
│  │  ┌──────────────────────────────────────────────────────┐  │   │
│  │  │  Event Storage (PostgreSQL + TimescaleDB)            │  │   │
│  │  └──────────────────────────────────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────────────────┐  │   │
│  │  │  Event Router & Normalizer                           │  │   │
│  │  └──────────────────────────────────────────────────────┘  │   │
│  │  ┌──────────────────────────────────────────────────────┐  │   │
│  │  │  WebSocket Server                                     │  │   │
│  │  └──────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                           │                                         │
│                           ▼                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Browser Client (前端)                      │   │
│  │  - Three.js 3D 可视化                                        │   │
│  │  - 统一事件格式处理                                          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 技术选型

### 数据库替换方案

| 数据库 | 优势 | 劣势 | 推荐度 |
|--------|------|------|--------|
| **PostgreSQL + TimescaleDB** | 成熟、JSON 列支持、时序扩展 | 写入性能一般 | ⭐⭐⭐⭐⭐ |
| ClickHouse | 时序最优、压缩率高 | 需单独部署 | ⭐⭐⭐⭐ |
| MongoDB | 文档型、Change Streams | 资源占用高 | ⭐⭐⭐ |
| SQLite (当前 JSONL) | 零依赖 | 查询弱、无并发 | ⭐ |

**最终选择**: **PostgreSQL + TimescaleDB**
- 成熟稳定，Docker 一键部署
- JSONB 列支持 Agent 特定数据
- TimescaleDB 优化时序查询
- 生态完善

### 消息总线

| 方案 | 优势 | 劣势 |
|------|------|------|
| **Redis Pub/Sub** | 简单、低延迟 | 无持久化 |
| NATS | 持久化、JetStream | 额外复杂度 |
| RabbitMQ | 功能完善 | 过重 |

**最终选择**: **Redis Pub/Sub**
- 简单够用
- 大多数项目已有 Redis
- 配合 PostgreSQL 做持久化

---

## Agent 接入方案

### 核心设计原则

**✅ 非侵入式**: 不修改 Agent 框架源码
**✅ 渐进式**: 从简单包装到深度集成
**✅ 降级兼容**: 有限接入优于无法接入

### 接入模式对比

```
┌────────────────────────────────────────────────────────┐
│              接入难度对比                              │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Agent          方案              侵入性    可行性     │
│  ───────────────────────────────────────────────────  │
│  Claude Code    Official Hook      ❌ 无     ✅ 完美   │
│  LangGraph      Callback Handler  ⚠️ 1行     ✅ 良好   │
│  CrewAI         Process Wrap      ⚠️ 启动   ✅ 可行   │
│  AutoGPT        Output Parse      ⚠️ 管道   ✅ 可行   │
│  OpenAI         Log Parse         ❌ 无     ⚠️ 有限   │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### 模式 1: 官方 Hook (零侵入)

**适用**: Claude Code

```typescript
// 直接使用 Claude Code 的 hook 系统
// 1. 复制 hook 脚本
// 2. 修改 ~/.claude/settings.json
// 3. 完成

const settings = {
  hooks: {
    PreToolUse: '~/.vibecraft/hooks/event-bridge.sh',
    PostToolUse: '~/.vibecraft/hooks/event-bridge.sh',
    Stop: '~/.vibecraft/hooks/event-bridge.sh',
    SessionStart: '~/.vibecraft/hooks/event-bridge.sh',
    // ...
  }
}
```

### 模式 2: 环境变量注入 (1 行代码)

**适用**: LangGraph / LangChain

```python
# 用户代码中只需添加 1 行
from langchain.callbacks import get_callback_manager
from vibecraft.callbacks import VibecraftCallbackHandler

cm = get_callback_manager()
cm.add_handler(VibecraftCallbackHandler())  # ← 仅此 1 行

# 或者通过环境变量
export LANGCHAIN_CALLBACKS=vibecraft.callbacks.VibecraftCallbackHandler
```

**SDK 实现**:

```python
# ~/.vibecraft/langchain_handler.py
from langchain.callbacks.base import BaseCallbackHandler
import json
import sys

class VibecraftCallbackHandler(BaseCallbackHandler):
    def on_tool_start(self, serialized, input_str, **kwargs):
        event = {
            'type': 'pre_tool_use',
            'tool': serialized['name'],
            'input': input_str,
            'timestamp': datetime.now().isoformat()
        }
        sys.stdout.write(json.dumps(event) + '\n')
        sys.stdout.flush()

    def on_tool_end(self, output, **kwargs):
        event = {
            'type': 'post_tool_use',
            'output': output,
            'success': True
        }
        sys.stdout.write(json.dumps(event) + '\n')
        sys.stdout.flush()
```

### 模式 3: 进程包装 (改启动命令)

**适用**: CrewAI, AutoGPT

```bash
# 不再直接运行:
python my_crew.py

# 而是使用包装器:
vibecraft-run crewai my_crew.py

# 或设置别名:
alias crew-run='vibecraft-run crewai'
crew-run my_crew.py
```

**SDK 实现**:

```python
# ~/.vibecraft/instrumentors/crewai_patch.py
import sys
import json
from datetime import datetime

_original_crew_execute = None

def _instrumented_execute(self, *args, **kwargs):
    event = {
        'type': 'crew_start',
        'crew_name': self.name,
        'timestamp': datetime.now().isoformat()
    }
    sys.stdout.write(json.dumps(event) + '\n')

    try:
        result = _original_crew_execute(self, *args, **kwargs)
        event = {'type': 'crew_complete', 'result': str(result)}
        sys.stdout.write(json.dumps(event) + '\n')
        return result
    except Exception as e:
        event = {'type': 'crew_error', 'error': str(e)}
        sys.stdout.write(json.dumps(event) + '\n')
        raise

def patch_crewai():
    from crewai import Crew
    global _original_crew_execute
    _original_crew_execute = Crew.execute
    Crew.execute = _instrumented_execute
```

**包装脚本**:

```bash
#!/usr/bin/env python3
# ~/.vibecraft/bin/crewai-wrapper

import sys
import os

# 在导入 crewai 之前注入
sys.path.insert(0, os.path.expanduser('~/.vibecraft/instrumentors'))
from vibecraft.instrumentors.crewai_patch import patch_crewai
patch_crewai()

# 执行用户的脚本
exec(open(sys.argv[1]).read())
```

### 模式 4: 输出解析 (管道)

**适用**: AutoGPT, 闭源工具

```bash
# AutoGPT 输出详细日志
autogpt 2>&1 | vibecraft-parse autogpt

# 解析器提取事件
# [2024-01-01] Command: execute_shell "ls -la"
# → {type: 'pre_tool_use', tool: 'execute_shell', input: 'ls -la'}
```

**解析器**:

```python
#!/usr/bin/env python3
import sys
import json
import re

for line in sys.stdin:
    if 'Command:' in line:
        match = re.search(r'Command: (\w+)\s+', line)
        if match:
            event = {
                'type': 'pre_tool_use',
                'tool': match.group(1),
                'timestamp': datetime.now().isoformat()
            }
            print(json.dumps(event), flush=True)
```

### 模式 5: 日志解析 (有限支持)

**适用**: OpenAI (闭源)

```bash
# 启用 OpenAI 详细日志
export OPENAI_LOG=debug
export OPENAI_LOG_FILE=~/.vibecraft/logs/openai.log

# Vibecraft 监控日志文件
vibecraft watch-logs openai
```

**注意**: 由于 OpenAI API 闭源，此方式提供有限支持。建议使用开源替代方案。

---

## 数据库 Schema

### PostgreSQL + TimescaleDB

```sql
-- 01_events.sql

-- 启用 TimescaleDB 扩展
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 事件表（时序优化）
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- 通用字段
  event_type VARCHAR(50) NOT NULL,
  agent_type VARCHAR(50) NOT NULL,
  agent_id VARCHAR(255) NOT NULL,
  session_id VARCHAR(255) NOT NULL,

  -- 时间
  timestamp BIGINT NOT NULL,
  received_at BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW() * 1000),

  -- Agent 特定数据（JSON）
  data JSONB NOT NULL,

  -- 元数据
  parent_id UUID,
  correlation_id VARCHAR(255),
  tags TEXT[],

  -- 索引
  INDEX idx_agent_timestamp (agent_id, timestamp),
  INDEX idx_session_type (session_id, event_type),
  INDEX idx_correlation (correlation_id)
);

-- 转换为 TimescaleDB hypertable（自动分区）
SELECT create_hypertable('events', 'timestamp',
  chunk_time_interval => INTERVAL '1 day'
);

-- 连续聚合（加速查询）
CREATE MATERIALIZED VIEW events_hourly_stats
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', to_timestamp(timestamp / 1000)) AS bucket,
  agent_type,
  event_type,
  COUNT(*) AS event_count,
  COUNT(DISTINCT agent_id) AS active_agents
FROM events
GROUP BY bucket, agent_type, event_type;

-- 会话表
CREATE TABLE IF NOT EXISTS sessions (
  id VARCHAR(255) PRIMARY KEY,
  agent_type VARCHAR(50) NOT NULL,
  agent_id VARCHAR(255) NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  status VARCHAR(20) NOT NULL DEFAULT 'running',
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL,
  ended_at BIGINT,
  INDEX idx_agent_status (agent_id, status)
);

-- 子任务表
CREATE TABLE IF NOT EXISTS subtasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_event_id UUID NOT NULL REFERENCES events(id),
  agent_id VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'running',
  started_at BIGINT NOT NULL,
  completed_at BIGINT,
  result JSONB,
  INDEX idx_parent (parent_event_id)
);
```

---

## 统一事件格式

```typescript
// packages/universal-agent-sdk/src/types.ts

export enum AgentType {
  CLAUDE_CODE = 'claude-code',
  CREWAI = 'crewai',
  OPENAI_AGENTS = 'openai-agents',
  AUTO_GPT = 'auto-gpt',
  LANGGRAPH = 'langgraph',
}

export enum EventType {
  SESSION_START = 'session_start',
  SESSION_END = 'session_end',
  PRE_TOOL_USE = 'pre_tool_use',
  POST_TOOL_USE = 'post_tool_use',
  USER_MESSAGE = 'user_message',
  ASSISTANT_MESSAGE = 'assistant_message',
  SUBTASK_START = 'subtask_start',
  SUBTASK_END = 'subtask_end',
  ERROR = 'error',
}

export interface AgentEvent {
  // 通用字段
  id: string                    // UUID
  type: EventType
  agentType: AgentType
  agentId: string
  sessionId: string
  timestamp: number             // Unix ms
  receivedAt: number

  // 扩展字段
  data: Record<string, unknown>

  // 可选元数据
  metadata?: {
    parentId?: string
    correlationId?: string
    tags?: string[]
  }
}

export interface AgentAdapter {
  agentType: AgentType
  injectionMode: InjectionMode

  initialize(config: Record<string, unknown>): Promise<void>
  start(): Promise<void>
  stop(): Promise<void>
  onEvent(callback: (event: AgentEvent) => void): void
  normalizeEvent(rawEvent: unknown): AgentEvent
}
```

---

## CLI 使用流程

```bash
# 安装
npm install -g @vibecraft/universal-sdk

# 初始化
vibecraft init

# 选择要集成的 Agent
? Which agent framework are you using?
  ❯ Claude Code
    LangGraph
    CrewAI
    AutoGPT
    OpenAI Agents (limited)

# Claude Code (零修改)
vibecraft hook claude
# ✅ Configured ~/.claude/settings.json

# LangGraph (1 行代码)
vibecraft hook langgraph
# ✅ Installed callback handler
# ℹ️  Add to your code:
#     from vibecraft import VibecraftCallback
#     callbacks = [VibecraftCallback()]

# CrewAI (改启动)
vibecraft hook crewai
# ✅ Installed instrumentor
# ℹ️  Run with: vibecraft-run crewai my_crew.py

# AutoGPT (管道)
vibecraft hook autogpt
# ✅ Installed parser
# ℹ️  Run with: autogpt | vibecraft-parse autogpt

# 启动 Vibecraft Server
vibecraft start
# ✅ PostgreSQL connected
# ✅ Redis connected
# ✅ WebSocket server listening on :4003
# 🌐 Open http://localhost:4003

# 查看可视化
open http://localhost:4003
```

---

## 项目结构

```
packages/
├── universal-agent-sdk/
│   ├── src/
│   │   ├── types.ts                    # 核心类型定义
│   │   ├── adapters/
│   │   │   ├── claude.ts               # Official Hook
│   │   │   ├── langgraph.ts            # Callback Handler
│   │   │   ├── crewai.ts               # Monkey Patch
│   │   │   ├── autogpt.ts              # Output Parser
│   │   │   └── openai.ts               # Log Parser
│   │   ├── bridge/
│   │   │   ├── EventBridge.ts          # 统一事件格式
│   │   │   └── RedisPublisher.ts       # 发布到 Redis
│   │   └── parsers/
│   │       ├── autogpt.py              # 日志解析器
│   │       └── openai.py
│   ├── bin/
│   │   ├── cli.ts                      # vibecraft 命令
│   │   └── wrappers/
│   │       ├── crewai-wrapper.sh
│   │       └── autogpt-wrapper.sh
│   └── package.json
│
├── python-instrumentors/
│   ├── langchain_handler.py            # LangGraph callback
│   ├── crewai_patch.py                 # CrewAI monkey patch
│   ├── autogpt_parser.py               # AutoGPT 解析器
│   └── setup.py                        # pip install vibecraft-agent
│
└── vibecraft-server/
    ├── migrations/
    │   ├── 001_create_events.sql
    │   └── 002_create_sessions.sql
    ├── src/
    │   ├── repository/
    │   │   ├── EventRepository.ts
    │   │   └── PostgresEventRepository.ts
    │   ├── EventBusSubscriber.ts       # Redis 订阅
    │   └── index.ts
    └── package.json

deving/
└── universal-agent-architecture.md     # 本文档
```

---

## 实施路线图

### Phase 1: 基础设施 (2 周)
- [ ] 部署 PostgreSQL + TimescaleDB (Docker Compose)
- [ ] 部署 Redis
- [ ] 创建 Schema 和迁移脚本
- [ ] 实现 AgentEvent SDK 核心
- [ ] 实现 Redis Event Publisher

### Phase 2: Claude Code 适配 (1 周)
- [ ] ClaudeCodeAdapter 实现
- [ ] Server 重构（接收统一事件）
- [ ] 前端适配（统一事件处理）
- [ ] 测试现有功能正常

### Phase 3: 其他 Agent 集成 (4 周)
- [ ] LangGraph Adapter
- [ ] CrewAI Adapter (进程包装)
- [ ] AutoGPT Adapter (输出解析)
- [ ] OpenAI Adapter (日志解析，有限)
- [ ] 测试各 Agent 集成

### Phase 4: 可视化优化 (2 周)
- [ ] 不同 Agent 的 Zone 样式差异
- [ ] 多 Agent 协作的可视化
- [ ] Agent 间通信关系图
- [ ] 历史回放功能

### Phase 5: 生产化 (2 周)
- [ ] 监控和告警
- [ ] 性能优化
- [ ] 文档完善
- [ ] 发布

**总计**: 11 周

---

## Docker 部署

```yaml
# docker-compose.yml

version: '3.8'

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    environment:
      POSTGRES_DB: vibecraft
      POSTGRES_USER: vibecraft
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  vibecraft-server:
    build: .
    environment:
      DATABASE_URL: postgresql://vibecraft:password@postgres:5432/vibecraft
      REDIS_URL: redis://redis:6379
    ports:
      - "4003:4003"
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
```

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止
docker-compose down
```

---

## 迁移策略（从 JSONL）

```bash
# 1. 导出现有 JSONL 数据
npm run export:jsonl -- --output events.jsonl

# 2. 导入到 PostgreSQL
npm run import:postgres -- --input events.jsonl

# 3. 验证数据
npm run verify:migration

# 4. 切换配置
export VIBECRAFT_STORAGE_BACKEND=postgres

# 5. 重启服务
vibecraft restart
```

---

## 关键优势

✅ **非侵入式**: 无需修改 Agent 框架源码
✅ **统一抽象**: 一个 SDK 支持所有 Agent
✅ **生产级数据库**: PostgreSQL + TimescaleDB
✅ **实时性能**: Redis Pub/Sub 低延迟
✅ **渐进式迁移**: 从 JSONL 平滑过渡
✅ **易于扩展**: 新 Agent 只需实现 Adapter 接口

---

## 风险和限制

⚠️ **闭源 Agent 支持**: OpenAI 等闭源方案只能有限支持
⚠️ **Agent 生态系统**: 部分 Agent 框架可能缺乏 hook 点
⚠️ **性能**: 大规模并发需要优化（当前 MVP 阶段）
⚠️ **学习曲线**: 用户需要了解不同 Agent 的集成方式

---

## 下一步

1. **技术验证**: 实现 Claude Code Adapter + PostgreSQL 替换
2. **社区反馈**: 征求不同 Agent 框架用户的集成需求
3. **迭代优化**: 根据实际使用优化接入体验

---

**文档版本**: v1.0
**最后更新**: 2025-02-05
**状态**: 设计阶段，待实施
