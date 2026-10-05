# UI rules

Load these when the scope renders an interface. They hold for any component library.

- **One owner per piece of data.** The component that owns the data fetches and changes it; components below get values and callbacks.
- **Data flows one way.** Values go down, and events come back up.
- **Derive, don't sync.** A value computable from existing state or props is computed while rendering, never copied into state and kept in step.
- **Effects are for the outside world only.** An effect syncs with something outside the UI, such as a subscription, a timer or a network call, and cleans up after itself. It never moves data between the UI's own state.
- **Rendering is pure.** The same inputs render the same output and change nothing.
- **Server state is not UI state.** Fetched data lives in the cache. A write updates the cache from its result and does not refetch what the result already holds.
- **Design tokens, never raw values,** for color, spacing and type.
- **A component owns the whole markup of the thing it names.** One that only forwards to another goes.
- **Components render from props.** Data and commands come from the owner above, so a component with no logic can be rendered alone and its output locked by a visual test.
- **The framework's primitive, not its escape hatch:** a link component over an imperative navigation call.

Spot it:

- an effect that sets state from props or other state
- the same value held in two places
- a child fetching data its parent owns
- a refetch after a write whose result holds the data
- a hardcoded hex value or pixel size
