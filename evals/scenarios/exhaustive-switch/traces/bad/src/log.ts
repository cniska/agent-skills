import type { ToolCall } from "./tool-call";

function header(call: ToolCall): string {
  if (call.kind === "read") return `read ${call.path}`;
  if (call.kind === "write") return `write ${call.path} (${call.bytes} bytes)`;
  return `delete ${call.paths.length} files`;
}

export function logCall(call: ToolCall): void {
  console.error(header(call));
}
