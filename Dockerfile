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

COPY ./web ./web
WORKDIR /app/web

RUN --mount=type=cache,id=s/1995182b-c4df-465f-afec-b3f918aafc05-poetry,target=/tmp/poetry_cache poetry install --without dev --only main --no-ansi

RUN apt install -y curl
RUN useradd -m freedium
USER freedium

CMD ["python3", "-m", "server", "server"]
