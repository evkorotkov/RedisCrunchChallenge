FROM golang:1.20.1-alpine3.16

ENV APP_ROOT=/golang

RUN apk add --update --no-cache bash redis ruby

WORKDIR ${APP_ROOT}

COPY golang/go.mod golang/go.sum ./
RUN go mod download

COPY golang .
RUN go build -o main .
