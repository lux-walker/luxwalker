#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <container_id>"
  exit 1
fi

docker exec -it -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" "$1" zsh
