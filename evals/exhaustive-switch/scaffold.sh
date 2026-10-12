#!/usr/bin/env bash
set -euo pipefail

mkdir -p src

cat >package.json <<'EOF'
{
  "name": "toolrun",
  "private": true,
  "type": "module",
  "scripts": { "start": "bun src/main.ts" }
}
EOF

cat >src/tool-call.ts <<'EOF'
export type ToolCall =
  | { readonly kind: "read"; readonly path: string }
  | { readonly kind: "write"; readonly path: string; readonly bytes: number }
  | { readonly kind: "delete"; readonly paths: readonly string[] };
EOF

cat >src/log.ts <<'EOF'
import type { ToolCall } from "./tool-call";

export function logCall(call: ToolCall): void {
  console.error(JSON.stringify(call));
}
EOF

cat >src/main.ts <<'EOF'
import { logCall } from "./log";
import type { ToolCall } from "./tool-call";

const calls: readonly ToolCall[] = [
  { kind: "read", path: "src/a.ts" },
  { kind: "write", path: "src/a.ts", bytes: 120 },
  { kind: "delete", paths: ["tmp/1", "tmp/2", "tmp/3"] },
];

for (const call of calls) logCall(call);
EOF
