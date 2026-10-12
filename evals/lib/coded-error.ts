type Facts = {
  readonly usage: { readonly problem: string };
  readonly "frontmatter-unsupported": { readonly line: string; readonly detail: string };
  readonly "grader-invalid": { readonly grader: string; readonly problem: string };
  readonly "input-invalid": { readonly path: string; readonly problem: string };
  readonly "graders-missing": { readonly dir: string };
  readonly "case-missing": { readonly name: string };
  readonly "results-missing": { readonly dir: string };
  readonly "result-case-missing": { readonly name: string; readonly path: string };
  readonly "run-missing": { readonly name: string; readonly index: number };
  readonly "arm-count": { readonly name: string; readonly arms: number };
  readonly "trace-unrecorded": { readonly name: string; readonly index: number };
  readonly "trace-gone": { readonly path: string };
};

export type ErrorCode = keyof Facts;

const MESSAGES: { readonly [Code in ErrorCode]: (facts: Facts[Code]) => string } = {
  usage: ({ problem }) => problem,
  "frontmatter-unsupported": ({ line, detail }) => `frontmatter: ${detail} in: ${line}`,
  "grader-invalid": ({ grader, problem }) => `grader ${grader}: ${problem}`,
  "input-invalid": ({ path, problem }) => `${path}: ${problem}`,
  "graders-missing": ({ dir }) => `no graders/ folder in ${dir}; pass a case directory`,
  "case-missing": ({ name }) => `no case ${name} under evals/`,
  "results-missing": ({ dir }) => `no run under ${dir}; run mise run eval first`,
  "result-case-missing": ({ name, path }) => `case ${name} is not in ${path}`,
  "run-missing": ({ name, index }) => `no run ${index} in case ${name}`,
  "arm-count": ({ name, arms }) => `case ${name} has ${arms} arms; the runner produces one`,
  "trace-unrecorded": ({ name, index }) => `run ${index} in case ${name} recorded no trace path`,
  "trace-gone": ({ path }) => `trace is gone: ${path} (rerun with --keep-temp)`,
};

export class CodedError<Code extends ErrorCode = ErrorCode> extends Error {
  override readonly name = "CodedError";
  readonly code: Code;
  readonly facts: Facts[Code];

  constructor(code: Code, facts: Facts[Code]) {
    super(MESSAGES[code](facts));
    this.code = code;
    this.facts = facts;
  }
}
