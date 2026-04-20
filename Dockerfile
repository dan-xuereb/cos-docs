# cos-docs/Dockerfile
#
# IMPORTANT: The site/ tree is built OUTSIDE this Dockerfile by the workflow
# (.github/workflows/build.yml) because build-all-api.sh requires sibling
# repos at /home/btc/github/* which live outside the docker build context.
# Moving the mkdocs build inside the Dockerfile would blow up the build
# context to 29 repos / several GB. See RESEARCH §4 Pitfall 2.
#
# The build pipeline (on runner) is:
#   1. scripts/build-all-api.sh --keep        # swap in pre-rendered API pages
#   2. mkdocs build --strict                  # produce ./site/
#   3. scripts/build-all-api.sh --restore     # restore sibling docs/api.md
#   4. emit site-manifest.json                # per-repo SHA manifest
#   5. docker build -t cos-docs:<sha> .       # <-- this file
#
# Multi-stage label (AS runtime) retained for workspace convention even
# though there is no separate build stage.

FROM nginx:1.27-alpine AS runtime
WORKDIR /usr/share/nginx/html

# Pre-built static site produced by the workflow (see header).
COPY site/ ./

# Per-repo-SHA manifest produced by the sibling-pull step in the workflow
# (Plan 04-04). For local smoke tests a stub file is fine.
COPY site-manifest.json ./

# nginx server config (see deploy/nginx.conf).
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf

# Make nginx dirs writable for non-root user (UID 101 = nginx user in the
# alpine image). Mirrors quant-dashboard/Dockerfile:38-40.
RUN mkdir -p /var/cache/nginx /var/run && \
    chown -R 101:101 /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && chown 101:101 /var/run/nginx.pid

USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health >/dev/null || exit 1
CMD ["nginx", "-g", "daemon off;"]
