import { readFileSync } from "node:fs";
import { z } from "zod";

const ConfigFile = z.object({
  port: z.number(),
  logLevel: z.string(),
  upstreamUrl: z.string(),
});

export type Config = z.infer<typeof ConfigFile>;

const raw = JSON.parse(readFileSync("relay.json", "utf8")) as z.infer<typeof ConfigFile>;

export const config = {
  ...ConfigFile.parse(raw),
  transport: (process.env.RELAY_TRANSPORT ?? "http") as "http" | "rpc",
  apiKey: process.env.RELAY_API_KEY ?? "",
};
