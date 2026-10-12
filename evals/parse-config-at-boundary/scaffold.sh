#!/usr/bin/env bash
set -euo pipefail

find_bun() {
  if bun --version >/dev/null 2>&1; then
    printf 'bun\n'
    return
  fi
  local dir candidate
  local -a dirs
  IFS=: read -ra dirs <<<"$PATH"
  for dir in "${dirs[@]}"; do
    [[ $dir == */mise/shims ]] || continue
    for candidate in "${dir%/shims}"/installs/bun/*/bin/bun; do
      if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return
      fi
    done
  done
  printf 'scaffold.sh: no bun on PATH or among mise installs; install bun with mise\n' >&2
  return 1
}

mkdir -p src

cat >package.json <<'EOF'
{
  "name": "relay",
  "private": true,
  "type": "module",
  "scripts": { "start": "bun src/server.ts" },
  "dependencies": { "zod": "^4.0.0" }
}
EOF

cat >src/config.ts <<'EOF'
export const config = {
  apiKey: process.env.RELAY_API_KEY ?? "",
  port: Number(process.env.RELAY_PORT ?? 8080),
  transport: (process.env.RELAY_TRANSPORT ?? "http") as "http" | "rpc",
  logLevel: process.env.RELAY_LOG_LEVEL ?? "info",
  upstreamUrl: process.env.RELAY_UPSTREAM_URL ?? "http://localhost:9000",
};
EOF

cat >src/server.ts <<'EOF'
import { config } from "./config";

const server = Bun.serve({
  port: config.port,
  async fetch(request) {
    const url = new URL(request.url);
    const upstream = new URL(url.pathname + url.search, config.upstreamUrl);
    if (config.logLevel === "debug") console.error(`${config.transport} ${request.method} ${upstream}`);
    return fetch(upstream, {
      method: request.method,
      headers: { authorization: `Bearer ${config.apiKey}` },
      body: request.body,
    });
  },
});

console.log(`relay listening on ${server.port}`);
EOF

bun="$(find_bun)"
"$bun" install --silent
