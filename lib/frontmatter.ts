import { CodedError } from "./coded-error";
import { readText } from "./read-file";

export type FrontmatterValue = string | readonly string[] | Readonly<Record<string, string>>;
export type Frontmatter = Readonly<Record<string, FrontmatterValue>>;

type Open =
  | { readonly kind: "block"; readonly key: string; readonly joiner: string; text: string }
  | { readonly kind: "map"; readonly map: Record<string, string> };

type Line = { readonly path: string; readonly line: string };

const FRONTMATTER = /^---\n([\s\S]*?)\n---/;
const KEY_VALUE = /^([\w-]+):\s*(.*)$/;
const CHILD_KEY_VALUE = /^\s+([\w-]+):\s*(.*)$/;
const INDENTED = /^\s+(.*)$/;
const INLINE_LIST = /^\[(.*)\]$/;
const INLINE_MAP = /^\{(.*)\}$/;
const PLAIN_ITEM = /^[^,:'"{}[\]]+$/;
const FOLDED = /^>-?$/;
const LITERAL = /^\|-?$/;

function unquote(value: string): string {
  if (value.startsWith("'") && value.endsWith("'")) return value.slice(1, -1).replace(/''/g, "'");
  if (value.startsWith('"') && value.endsWith('"')) return value.slice(1, -1);
  return value;
}

function plainItem(item: string, at: Line): string {
  const value = item.trim();
  if (!PLAIN_ITEM.test(value)) {
    throw new CodedError("frontmatter_unsupported", {
      ...at,
      detail: `unsupported inline item ${JSON.stringify(value)}`,
    });
  }
  return value;
}

function inlineMapEntry(pair: string, at: Line): [string, string] {
  const parts = pair.split(":");
  if (parts.length !== 2) {
    throw new CodedError("frontmatter_unsupported", {
      ...at,
      detail: `unsupported inline map entry ${JSON.stringify(pair.trim())}`,
    });
  }
  const [key = "", value = ""] = parts;
  return [plainItem(key, at), plainItem(value, at)];
}

function inlineValue(value: string, at: Line): FrontmatterValue {
  const list = value.match(INLINE_LIST);
  if (list) {
    const items = list[1] ?? "";
    return items.trim() ? items.split(",").map((item) => plainItem(item, at)) : [];
  }
  const map = value.match(INLINE_MAP);
  if (!map) return unquote(value);
  return Object.fromEntries((map[1] ?? "").split(",").map((pair) => inlineMapEntry(pair, at)));
}

function blockJoiner(value: string): string | null {
  if (FOLDED.test(value)) return " ";
  if (LITERAL.test(value)) return "\n";
  return null;
}

export function frontmatter(text: string, path: string): Frontmatter {
  const body = text.match(FRONTMATTER);
  if (!body) return {};
  const keys: Record<string, FrontmatterValue> = {};
  let open: Open | null = null;
  for (const line of (body[1] ?? "").split("\n")) {
    if (!line.trim()) continue;
    const indented = line.match(INDENTED);
    if (indented && open?.kind === "block") {
      const text = (indented[1] ?? "").trim();
      open.text = open.text ? `${open.text}${open.joiner}${text}` : text;
      keys[open.key] = open.text;
      continue;
    }
    const child = line.match(CHILD_KEY_VALUE);
    if (child && open?.kind === "map") {
      open.map[child[1] ?? ""] = unquote((child[2] ?? "").trim());
      continue;
    }
    const keyValue = line.match(KEY_VALUE);
    if (!keyValue)
      throw new CodedError("frontmatter_unsupported", { path, line, detail: "unsupported line" });
    const key = keyValue[1] ?? "";
    const value = (keyValue[2] ?? "").trim();
    const joiner = blockJoiner(value);
    open = null;
    if (joiner) {
      open = { kind: "block", key, joiner, text: "" };
      keys[key] = "";
      continue;
    }
    if (value === "") {
      const map: Record<string, string> = {};
      open = { kind: "map", map };
      keys[key] = map;
      continue;
    }
    keys[key] = inlineValue(value, { path, line });
  }
  return keys;
}

export function readFrontmatter(path: string): Frontmatter {
  return frontmatter(readText(path), path);
}
