import { readFileSync } from "node:fs";
import { z } from "zod";

const ConfigFile = z.strictObject({
  port: z.number(),
  transport: z.enum(["http", "rpc"]),
  logLevel: z.string(),
  upstreamUrl: z.string(),
});

type Config = z.infer<typeof ConfigFile>;

const apiKey = z.string().min(1).parse(process.env.RELAY_API_KEY);
const file: Config = JSON.parse(readFileSync("relay.json", "utf8"));

export const config = { ...file, apiKey };
