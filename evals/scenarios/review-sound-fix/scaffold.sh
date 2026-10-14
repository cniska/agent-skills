#!/usr/bin/env bash
set -euo pipefail

mkdir -p src tests

cat >package.json <<'EOF'
{
  "name": "pinboard",
  "private": true,
  "type": "module",
  "scripts": { "test": "bun test" }
}
EOF

cat >src/slug.ts <<'EOF'
const NON_ALPHANUMERIC = /[^a-z0-9]+/g;

export function slugify(title: string): string {
  return title.toLowerCase().replace(NON_ALPHANUMERIC, "-");
}
EOF

cat >tests/slug.test.ts <<'EOF'
import { expect, test } from "bun:test";
import { slugify } from "../src/slug";

test("joins words with a dash", () => {
  expect(slugify("Weekly Notes")).toBe("weekly-notes");
});

test("folds a run of punctuation into one dash", () => {
  expect(slugify("Q3 -- plans")).toBe("q3-plans");
});
EOF

git() { command git -c user.name=Owner -c user.email=owner@example.com "$@"; }
git init -q -b main
git add -A
git commit -q -m "feat: slugify titles"

cat >src/slug.ts <<'EOF'
const NON_ALPHANUMERIC = /[^a-z0-9]+/g;
const EDGE_DASHES = /^-+|-+$/g;

export function slugify(title: string): string {
  return title.toLowerCase().replace(NON_ALPHANUMERIC, "-").replace(EDGE_DASHES, "");
}
EOF

cat >>tests/slug.test.ts <<'EOF'

test("drops a dash left by punctuation at either end", () => {
  expect(slugify("Hello, World!")).toBe("hello-world");
  expect(slugify("(Draft) Plan")).toBe("draft-plan");
});
EOF
