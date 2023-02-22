FROM rust:1.67.1-alpine3.16

ENV APP_ROOT=/rust

RUN apk add --update --no-cache bash ruby redis musl-dev

WORKDIR ${APP_ROOT}
COPY rust .

RUN cargo build --release
