type Facts = {
  readonly usage: { readonly usage: string; readonly problem: string | null };
  readonly frontmatter_unsupported: {
    readonly path: string;
    readonly line: string;
    readonly detail: string;
  };
  readonly grader_invalid: { readonly path: string; readonly problem: string };
  readonly input_missing: { readonly path: string };
  readonly skills_missing: { readonly dir: string };
  readonly input_invalid: { readonly path: string; readonly problem: string };
  readonly graders_missing: { readonly dir: string };
  readonly case_missing: { readonly name: string };
  readonly results_missing: { readonly dir: string };
  readonly result_case_missing: { readonly name: string; readonly path: string };
  readonly run_missing: { readonly name: string; readonly index: number };
  readonly arm_count: { readonly name: string; readonly arms: number };
  readonly trace_unrecorded: { readonly name: string; readonly index: number };
  readonly trace_gone: { readonly path: string };
  readonly unreachable: { readonly value: string };
  readonly invariant_failed: { readonly condition: string };
};

export type ErrorCode = keyof Facts;

export const BUG =
  "stop and hand this error to the owner as a bug in the repo tooling; no command you run resolves it";

const KEEP_A_TRACE =
  "rerun with mise run eval --skill <a tag in the case's prompt.md> --keep-temp, then run mise run eval:keep on the new head.json before its temporary directory is cleaned";

type Entry<Code extends ErrorCode> = {
  readonly exit: number;
  readonly message: (facts: Facts[Code]) => string;
  readonly resolve: (facts: Facts[Code]) => string;
};

const ERRORS: { readonly [Code in ErrorCode]: Entry<Code> } = {
  usage: {
    exit: 2,
    message: ({ usage, problem }) => (problem === null ? usage : `${problem}\n${usage}`),
    resolve: () => "rerun with the arguments the usage line shows",
  },
  frontmatter_unsupported: {
    exit: 1,
    message: ({ path, line, detail }) => `${path}: frontmatter ${detail} in: ${line}`,
    resolve: ({ path }) =>
      `rewrite that line in ${path} as a plain key: value, an inline [list] or an inline { map } of plain items`,
  },
  grader_invalid: {
    exit: 1,
    message: ({ path, problem }) => `${path}: ${problem}`,
    resolve: ({ path }) =>
      `fix ${path} to the grader options in https://code.claude.com/docs/en/plugin-evals`,
  },
  input_missing: {
    exit: 1,
    message: ({ path }) => `no file at ${path}`,
    resolve: () =>
      "pass a path that exists; if traces/expected.json names it, save that trace with mise run eval:keep or remove its entry",
  },
  input_invalid: {
    exit: 1,
    message: ({ path, problem }) => `${path}: ${problem}`,
    resolve: ({ path }) =>
      `fix what the message names in ${path}; evals/README.md describes each file's shape`,
  },
  skills_missing: {
    exit: 1,
    message: ({ dir }) => `no skills/ directory in ${dir}`,
    resolve: () =>
      "pass the repo root, the directory that holds skills/, or no argument to validate this repo",
  },
  graders_missing: {
    exit: 1,
    message: ({ dir }) => `no graders/ folder in ${dir}`,
    resolve: ({ dir }) => `add a graders/ folder to ${dir}, or pass a case directory that has one`,
  },
  case_missing: {
    exit: 1,
    message: ({ name }) => `no case ${name} under evals/scenarios/`,
    resolve: () => "pass the name of a directory under evals/scenarios/ that holds prompt.md",
  },
  results_missing: {
    exit: 1,
    message: ({ dir }) => `no run under ${dir}`,
    resolve: () => "run mise run eval first, or pass a result file",
  },
  result_case_missing: {
    exit: 1,
    message: ({ name, path }) => `case ${name} is not in ${path}`,
    resolve: () =>
      "pass a result file from a run that included the case; mise run eval:summary <file> lists its cases",
  },
  run_missing: {
    exit: 1,
    message: ({ name, index }) => `no run ${index} in case ${name}`,
    resolve: () => "pass a run index from 0 up to the case's run count less one",
  },
  arm_count: {
    exit: 1,
    message: ({ name, arms }) => `case ${name} has ${arms} arms; the runner produces one`,
    resolve: () => "pass a head.json or base.json written by mise run eval",
  },
  trace_unrecorded: {
    exit: 1,
    message: ({ name, index }) => `run ${index} in case ${name} recorded no trace path`,
    resolve: () => KEEP_A_TRACE,
  },
  trace_gone: {
    exit: 1,
    message: ({ path }) => `trace is gone: ${path}`,
    resolve: () => KEEP_A_TRACE,
  },
  unreachable: {
    exit: 1,
    message: ({ value }) => `unreachable: ${value}`,
    resolve: () => BUG,
  },
  invariant_failed: {
    exit: 1,
    message: ({ condition }) => `invariant failed: ${condition}`,
    resolve: () => BUG,
  },
};

export class CodedError<Code extends ErrorCode = ErrorCode> extends Error {
  override readonly name = "CodedError";
  readonly code: Code;
  readonly facts: Facts[Code];
  readonly resolve: string;
  readonly exit: number;

  constructor(code: Code, facts: Facts[Code]) {
    const entry: Entry<Code> = ERRORS[code];
    super(entry.message(facts));
    this.code = code;
    this.facts = facts;
    this.resolve = entry.resolve(facts);
    this.exit = entry.exit;
  }
}
