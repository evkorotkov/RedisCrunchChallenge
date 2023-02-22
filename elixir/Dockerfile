FROM hexpm/elixir:1.14.3-erlang-25.2.3-alpine-3.17.0

ENV APP_ROOT=/elixir

RUN apk add --update --no-cache redis ruby bash

WORKDIR ${APP_ROOT}
COPY elixir .

RUN mix local.hex --force && mix local.rebar --force
