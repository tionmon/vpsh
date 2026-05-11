# ---- 编译阶段 ----
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache gcc musl-dev sqlite-dev

WORKDIR /src
COPY . .
RUN go mod tidy && CGO_ENABLED=1 go build -ldflags="-s -w" -trimpath -o /shortlink .

# ---- 运行阶段 ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates sqlite-libs

COPY --from=builder /shortlink /usr/local/bin/shortlink

RUN mkdir -p /app/data

ENV DATABASE_PATH=/app/data/shortlinks.db

EXPOSE 5000

CMD ["shortlink"]
