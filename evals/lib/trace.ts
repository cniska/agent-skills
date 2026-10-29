import { z } from "zod";

import { CodedError } from "../../lib/coded-error";

export type ToolCall = { readonly name: string; readonly input: string };

export type Trace = {
  readonly text: string;
  readonly toolCalls: readonly ToolCall[];
};

const Line = z.looseObject({ type: z.string().optional() });
const Blocks = z.array(z.looseObject({ type: z.string() }));
const AssistantLine = z.looseObject({ message: z.looseObject({ content: Blocks }) });
const ToolUseBlock = z.looseObject({ type: z.literal("tool_use"), name: z.string(), input: z.unknown() });

type LineBlocks = Readonly<z.infer<typeof Blocks>>;

function parseLine(json: string, source: string, index: number): LineBlocks {
  let value: unknown;
  try {
    value = JSON.parse(json);
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    throw new CodedError("input_invalid", {
      path: source,
      problem: `line ${index + 1} is not JSON: ${error.message}`,
    });
  }
  if (parseWith(Line, value, source, index).type !== "assistant") return [];
  return parseWith(AssistantLine, value, source, index).message.content;
}

function parseWith<T extends z.ZodType>(
  schema: T,
  value: unknown,
  source: string,
  index: number,
): z.infer<T> {
  const result = schema.safeParse(value);
  if (!result.success) {
    throw new CodedError("input_invalid", {
      path: source,
      problem: `line ${index + 1}: ${z.prettifyError(result.error)}`,
    });
  }
  return result.data;
}

function toolCalls(lines: readonly LineBlocks[]): ToolCall[] {
  return lines.flatMap((blocks) =>
    blocks.flatMap((block) => {
      const call = ToolUseBlock.safeParse(block);
      return call.success ? [{ name: call.data.name, input: JSON.stringify(call.data.input) }] : [];
    }),
  );
}

export function parseTrace(text: string, source: string): Trace {
  const lines = text
    .split("\n")
    .flatMap((json, index) => (json.trim() ? [parseLine(json, source, index)] : []));
  return { text, toolCalls: toolCalls(lines) };
}
