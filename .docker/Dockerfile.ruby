FROM ruby:2.7.2-alpine

ENV APP_ROOT=/app/ruby

RUN apk add --update --no-cache redis build-base ruby-dev bash

WORKDIR ${APP_ROOT}
COPY ruby/Gemfile ruby/Gemfile.lock ./

RUN bundle update --bundler
RUN bundle install
