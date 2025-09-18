# Stage 1: Download dependencies
FROM golang:1.24 AS deps
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

# Stage 2: Build application
FROM golang:1.24 AS builder
WORKDIR /app
# Copy downloaded dependencies from deps stage
COPY --from=deps /go/pkg /go/pkg
COPY go.mod go.sum ./
COPY . .
# Build static binary with CGO disabled
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -a -ldflags '-extldflags "-static" -w -s' \
    -trimpath \
    -o main .

# Stage 3: Final runtime image
FROM mcr.microsoft.com/azurelinux/distroless/base:3.0
WORKDIR /app
# Copy only the binary from builder stage
COPY --from=builder /app/main ./main
# Run the application
CMD ["./main"]