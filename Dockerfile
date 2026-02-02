# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache python3 make g++ tmux jq

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Stage 2: Runtime
FROM node:18-alpine

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache tmux jq

# Create non-root user
RUN addgroup -g 1001 -S vibecraft && \
    adduser -S -u 1001 -G vibecraft vibecraft

# Copy built application from builder
COPY --from=builder --chown=vibecraft:vibecraft /app/node_modules ./node_modules
COPY --from=builder --chown=vibecraft:vibecraft /app/dist ./dist
COPY --from=builder --chown=vibecraft:vibecraft /app/package.json ./

# Create data directory
RUN mkdir -p /home/vibecraft/.vibecraft/data && \
    chown -R vibecraft:vibecraft /home/vibecraft/.vibecraft

# Switch to non-root user
USER vibecraft

# Set environment variables
ENV VIBECRAFT_PORT=4003
ENV VIBECRAFT_CLIENT_PORT=4002
ENV VIBECRAFT_EVENTS_FILE=/home/vibecraft/.vibecraft/data/events.jsonl
ENV VIBECRAFT_SESSIONS_FILE=/home/vibecraft/.vibecraft/data/sessions.json
ENV VIBECRAFT_TILES_FILE=/home/vibecraft/.vibecraft/data/tiles.json
ENV NODE_ENV=production

# Expose ports
EXPOSE 4002 4003

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:4003/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server
CMD ["node", "dist/server/index.js"]
