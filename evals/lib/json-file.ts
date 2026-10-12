import { readFileSync } from "node:fs";
import { z } from "zod";
import { CodedError } from "./coded-error";

export function readJson<Schema extends z.ZodType>(path: string, schema: Schema): z.infer<Schema> {
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    throw new CodedError("input-invalid", { path, problem: `not JSON: ${error.message}` });
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success)
    throw new CodedError("input-invalid", { path, problem: z.prettifyError(parsed.error) });
  return parsed.data;
}
