FROM oven/bun:1-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN bun install --production

FROM oven/bun:1-alpine AS runtime
WORKDIR /app
RUN apk add --no-cache wget sqlite && \
    addgroup -S app && adduser -S -G app -h /app app && \
    mkdir -p /data && chown -R app:app /data
COPY --from=deps /app/node_modules ./node_modules
COPY package.json tsconfig.json ./
COPY src ./src
USER app
ENV NODE_ENV=production
EXPOSE 8080
CMD ["bun", "src/index.ts"]
