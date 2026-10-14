import { describe, expect, test } from "bun:test";
import { parseTrace } from "./trace";

describe("parseTrace", () => {
  test("reads a trace whose system line carries its message as a string", () => {
    const trace = parseTrace(
      [
        JSON.stringify({
          type: "system",
          subtype: "permission_denied",
          message: "Permission to use Grep has been denied.",
        }),
        JSON.stringify({ type: "assistant", message: { content: [{ type: "text", text: "Done." }] } }),
      ].join("\n"),
      "trace.jsonl",
    );
    expect(trace.lastMessage).toBe("Done.");
  });
});
