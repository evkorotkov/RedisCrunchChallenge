FROM rust:1.78.0-alpine3.20

ENV APP_ROOT=/rust

RUN apk add --update --no-cache bash ruby redis musl-dev

WORKDIR ${APP_ROOT}
COPY rust .

RUN cargo build --release
