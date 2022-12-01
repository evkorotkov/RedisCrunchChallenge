FROM clojure:tools-deps-1.11.1.1224-alpine

ENV APP_ROOT=/clojure

RUN apk add --update --no-cache bash ruby redis musl-dev rlwrap

WORKDIR ${APP_ROOT}
COPY clojure .
