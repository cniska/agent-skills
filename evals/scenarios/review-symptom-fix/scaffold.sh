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

cat >src/loading.ts <<'EOF'
export const MIN_LOADING_MS = 400;

export async function atLeast<T>(work: Promise<T>): Promise<T> {
  const [value] = await Promise.all([work, Bun.sleep(MIN_LOADING_MS)]);
  return value;
}
EOF

cat >src/api.ts <<'EOF'
export type Api = { readonly get: (path: string) => Promise<unknown> };
EOF

cat >src/profile.ts <<'EOF'
import type { Api } from "./api";
import { atLeast } from "./loading";

export async function loadProfile(api: Api, id: string): Promise<unknown> {
  return atLeast(api.get(`/profiles/${id}`));
}
EOF

cat >src/search.ts <<'EOF'
import type { Api } from "./api";
import { atLeast } from "./loading";

export async function search(api: Api, query: string): Promise<unknown> {
  return atLeast(api.get(`/search?q=${encodeURIComponent(query)}`));
}
EOF

cat >src/feed.ts <<'EOF'
import type { Api } from "./api";
import { atLeast } from "./loading";

export async function loadFeed(api: Api, page: number): Promise<unknown> {
  return atLeast(api.get(`/feed?page=${page}`));
}
EOF

cat >tests/profile.test.ts <<'EOF'
import { expect, test } from "bun:test";
import { loadProfile } from "../src/profile";

const api = { get: async (path: string) => ({ path }) };
const ids = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n"];

test("loads every profile by id", async () => {
  for (const id of ids) {
    expect(await loadProfile(api, id)).toEqual({ path: `/profiles/${id}` });
  }
});
EOF

cat >tests/search.test.ts <<'EOF'
import { expect, test } from "bun:test";
import { search } from "../src/search";

const api = { get: async (path: string) => ({ path }) };

test("encodes the query", async () => {
  expect(await search(api, "a b")).toEqual({ path: "/search?q=a%20b" });
});

test("passes an empty query through", async () => {
  expect(await search(api, "")).toEqual({ path: "/search?q=" });
});
EOF

cat >tests/feed.test.ts <<'EOF'
import { expect, test } from "bun:test";
import { loadFeed } from "../src/feed";

const api = { get: async (path: string) => ({ path }) };

test(
  "loads every page of a long feed",
  async () => {
    for (let page = 1; page <= 13; page += 1) {
      expect(await loadFeed(api, page)).toEqual({ path: `/feed?page=${page}` });
    }
  },
  { timeout: 8000 },
);
EOF

git() { command git -c user.name=Owner -c user.email=owner@example.com "$@"; }
git init -q -b main
git add -A
git commit -q -m "feat: load profiles, search and feed"

cat >tests/profile.test.ts <<'EOF'
import { expect, mock, test } from "bun:test";

mock.module("../src/loading", () => ({
  MIN_LOADING_MS: 0,
  atLeast: <T>(work: Promise<T>) => work,
}));

const { loadProfile } = await import("../src/profile");

const api = { get: async (path: string) => ({ path }) };
const ids = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n"];

test("loads every profile by id", async () => {
  for (const id of ids) {
    expect(await loadProfile(api, id)).toEqual({ path: `/profiles/${id}` });
  }
});
EOF
