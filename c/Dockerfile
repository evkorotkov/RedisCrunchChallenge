FROM alpine:3.16

ENV APP_ROOT=/c

RUN apk add --update --no-cache bash build-base ruby redis hiredis-dev cjson-dev openssl-dev parallel

WORKDIR ${APP_ROOT}
COPY c .
RUN make
