FROM erlang:27

ARG GLEAM_VERSION=v1.14.0

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo git zsh curl wget ca-certificates xz-utils gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install watchexec
ARG WATCHEXEC_VERSION=v2.4.1
RUN ARCH=$(uname -m | sed 's/x86_64/x86_64/' | sed 's/aarch64/aarch64/') \
    && curl -fsSL "https://github.com/watchexec/watchexec/releases/download/${WATCHEXEC_VERSION}/watchexec-${WATCHEXEC_VERSION#v}-${ARCH}-unknown-linux-musl.tar.xz" -o /tmp/watchexec.tar.xz \
    && tar -xf /tmp/watchexec.tar.xz -C /tmp \
    && mv /tmp/watchexec-${WATCHEXEC_VERSION#v}-${ARCH}-unknown-linux-musl/watchexec /usr/local/bin/ \
    && rm -rf /tmp/watchexec*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Gleam
RUN curl -fsSL -o gleam.tar.gz https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam-${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf gleam.tar.gz -C /usr/local/bin \
    && rm gleam.tar.gz \
    && chmod +x /usr/local/bin/gleam

# Create developer user
RUN useradd -m -s /bin/zsh developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to developer user
USER developer
WORKDIR /home/developer

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Configure zsh
RUN sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# Install Claude Code using official installer
RUN curl -fsSL https://claude.ai/install.sh | bash

# Make Claude available in non-interactive shells too (Zed runs postCreateCommand in /bin/sh)
ENV PATH="/home/developer/.local/bin:${PATH}"

# Configure Claude Code to use API key from environment (skip login prompt)
RUN mkdir -p ~/.claude && \
    echo '{"apiKeySource": "env"}' > ~/.claude/settings.json && \
    echo '{"hasCompletedOnboarding": true}' > ~/.claude.json

# Set working directory for development
WORKDIR /workspace
