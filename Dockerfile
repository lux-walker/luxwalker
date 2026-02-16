# Build stage
FROM erlang:27-alpine AS builder

ARG GLEAM_VERSION=v1.6.3

# Install build dependencies
RUN apk add --no-cache curl tar

# Install Gleam
RUN curl -fsSL -o gleam.tar.gz https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam-${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf gleam.tar.gz -C /usr/local/bin \
    && rm gleam.tar.gz \
    && chmod +x /usr/local/bin/gleam

WORKDIR /app

# Copy project files
COPY gleam.toml manifest.toml ./
COPY src ./src
COPY test ./test

# Build the project
RUN gleam export erlang-shipment

# Runtime stage
FROM erlang:27-alpine

WORKDIR /app

# Copy the built application from builder
COPY --from=builder /app/build/erlang-shipment ./

# Expose port (render.com uses PORT env var)
EXPOSE 8000

# Run the application
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
