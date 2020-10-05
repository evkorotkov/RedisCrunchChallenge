FROM ruby:2.6.6-alpine

ENV APP_ROOT=/app/ruby

RUN apk add --update --no-cache redis

WORKDIR ${APP_ROOT}
