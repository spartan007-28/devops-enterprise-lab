FROM node:24.20.0-alpine AS dependencies

WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/frontend/package.json apps/frontend/package.json
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --ignore-scripts

FROM dependencies AS build
COPY apps/backend apps/backend
COPY eslint.config.mjs ./
RUN npm run build --workspace=@taskflow/backend

FROM node:24.20.0-alpine AS production-dependencies

WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/frontend/package.json apps/frontend/package.json
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --omit=dev --omit=peer --ignore-scripts

FROM production-dependencies AS migrations

COPY apps/backend apps/backend
RUN npm install --no-save --omit=dev --ignore-scripts prisma@6.19.3
RUN npm run prisma:generate --workspace=@taskflow/backend
RUN apk upgrade --no-cache
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
RUN chown -R node:node /workspace
USER node

FROM production-dependencies AS runtime-dependencies

RUN rm -rf node_modules/prisma node_modules/@prisma/config node_modules/@prisma/engines node_modules/deepmerge-ts node_modules/effect

FROM node:24.20.0-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production
RUN apk upgrade --no-cache
COPY --from=runtime-dependencies /workspace/node_modules ./node_modules
COPY --from=build /workspace/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /workspace/node_modules/@prisma/client ./node_modules/@prisma/client
COPY --from=build /workspace/apps/backend/dist ./apps/backend/dist
COPY --from=build /workspace/package.json ./package.json
COPY --from=build /workspace/apps/backend/package.json ./apps/backend/package.json
COPY --from=build /workspace/apps/backend/prisma ./apps/backend/prisma
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
RUN chown -R node:node /app
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=5 CMD node -e "fetch('http://127.0.0.1:3000/health/ready').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"
CMD ["node", "apps/backend/dist/main.js"]
