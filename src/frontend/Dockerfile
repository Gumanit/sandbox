FROM node:16-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

FROM deps AS build
COPY . .

ARG VUE_APP_API_URL=""
ENV VUE_APP_API_URL=$VUE_APP_API_URL

RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine AS prod
COPY default.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=101:101 /app/dist /usr/share/nginx/html
EXPOSE 8080