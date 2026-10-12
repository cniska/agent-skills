import { CodedError, type ErrorCode } from "./coded-error";

const EXIT_BY_CODE: { readonly [Code in ErrorCode]: number } = {
  usage: 2,
  "frontmatter-unsupported": 1,
  "grader-invalid": 1,
  "input-invalid": 1,
  "graders-missing": 1,
  "case-missing": 1,
  "results-missing": 1,
  "result-case-missing": 1,
  "run-missing": 1,
  "arm-count": 1,
  "trace-unrecorded": 1,
  "trace-gone": 1,
};

export function reportProblems(problems: readonly string[]): void {
  if (problems.length === 0) return;
  process.stderr.write(`${problems.join("\n")}\n`);
  process.exitCode = 1;
}

function exitCode(error: unknown): number {
  if (!(error instanceof CodedError)) return 1;
  const code: ErrorCode = error.code;
  return EXIT_BY_CODE[code];
}

export function runMain(main: (args: readonly string[]) => void): void {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(exitCode(error));
  }
}
