# Rationale: Base Image and Service Choices

## 1. Base image: why `nginx:alpine` for the final stage

At runtime this application is a folder of static files. The build stage needs Node.js and npm to run `npm ci` and `npm run build`, but once `build/` exists nothing in it needs Node. All the final image has to do is serve files over HTTP, and nginx is built for that. The official nginx image documents exactly this pattern: copy static content into `/usr/share/nginx/html` and the image serves it [1].

I chose the `-alpine` variant over the default Debian-based `nginx` image for size. The official image documentation describes the Alpine variant as built on Alpine Linux, which is much smaller than most distribution base images (about 5 MB), and recommends it when the final image should be as small as possible [1]. The documented caveat is that Alpine uses musl libc instead of glibc, which can break software with deep libc dependencies [1]. That risk does not apply here. The only software in the final stage is nginx itself, which the image maintainers build and publish on Alpine, and my own content is plain HTML with no compiled code.

The multi-stage build is what makes this choice possible. Docker's documentation explains that a multi-stage build lets you copy only selected artifacts from one stage into the next, leaving everything else behind in the build stage [2]. In this Dockerfile, `COPY --from=build /app/build /usr/share/nginx/html` is the only line that carries anything forward. The Node.js runtime, npm, the npm cache and `node_modules` stay in the build stage and never ship.

My measurements (`docker images`, built on October 29, 2026):

| Image | Built from | Disk usage | Unique content |
|---|---|---|---|
| `demo:multi` | `Dockerfile` (multi-stage) | 93.6 MB | 26.3 MB |
| `demo:single` | `Dockerfile.single` (single-stage, `node:24`) | 1.65 GB | 413 MB |

The single-stage image is about 17.6× larger on disk (1650 MB ÷ 93.6 MB), and its unique content is about 15.7× larger (413 MB ÷ 26.3 MB). Most of the multi-stage image's 93.6 MB is the shared `nginx:alpine` base layers. The single-stage image, by contrast, carries the entire Node.js toolchain plus a globally installed `http-server`, none of which is needed to serve one HTML file. A smaller image pulls faster, costs less to store and transfer, and has fewer installed packages that could contain vulnerabilities.

## 2. Service split: why `cache` is a separate service

Docker's documentation states that it is best practice to separate areas of concern by using one service per container, and to avoid making one container responsible for multiple aspects of an application [3]. Serving web content and holding cached data are two different concerns with different lifecycles. With them split, I can restart, upgrade or replace Redis without rebuilding the web image, and the web image stays a small, single-purpose nginx container instead of needing a process manager to run two servers at once.

This is the Week 3 service-model trade-off made concrete. A container sits between IaaS and PaaS: I decide, piece by piece, what I build and manage myself and what I accept as a pre-built dependency. For `web`, I own the build: I wrote the Dockerfile and control exactly what ships. For `cache`, I made the opposite choice. I did not write or configure a cache; I composed in the public `redis:7-alpine` image as a ready-made component and only declared how it connects to my stack.

Compose makes that dependency explicit. The `cache` service has a healthcheck (`redis-cli ping`), and `web` uses `depends_on` with `condition: service_healthy`, so Compose waits for the cache to report healthy before starting `web`, rather than just waiting for its container to start [4].

One limitation is worth stating: `depends_on` controls startup order only. If `cache` is stopped while the stack is running, `web` keeps returning `200`, because this web service never calls Redis after it starts. In a real application that reads from the cache, the app itself would need to handle the cache going away, since Compose's startup ordering would not protect it at runtime.

## References

[1] Docker Hub, *nginx — Docker Official Image* (sections "Hosting some simple static content" and "Image Variants: nginx:\<version\>-alpine"). https://hub.docker.com/_/nginx

[2] Docker Docs, *Multi-stage builds*. https://docs.docker.com/build/building/multi-stage/

[3] Docker Docs, *Run multiple processes in a container*. https://docs.docker.com/engine/containers/multi-service_container/

[4] Docker Docs, *Control startup and shutdown order in Compose*. https://docs.docker.com/compose/how-tos/startup-order/