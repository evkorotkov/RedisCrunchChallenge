FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine3.16

ENV APP_ROOT=/dotnet

RUN apk add --update --no-cache bash redis ruby ruby-rdoc

WORKDIR ${APP_ROOT}
COPY dotnet/ ./

RUN dotnet build -c Release
