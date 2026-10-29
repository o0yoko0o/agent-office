# The office in a container, watching the host's agents through read-only
# bind mounts (compose.yaml, compose.mounts.yaml from scripts/docker/mounts.sh).
# Build stage: npm ci + npm run build. Runtime: only dist/ and package.json,
# since the office has no runtime dependencies (node-pty is only for the
# control plane, which is off here). Node 24 for node:sqlite (opencode).
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build

FROM node:24-bookworm-slim
# Its own office home, so office.json never lands in the host's ~/.agentoffice.
# The host outbox is mounted read-only at $AGENT_OFFICE_HOME/outbox.
ENV NODE_ENV=production \
    AGENT_OFFICE_HOME=/var/lib/agentoffice \
    NO_COLOR=1
RUN install -d -o node -g node -m 700 /var/lib/agentoffice
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/dist ./dist
USER node
# --no-presence: the container can't see the host's agent processes.
EXPOSE 4747
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:4747/api/snapshot').then((r) => process.exit(r.ok ? 0 : 1), () => process.exit(1))"
CMD ["node", "dist/cli.js", "--host", "0.0.0.0", "--port", "4747", "--no-open", "--no-control", "--local-only", "--no-presence"]
