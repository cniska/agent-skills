import { readFileSync } from "node:fs";
import { z } from "zod";

const ConfigFile = z.strictObject({
  port: z.number().int().positive(),
  transport: z.enum(["http", "rpc"]),
  logLevel: z.enum(["debug", "info", "warn", "error"]),
  upstreamUrl: z.url(),
});

const apiKey = z.string().min(1).parse(process.env.RELAY_API_KEY);
const file: unknown = JSON.parse(readFileSync("relay.json", "utf8"));

export const config = { ...ConfigFile.parse(file), apiKey };
