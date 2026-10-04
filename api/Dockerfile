# syntax=docker/dockerfile:1.7

# ---- deps: production dependencies only ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
# npm ci when a lockfile is committed (recommended); falls back to npm install otherwise.
RUN if [ -f package-lock.json ]; then npm ci --omit=dev --ignore-scripts; \
    else npm install --omit=dev --ignore-scripts; fi \
 && npm cache clean --force

# ---- runtime: small, non-root ----
FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app
RUN apk add --no-cache tini
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
COPY --chown=node:node migrations ./migrations
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://127.0.0.1:3000/healthz || exit 1
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/server.js"]
