import { assertUnreachable } from "./assert";
import type { ToolCall } from "./tool-call";

function header(call: ToolCall): string {
  if (call.kind === "read") return `read ${call.path}`;
  if (call.kind === "write") return `write ${call.path} (${call.bytes} bytes)`;
  if (call.kind === "delete") return `delete ${call.paths.length} files`;
  return assertUnreachable(call);
}

export function logCall(call: ToolCall): void {
  console.error(header(call));
}
