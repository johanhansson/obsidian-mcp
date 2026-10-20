# MCP server image. This fork builds TypeScript inside the image (deployed on
# Coolify straight from the repo), so it does not need a prebuilt dist/ from CI.
# Base pinned by digest (multi-arch index for node:22-slim); bump it deliberately.
ARG NODE_IMAGE=node:22-slim@sha256:43ac6c60b8f89723f746e8a92ce91abd5017e627ce1ddfe4238355d3a30b772c

# ---- Build stage: compile src/ + lib/livesync-commonlib into dist/ ----
FROM ${NODE_IMAGE} AS builder

WORKDIR /app

COPY package.json package-lock.json ./
# Full deps (tsup/typescript are devDependencies). No install scripts are
# needed to build — upstream CI also builds with --ignore-scripts.
RUN npm ci --ignore-scripts

COPY tsconfig.json tsup.config.ts ./
COPY src/ src/
COPY lib/ lib/
# Fail early with a clear message if the git submodule wasn't checked out.
RUN test -d lib/livesync-commonlib/src || (echo "lib/livesync-commonlib is empty: clone with --recurse-submodules" >&2 && exit 1)
RUN npm run build

# ---- Runtime stage: dist/ + production node_modules only ----
FROM ${NODE_IMAGE}

WORKDIR /app

COPY package.json package-lock.json ./
# Runtime deps only, and no dependency install scripts (none are needed at runtime).
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

COPY --from=builder /app/dist ./dist

# Run as the unprivileged `node` user (uid 1000) from the base image.
# /data is created here so a new named volume mounted at DATA_DIR=/data
# inherits node ownership; bind mounts and older volumes must be writable by uid 1000.
RUN mkdir -p /data && chown node:node /data
USER node

EXPOSE 8787

CMD ["node", "dist/main.js"]
