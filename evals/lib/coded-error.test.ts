import { describe, expect, test } from "bun:test";
import { BUG, CodedError } from "./coded-error";

describe("coded errors", () => {
  test("a refusal tells the agent what to do next", () => {
    const error = new CodedError("trace-gone", { path: "/tmp/run/trace.jsonl" });
    expect(error.exit).toBe(1);
    expect(error.message).toBe("trace is gone: /tmp/run/trace.jsonl");
    expect(error.resolve).toStartWith("rerun with mise run eval --skill");
  });

  test("an unreachable branch is a fault handed to the owner", () => {
    const error = new CodedError("unreachable", { value: '"surprise"' });
    expect(error.resolve).toBe(BUG);
  });
});
