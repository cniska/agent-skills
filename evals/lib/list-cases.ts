import { cases } from "./cases";
import { runMain } from "./cli";
import { CodedError } from "./coded-error";

runMain((args) => {
  if (args.length > 1) throw new CodedError("usage", { problem: "usage: list-cases.ts [<skill>]" });
  const [skill] = args;
  for (const c of cases())
    if (skill === undefined || skill === "" || c.tags.includes(skill)) console.log(c.name);
});
