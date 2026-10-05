# Agent rules

Load these when the scope drives a model: a harness, a tool, a prompt, or the loop around them.

- **The model decides; the host supports it.** Host code routes, classifies or corrects nothing a prompt can handle, and invents no task types. A host check is added only when evidence shows it helps, and host checks shrink as models improve.
- **Fix the cause in the prompt.** A bad answer is fixed in the instructions, never by post-processing the output.
- **Tune for the general case.** A change that only makes one scenario pass is not progress.
- **Prompts are short, general and direct.** They hold no case-specific rules, no examples tuned to one task, and nothing defensive. A general rule beats more specific instructions. A prompt states the shape it wants rather than listing what is forbidden, and a line that does not change what the model does is cut.
- **The core is agnostic** to language, project and task.
- **The model can end its turn.** It has a clear way to say it is done.
- **Tool results carry only what the model needs.** The rest costs tokens and can mislead.
- **Tool errors reach the model** as a code and a message it can act on.
- **Guards and evaluators are pure decisions** (see "Pure decisions, separate effects"). A mode change or other effect is a separate step in the loop.
- **Tools belong to the agent, and commands to the user.** The agent never writes a prompt for the user to submit.
- **Every tuning constant is measured,** never guessed.
- **A bad run is diagnosed as harness or model before anything changes,** and behavior is not tuned for a weak model.
- **The harness tells the model what it knows and what it does for it.** A linter, test runner or package manager the harness detected is available to the model, and the model is told which steps the harness runs, so it does not run them again.
- **Context is budgeted across turns.** A default read or result size is set for what accumulates over a task, not for one call.
- **The prompt is ordered:** stable content first, where it carries most weight and caches, and dynamic content last.
- **A tool is one declarative unit.** Its schema, instructions and formatter live with it, and the prompt is assembled from the tools present.
- **The agent is judged by real runs on real tasks.** Tests fake only the model.

Spot it:

- a regex or keyword classifier deciding what the model should do
- output rewritten after the model returns it
- a prompt line that names one task, file or scenario
- a prompt test matching text with a regex instead of checking intent
- a tool result carrying data the model does not use
- a tool whose schema or formatter lives in another file
- dynamic content above stable content in the system prompt
