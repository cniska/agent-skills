import { runMain } from "../../lib/cli";
import { CodedError } from "../../lib/coded-error";
import { cases } from "./cases";

runMain((args) => {
  if (args.length > 1)
    throw new CodedError("usage", { usage: "usage: bun evals/lib/list-cases.ts [<skill>]", problem: null });
  const [skill] = args;
  for (const c of cases())
    if (skill === undefined || skill === "" || c.tags.includes(skill)) console.log(c.name);
});
