# Configuration Setup

## Overview

The application uses environment variables for configuration, with support for `.env` files in development.

## Files

- **`.env`** - Local development environment file (not committed to git)
- **`.env.example`** - Template file showing all required variables
- **`src/config.gleam`** - Configuration loading module

## Environment Variables

### Required Variables

```bash
# SMTP Configuration
SMTP_HOST=smtp.gmail.com        # SMTP server host
SMTP_PORT=587                    # SMTP server port
SMTP_USERNAME=your@email.com    # SMTP username
SMTP_PASSWORD=your_app_password  # SMTP password (use app password for Gmail)
SMTP_FROM_EMAIL=your@email.com  # From email address
SMTP_FROM_NAME=Luxwalker         # From name in emails
```

## Setup Instructions

### Development

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and fill in your credentials

3. Run the application:
   ```bash
   gleam run
   ```

The application will automatically load the `.env` file and use those values.

### Production

In production, set environment variables directly (no `.env` file needed):

```bash
export SMTP_HOST=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USERNAME=your@email.com
# ... etc
```

Or use your hosting provider's environment variable configuration.

## Gmail Setup

To use Gmail SMTP, you need an **App Password**:

1. Go to your Google Account settings
2. Security → 2-Step Verification (enable if not already)
3. Security → App passwords
4. Generate a new app password for "Mail"
5. Use this password in `SMTP_PASSWORD`

## How It Works

1. On startup, `config.load()` is called
2. It attempts to load `.env` file (silently fails if not found)
3. It reads environment variables using `envoy.get()`
4. Configuration is validated and stored in `AppConfig`
5. `AppConfig` is passed through `AppContext` to all actors

## Adding New Configuration

To add new configuration values:

1. Add the variable to `.env` and `.env.example`
2. Add getter in `src/config.gleam` → `load_*_config()`
3. Add field to appropriate config type
4. Use via `state.config` in actors

## Sources

- [dot_env package](https://hexdocs.pm/dot_env/)
- [envoy package](https://hexdocs.pm/envoy/)
- [dotenv_gleam](https://hexdocs.pm/dotenv_gleam/)
