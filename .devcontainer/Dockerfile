FROM erlang:27

ARG GLEAM_VERSION=v1.14.0

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo git zsh curl wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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

# Add Claude to PATH
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# Configure Claude Code to use API key from environment (skip login prompt)
RUN mkdir -p ~/.claude && \
    echo '{"apiKeySource": "env"}' > ~/.claude/settings.json && \
    echo '{"hasCompletedOnboarding": true}' > ~/.claude.json

# Set working directory for development
WORKDIR /workspace
