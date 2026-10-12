const PLAIN_ITEM = /^[^,:'"{}[\]]+$/;

const unquote = (v) => {
  if (v.startsWith("'") && v.endsWith("'")) return v.slice(1, -1).replace(/''/g, "'");
  if (v.startsWith('"') && v.endsWith('"')) return v.slice(1, -1);
  return v;
};

function plainItem(item, line) {
  const value = item.trim();
  if (!PLAIN_ITEM.test(value)) throw new Error(`frontmatter: unsupported inline item ${JSON.stringify(value)} in: ${line}`);
  return value;
}

function inlineValue(value, line) {
  const list = value.match(/^\[(.*)\]$/);
  if (list) return list[1].trim() ? list[1].split(",").map((x) => plainItem(x, line)) : [];
  const map = value.match(/^\{(.*)\}$/);
  if (!map) return unquote(value);
  return Object.fromEntries(
    map[1].split(",").map((pair) => {
      const parts = pair.split(":");
      if (parts.length !== 2) throw new Error(`frontmatter: unsupported inline map entry ${JSON.stringify(pair.trim())} in: ${line}`);
      return parts.map((x) => plainItem(x, line));
    }),
  );
}

function blockStyle(value) {
  if (/^>-?$/.test(value)) return " ";
  if (/^\|-?$/.test(value)) return "\n";
  return null;
}

export function frontmatter(text) {
  const body = text.match(/^---\n([\s\S]*?)\n---/);
  if (!body) return {};
  const keys = {};
  let open = null;
  for (const line of body[1].split("\n")) {
    if (!line.trim()) continue;
    const indented = line.match(/^\s+(.*)$/);
    if (indented && open?.joiner) {
      keys[open.key] = keys[open.key] ? `${keys[open.key]}${open.joiner}${indented[1].trim()}` : indented[1].trim();
      continue;
    }
    const child = line.match(/^\s+([\w-]+):\s*(.*)$/);
    if (child && open?.joiner === null) {
      keys[open.key][child[1]] = unquote(child[2].trim());
      continue;
    }
    const kv = line.match(/^([\w-]+):\s*(.*)$/);
    if (!kv) throw new Error(`frontmatter: unsupported line: ${line}`);
    const [, key, raw] = kv;
    const value = raw.trim();
    const joiner = blockStyle(value);
    open = null;
    if (joiner) {
      keys[key] = "";
      open = { key, joiner };
      continue;
    }
    if (value === "") {
      keys[key] = {};
      open = { key, joiner: null };
      continue;
    }
    keys[key] = inlineValue(value, line);
  }
  return keys;
}
