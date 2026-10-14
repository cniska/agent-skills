import { z } from "zod";
import { CodedError } from "../../lib/coded-error";

export type ToolCall = { readonly name: string; readonly input: string };

export type Trace = {
  readonly text: string;
  readonly lastMessage: string;
  readonly toolCalls: readonly ToolCall[];
};

const Line = z.looseObject({ type: z.string().optional() });
const Blocks = z.array(z.looseObject({ type: z.string() }));
const AssistantLine = z.looseObject({ message: z.looseObject({ content: Blocks }) });
const TextBlock = z.looseObject({ type: z.literal("text"), text: z.string() });
const ToolUseBlock = z.looseObject({ type: z.literal("tool_use"), name: z.string(), input: z.unknown() });

type LineBlocks = Readonly<z.infer<typeof Blocks>>;

function parseLine(json: string, source: string, index: number): LineBlocks {
  let raw: unknown;
  try {
    raw = JSON.parse(json);
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    throw new CodedError("input_invalid", {
      path: source,
      problem: `line ${index + 1} is not JSON: ${error.message}`,
    });
  }
  if (parseWith(Line, raw, source, index).type !== "assistant") return [];
  return parseWith(AssistantLine, raw, source, index).message.content;
}

function parseWith<T extends z.ZodType>(schema: T, raw: unknown, source: string, index: number): z.infer<T> {
  const result = schema.safeParse(raw);
  if (!result.success) {
    throw new CodedError("input_invalid", {
      path: source,
      problem: `line ${index + 1}: ${z.prettifyError(result.error)}`,
    });
  }
  return result.data;
}

function messageText(blocks: LineBlocks): string {
  return blocks
    .flatMap((block) => {
      const text = TextBlock.safeParse(block);
      return text.success ? [text.data.text] : [];
    })
    .join("\n");
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
  const replies = lines.map(messageText).filter(Boolean);
  return { text, lastMessage: replies.at(-1) ?? "", toolCalls: toolCalls(lines) };
}
