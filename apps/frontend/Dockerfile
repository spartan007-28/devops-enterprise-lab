FROM node:24.20.0-alpine AS build

WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/frontend/package.json apps/frontend/package.json
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --ignore-scripts

COPY apps/frontend apps/frontend
COPY eslint.config.mjs .
RUN npm run build --workspace=@taskflow/frontend

FROM node:24.20.0-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production
RUN apk upgrade --no-cache
COPY --from=build /workspace/apps/frontend/dist ./dist
COPY apps/frontend/server.mjs ./server.mjs
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
USER node
EXPOSE 5173
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 CMD node -e "fetch('http://127.0.0.1:5173').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"
CMD ["node", "server.mjs"]
