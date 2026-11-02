import { writeFileSync } from "node:fs";
import { join } from "node:path";

import { runMain } from "../lib/cli";
import { CodedError } from "../lib/coded-error";
import { ROOT_DIR } from "../lib/paths";
import { RULE_NAMES_FILE, ruleNames, ruleNamesJson } from "../lib/rule-names";

runMain((args) => {
  if (args.length > 0)
    throw new CodedError("usage", { usage: "usage: bun scripts/rule-names.ts", problem: null });
  const { names, problems } = ruleNames(ROOT_DIR);
  if (problems.length > 0) throw new CodedError("rule_sources_invalid", { problems });
  writeFileSync(join(ROOT_DIR, RULE_NAMES_FILE), ruleNamesJson(names));
  console.log(`OK: ${names.length} rule names written to ${RULE_NAMES_FILE}`);
});
