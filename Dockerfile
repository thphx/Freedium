FROM python:3.12.3

ENV DEBIAN_FRONTEND=noninteractive
ENV POETRY_NO_INTERACTION=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

# POETRY_VIRTUALENVS_IN_PROJECT=1 \
# POETRY_VIRTUALENVS_CREATE=true \
RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-pip,target=/root/.cache/pip pip install poetry && poetry config virtualenvs.create false

WORKDIR /app

RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-pip,target=/root/.cache/pip pip install wheel Cython

COPY ./rl_string_helper ./rl_string_helper
RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-pip,target=/root/.cache/pip pip3 install ./rl_string_helper

COPY ./database-lib ./database-lib
RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-pip,target=/root/.cache/pip pip3 install ./database-lib

COPY ./medium-parser ./medium-parser
RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-pip,target=/root/.cache/pip pip3 install ./medium-parser

# Railway fix:
# Keep original source code unchanged, but copy the static assets that are
# normally served by Caddy in the official deployment.
COPY ./caddy/static ./caddy/static

COPY ./web ./web
WORKDIR /app/web

RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-poetry,target=/tmp/poetry_cache poetry install --without dev --only main --no-ansi

RUN apt update && apt install -y curl nginx && rm -rf /var/lib/apt/lists/*

RUN useradd -m freedium

# Runtime launcher:
# - starts Freedium app on an internal port
# - starts nginx on Railway's public $PORT
# - serves /tailwindcssv3-freedium-hotfix.js and favicon assets from /app/caddy/static
RUN cat > /app/start.sh <<'SH'
#!/bin/sh
set -eu

PUBLIC_PORT="${PORT:-8080}"
APP_PORT="${APP_PORT:-7000}"

mkdir -p /tmp/nginx/client_body \
         /tmp/nginx/proxy \
         /tmp/nginx/fastcgi \
         /tmp/nginx/uwsgi \
         /tmp/nginx/scgi

cat > /tmp/nginx.conf <<EOF
worker_processes 1;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    access_log /dev/stdout;
    error_log /dev/stderr info;

    client_body_temp_path /tmp/nginx/client_body;
    proxy_temp_path /tmp/nginx/proxy;
    fastcgi_temp_path /tmp/nginx/fastcgi;
    uwsgi_temp_path /tmp/nginx/uwsgi;
    scgi_temp_path /tmp/nginx/scgi;

    server {
        listen ${PUBLIC_PORT};

        location = /tailwindcssv3-freedium-hotfix.js {
            root /app/caddy/static;
            default_type application/javascript;
            try_files /tailwindcssv3-freedium-hotfix.js =404;
        }

        location ~ ^/(apple-touch-icon\.png|favicon-32x32\.png|favicon-16x16\.png|site\.webmanifest|safari-pinned-tab\.svg|android-chrome-192x192\.png|android-chrome-512x512\.png)$ {
            root /app/caddy/static;
            try_files \$uri =404;
        }

        location / {
            proxy_pass http://127.0.0.1:${APP_PORT};
            proxy_http_version 1.1;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

cd /app/web

python3 -m server server --port "${APP_PORT}"
APP_PID="$!"

nginx -c /tmp/nginx.conf -g "daemon off;" &
NGINX_PID="$!"

wait -n "$APP_PID" "$NGINX_PID"
SH

RUN chmod +x /app/start.sh && chown -R freedium:freedium /app /tmp

USER freedium

CMD ["/app/start.sh"]
