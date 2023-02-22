FROM node:18.14-alpine3.16

ENV APP_ROOT=/node

RUN apk add --update --no-cache bash redis ruby

WORKDIR ${APP_ROOT}
COPY node/ ./

RUN npm install
