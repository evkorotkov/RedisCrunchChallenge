FROM ruby:3.2.1-alpine3.16

ENV CONSOLE_LEVEL=warn
ENV APP_ROOT=/ruby_async

RUN apk add --update --no-cache redis build-base openssl-dev bash

WORKDIR ${APP_ROOT}
COPY ruby_async/ ./

RUN bundle update --bundler
RUN bundle install
