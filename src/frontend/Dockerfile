FROM node:16-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:16-alpine AS runtime

WORKDIR /app

RUN npm install -g http-server@14.1.1

RUN addgroup -S -g 10002 frontend && \
    adduser -S -D -H -u 10002 -G frontend -s /sbin/nologin frontend

COPY --from=builder --chown=frontend:frontend /app/dist /app/site

ENV BACKEND_URL=http://momo-store-backend:8081

EXPOSE 8888
USER 10002:10002
CMD ["sh", "-c", "exec http-server /app/site -p 8888 --proxy ${BACKEND_URL:-http://momo-store-backend:8081}"]

