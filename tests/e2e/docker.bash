#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="shellcheck-legibility:e2e"

main() {
  docker build --tag "$IMAGE_NAME" --file "$ROOT_DIR/tests/e2e/Dockerfile" "$ROOT_DIR"
  docker run --rm "$IMAGE_NAME"
}

main "$@"
