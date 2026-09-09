#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f .local/backend.env ]]; then
  echo 'Missing .local/backend.env; use Docker Compose or configure DB_URL, DB_USERNAME and DB_PASSWORD as described in README.' >&2
  exit 1
fi
source .local/backend.env
cd backend
exec ./mvnw spring-boot:run
