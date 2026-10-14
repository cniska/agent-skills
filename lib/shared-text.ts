export type Text = { readonly shown: string; readonly text: string };

export type SharedRun = {
  readonly first: string;
  readonly second: string;
  readonly words: readonly string[];
};

type Words = { readonly shown: string; readonly words: readonly string[] };

const LINK_TARGET = /\]\([^)\n]*\)/g;
const WORD = /[a-z0-9]+(?:'[a-z0-9]+)*/g;

function words({ shown, text }: Text): Words {
  return { shown, words: text.replace(LINK_TARGET, "]").toLowerCase().match(WORD) ?? [] };
}

function windowAt(words: readonly string[], start: number, length: number): string {
  return words.slice(start, start + length).join(" ");
}

function holdersByWindow(texts: readonly Words[], length: number): Map<string, Set<string>> {
  const holders = new Map<string, Set<string>>();
  for (const { shown, words } of texts) {
    for (let start = 0; start + length <= words.length; start++) {
      const window = windowAt(words, start, length);
      holders.set(window, (holders.get(window) ?? new Set()).add(shown));
    }
  }
  return holders;
}

function runsFrom(text: Words, holders: Map<string, Set<string>>, length: number): SharedRun[] {
  const runs = new Map<string, SharedRun>();
  const open = new Map<string, number>();
  const last = text.words.length - length;
  for (let start = 0; start <= last + 1; start++) {
    const later = new Set(
      start > last
        ? []
        : [...(holders.get(windowAt(text.words, start, length)) ?? [])].filter((other) => other > text.shown),
    );
    for (const [other, from] of open) {
      if (later.has(other)) continue;
      const words = text.words.slice(from, start - 1 + length);
      runs.set(`${other}\n${words.join(" ")}`, { first: text.shown, second: other, words });
      open.delete(other);
    }
    for (const other of later) if (!open.has(other)) open.set(other, start);
  }
  return [...runs.values()];
}

export function sharedRuns(texts: readonly Text[], length: number): SharedRun[] {
  const all = texts.map(words);
  const holders = holdersByWindow(all, length);
  return all.flatMap((text) => runsFrom(text, holders, length));
}
