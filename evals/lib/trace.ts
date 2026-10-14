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

type Message = { readonly type: string | null; readonly blocks: readonly unknown[] };

function parseLine(line: string, source: string, index: number): Message {
  let raw: unknown;
  try {
    raw = JSON.parse(line);
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    throw new CodedError("input_invalid", {
      path: source,
      problem: `line ${index + 1} is not JSON: ${error.message}`,
    });
  }
  const type = parseWith(Line, raw, source, index).type ?? null;
  if (type !== "assistant") return { type, blocks: [] };
  return { type, blocks: parseWith(AssistantLine, raw, source, index).message.content };
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

function messageText(message: Message): string {
  return message.blocks
    .flatMap((block) => {
      const text = TextBlock.safeParse(block);
      return text.success ? [text.data.text] : [];
    })
    .join("\n");
}

function toolCalls(messages: readonly Message[]): ToolCall[] {
  return messages.flatMap((message) =>
    message.blocks.flatMap((block) => {
      const call = ToolUseBlock.safeParse(block);
      return call.success ? [{ name: call.data.name, input: JSON.stringify(call.data.input) }] : [];
    }),
  );
}

export function parseTrace(text: string, source: string): Trace {
  const messages = text
    .split("\n")
    .flatMap((line, index) => (line.trim() ? [parseLine(line, source, index)] : []));
  const replies = messages
    .filter((m) => m.type === "assistant")
    .map(messageText)
    .filter(Boolean);
  return { text, lastMessage: replies.at(-1) ?? "", toolCalls: toolCalls(messages) };
}
