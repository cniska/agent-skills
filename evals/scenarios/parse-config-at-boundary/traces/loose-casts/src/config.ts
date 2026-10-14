import { readFileSync } from "node:fs";
import { z } from "zod";

type Transport = "http" | "rpc";

const ConfigFile = z.strictObject({
  port: z.number(),
  transport: z.enum(["http", "rpc"]),
  logLevel: z.string(),
  upstreamUrl: z.string(),
});

const apiKey = process.env.RELAY_API_KEY!;
const file = JSON.parse(readFileSync("relay.json", "utf8")) as any;
const parsed = ConfigFile.parse(file);

export const config = { ...parsed, transport: parsed.transport satisfies Transport, apiKey };
