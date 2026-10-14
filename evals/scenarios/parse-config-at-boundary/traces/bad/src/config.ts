import { readFileSync } from "node:fs";

interface Config {
  port: number;
  transport: "http" | "rpc";
  logLevel: string;
  upstreamUrl: string;
}

const file = JSON.parse(readFileSync("relay.json", "utf8")) as Config;

export const config = { ...file, apiKey: process.env.RELAY_API_KEY ?? "" };
