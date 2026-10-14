import { unreachable } from "./assert";
import type { ToolCall } from "./tool-call";

function header(call: ToolCall): string {
  switch (call.kind) {
    case "read":
      return `read ${call.path}`;
    case "write":
      return `write ${call.path} (${call.bytes} bytes)`;
    case "delete":
      return `delete ${call.paths.length} files`;
    default:
      return unreachable(call);
  }
}

export function logCall(call: ToolCall): void {
  console.error(header(call));
}
