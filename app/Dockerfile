# Build stage
FROM erlang:27-alpine AS builder

ARG GLEAM_VERSION=v1.14.0

# Install build dependencies (includes Node.js for client build)
RUN apk add --no-cache curl tar nodejs npm

# Install Gleam
RUN curl -fsSL -o gleam.tar.gz https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam-${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf gleam.tar.gz -C /usr/local/bin \
    && rm gleam.tar.gz \
    && chmod +x /usr/local/bin/gleam

WORKDIR /build

# Copy all three packages
COPY shared ./shared
COPY client ./client
COPY server ./server

# Build the client (JavaScript target)
WORKDIR /build/client
RUN gleam run -m lustre/dev build --minify --outdir=../server/priv/static

# Build the server (Erlang target)
WORKDIR /build/server
RUN gleam export erlang-shipment

# Runtime stage
FROM erlang:27-alpine

WORKDIR /app

# Copy the built server application
COPY --from=builder /build/server/build/erlang-shipment ./

# Expose port (render.com sets PORT env var, default 8080)
EXPOSE 8080

# Run the application
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
