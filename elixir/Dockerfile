FROM hexpm/elixir:1.14.3-erlang-25.2.3-alpine-3.16.3

ENV APP_ROOT=/elixir

RUN adduser -D app
RUN apk add --update --no-cache redis ruby bash

WORKDIR ${APP_ROOT}
RUN chown -R app:app $APP_ROOT
COPY --chown=app:app elixir .
USER app

RUN mix local.hex --force && mix local.rebar --force
