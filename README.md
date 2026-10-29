# Project 2: Containerize and Run Locally

This repository holds three artifacts:

| File / folder | What it is | Built in |
|---|---|---|
| `Dockerfile` | Multi-stage build: `node:24` build stage, `nginx:alpine` final stage | T02 |
| `compose.yaml` | Two services: `web` (built from the Dockerfile) and `cache` (`redis:7-alpine`) | T03 |
| `local-fn/` | AWS SAM function, invoked locally in a container (no AWS account) | T04 |

`Dockerfile.single` is the single-stage comparison build from T02. It is not part of the running stack. `RATIONALE.md` explains the base image and service choices.

## Prerequisites

A machine that has passed the T00 verification. Run every command in a Linux terminal (Ubuntu/WSL, or a GitHub Codespace), not PowerShell. You need:

- Docker Engine with the Compose plugin (`docker compose version` should work)
- AWS SAM CLI (`sam --version` should work)
- `git` and `curl`

No cloud account or credentials are needed.

## 1. Clone the repository

```bash
git clone https://github.com/Harsh6025/t02app.git
cd t02app
```

## 2. Build the image

```bash
docker build -t t02app:multi .
docker images t02app
```

Expected: one image, `t02app:multi`, under 100 MB.

## 3. Bring up both services with Compose

```bash
docker compose up -d --build
docker compose ps
```

Expected: two containers. `cache` shows `Up ... (healthy)`; `web` shows `Up` with port `0.0.0.0:8080->80/tcp`. `web` starts only after `cache` passes its healthcheck.

## 4. Confirm both services answer

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080
docker compose exec cache redis-cli ping
```

Expected:

```
200
PONG
```

## 5. Stop the stack

```bash
docker compose down
```

Expected: both containers and the Compose network are removed.

## 6. Invoke the function locally

```bash
cd local-fn
sam local invoke HelloWorldFunction
sam local invoke HelloWorldFunction -e events/event.json
cd ..
```

Expected: each invoke ends with

```
{"statusCode": 200, "body": "{\"message\":\"hello world\"}"}
```

The first run pulls the Lambda runtime image, which can take a few minutes. A `[ERROR] ... LAMBDA_RUNTIME Failed to get next invocation` line printed after the result is normal: the emulator has already shut down after the single invocation.

## Optional: reproduce the size comparison

```bash
docker build -f Dockerfile.single -t demo:single .
docker build -t demo:multi .
docker images | grep demo
docker rmi demo:single demo:multi
```

## Troubleshooting

- `port is already allocated`: another process is using port 8080. In `compose.yaml`, change the left side of `"8080:80"` to a free port (for example `"8081:80"`), and use that port in the `curl` command in step 4.
- Image size suddenly much larger: check that `.dockerignore` still lists `node_modules/`, `build/`, `local-fn/` and `.git/`.
