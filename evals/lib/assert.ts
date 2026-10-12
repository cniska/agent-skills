import { CodedError } from "./coded-error";

export function unreachable(value: never): never {
  throw new CodedError("unreachable", { value: JSON.stringify(value) });
}

export function invariant(condition: unknown, message: string): asserts condition {
  if (!condition) throw new CodedError("invariant_failed", { condition: message });
}
