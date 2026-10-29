# Stage 1: build. Has the full toolchain.
FROM node:24 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: run. Only the built output and a web server.
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
