import { BUG, CodedError } from "./coded-error";

export function reportProblems(problems: readonly string[], resolve: string): void {
  if (problems.length === 0) return;
  process.stderr.write(`${problems.join("\n")}\nto resolve: ${resolve}\n`);
  process.exitCode = 1;
}

function report(error: unknown): { message: string; resolve: string; exit: number } {
  if (error instanceof CodedError)
    return { message: error.message, resolve: error.resolve, exit: error.exit };
  return { message: error instanceof Error ? error.message : String(error), resolve: BUG, exit: 1 };
}

export function runMain(main: (args: readonly string[]) => void): void {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    const { message, resolve, exit } = report(error);
    process.stderr.write(`${message}\nto resolve: ${resolve}\n`);
    process.exit(exit);
  }
}
