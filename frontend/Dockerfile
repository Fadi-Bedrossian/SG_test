# syntax=docker/dockerfile:1.7

# ---- build static assets ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
RUN npm run build

# ---- serve with unprivileged nginx ----
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
# API_UPSTREAM is substituted into the template at container start (envsubst, built into the image).
ENV API_UPSTREAM=api:3000
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
