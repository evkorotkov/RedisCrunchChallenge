FROM golang:1.15

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

ADD . /app
RUN CGO_ENABLED=0 GOOS=linux go build -o main .
