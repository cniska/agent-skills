import { CodedError } from "../../lib/coded-error";

export function unreachable(value: never): never {
  throw new CodedError("unreachable", { value: JSON.stringify(value) });
}
