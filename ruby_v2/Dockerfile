FROM ruby:3.2.1-alpine3.16

ENV APP_ROOT=/ruby_v2

RUN apk add --update --no-cache redis build-base ruby-dev openssl-dev bash

WORKDIR ${APP_ROOT}
COPY ruby_v2/ ./

RUN bundle update --bundler
RUN bundle install
