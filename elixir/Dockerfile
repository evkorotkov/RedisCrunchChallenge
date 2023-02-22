FROM elixir:1.10.4-alpine

ENV APP_ROOT=/elixir

RUN apk add --update --no-cache redis ruby bash

WORKDIR ${APP_ROOT}
COPY elixir .

RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile
