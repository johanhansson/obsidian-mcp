FROM node:22-slim

WORKDIR /app

COPY package.json package-lock.json ./
COPY tsconfig.json tsup.config.ts ./
COPY src/ src/
COPY lib/ lib/

RUN npm ci
RUN npm run build

RUN npm ci --omit=dev

EXPOSE 8787

CMD ["node", "dist/main.js"]
